import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app_config.dart';
import '../../data/models/flight.dart';
import '../../data/local/hive_cache.dart';

class FlightData {
  final String eta;
  final FlightStatus status;

  FlightData({required this.eta, required this.status});

  factory FlightData.fromJson(Map<String, dynamic> json) {
    String etaString = '';
    FlightStatus flightStatus = FlightStatus.onTime;

    try {
      final arrival = json['arrival'];
      if (arrival != null) {
        // AeroDataBox structure: scheduledTime, revisedTime, predictedTime, actualTime are nested maps
        final revised = arrival['revisedTime'] as Map<String, dynamic>?;
        final predicted = arrival['predictedTime'] as Map<String, dynamic>?;
        final actual = arrival['actualTime'] as Map<String, dynamic>?;
        final scheduled = arrival['scheduledTime'] as Map<String, dynamic>?;

        etaString =
            (revised?['local'] ??
                    predicted?['local'] ??
                    actual?['local'] ??
                    scheduled?['local'] ??
                    '')
                .toString();
      }

      final statusStr = json['status'] as String?;
      flightStatus = FlightStatusExtension.fromString(statusStr);
    } catch (e) {
      print('FlightData.fromJson parsing error: $e');
    }

    if (etaString.isEmpty) {
      etaString = 'No ETA';
    } else {
      // format to short time (HH:mm) if it's full timestamp (preserving the exact local time string)
      try {
        final match = RegExp(r'\s(\d{2}):(\d{2})').firstMatch(etaString);
        if (match != null) {
          etaString = '${match.group(1)}:${match.group(2)}';
        } else {
          final dateTime = DateTime.parse(etaString);
          etaString =
              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }

    return FlightData(eta: etaString, status: flightStatus);
  }
}

class FlightApiService {
  int _currentKeyIndex = 0;

  Future<FlightData?> fetchFlight(
    String flightNumber, {
    int? targetMonth,
    int? targetDay,
  }) async {
    final keys = AppConfig.flightApiKeys;
    if (keys.isEmpty) return null;

    // Remove empty keys
    final validKeys = keys.where((k) => k.trim().isNotEmpty).toList();

    // If no API key is present, skip polling
    if (validKeys.isEmpty) {
      print(
        'FlightApiService: No API keys configured. Skipping flight poll for $flightNumber.',
      );
      return null;
    }

    for (int attempt = 0; attempt < validKeys.length; attempt++) {
      final keyIndex = (_currentKeyIndex + attempt) % validKeys.length;
      final key = validKeys[keyIndex];

      int retryCount = 0;
      const maxRetries = 2;
      bool rotateKey = false;

      while (retryCount <= maxRetries) {
        try {
          final response = await http.get(
            Uri.parse(
              'https://aerodatabox.p.rapidapi.com/flights/number/$flightNumber',
            ),
            headers: {
              'X-RapidAPI-Key': key,
              'X-RapidAPI-Host': 'aerodatabox.p.rapidapi.com',
            },
          );

          // Capture case-insensitive quota headers from RapidAPI
          final remainingStr = _getHeaderCaseInsensitive(response.headers, 'x-ratelimit-requests-remaining');
          final limitStr = _getHeaderCaseInsensitive(response.headers, 'x-ratelimit-requests-limit');
          if (remainingStr != null && limitStr != null) {
            final remaining = int.tryParse(remainingStr);
            final limit = int.tryParse(limitStr);
            if (remaining != null && limit != null) {
              final quotas = HiveCache.getApiKeyQuotas();
              quotas[key] = {
                'remaining': remaining,
                'limit': limit,
                'updatedAt': DateTime.now().toIso8601String(),
              };
              await HiveCache.setApiKeyQuotas(quotas);
            }
          }

          if (response.statusCode == 200) {
            // Success, update key index pointer
            _currentKeyIndex = keyIndex;
            final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
            if (data.isNotEmpty) {
              Map<String, dynamic>? matchingFlightJson;
              if (targetMonth != null && targetDay != null) {
                final targetDateTime = DateTime(
                  DateTime.now().year,
                  targetMonth,
                  targetDay,
                );
                for (final flightJson in data) {
                  try {
                    final arrival = flightJson['arrival'];
                    final scheduledLocal =
                        arrival?['scheduledTime']?['local'] as String?;
                    if (scheduledLocal != null) {
                      final flightDateTime = DateTime.parse(scheduledLocal);
                      // Check if difference is within 1 day (to handle midnight / timezone offsets)
                      if (flightDateTime
                              .difference(targetDateTime)
                              .inDays
                              .abs() <=
                          1) {
                        matchingFlightJson = flightJson as Map<String, dynamic>;
                        break;
                      }
                    }
                  } catch (_) {}
                }
              }

              final selectedJson =
                  matchingFlightJson ??
                  (targetMonth == null
                      ? data.first as Map<String, dynamic>
                      : null);
              if (selectedJson != null) {
                return FlightData.fromJson(selectedJson);
              }
            }
            return null;
          }

          if (response.statusCode == 429) {
            // Let's check if we still have monthly quota left in our cached quotas
            final quotas = HiveCache.getApiKeyQuotas();
            final remaining = quotas[key]?['remaining'] as int?;
            
            print('FlightApiService: Hit 429 Rate Limit. Response body: ${response.body}');
            
            if ((remaining == null || remaining > 0) && retryCount < maxRetries) {
              retryCount++;
              print('FlightApiService: Hit temporary RapidAPI rate limit, but key still has remaining quota ($remaining left). Waiting 4 seconds and retrying (Attempt $retryCount/$maxRetries) for flight $flightNumber...');
              await Future.delayed(const Duration(seconds: 4));
              continue; // retry inside the while loop
            } else {
              print('FlightApiService: Rate limited on key index $keyIndex (Quota fully exhausted or max retries hit). Rotating to next key.');
              rotateKey = true;
              break; // break the while loop, proceed to rotate
            }
          }

          // Other API errors, log and break
          print(
            'FlightApiService HTTP error: ${response.statusCode} - ${response.body}',
          );
          rotateKey = true;
          break;
        } catch (e) {
          print('FlightApiService request exception: $e');
          rotateKey = true;
          break;
        }
      }

      if (!rotateKey) {
        // If we didn't flag a rotate, it means we succeeded or got null (non-429), so we don't need to try other keys
        break;
      }
    }

    return null;
  }

  String? _getHeaderCaseInsensitive(Map<String, String> headers, String key) {
    final lowerKey = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return null;
  }
}
