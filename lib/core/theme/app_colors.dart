import 'package:flutter/material.dart';
import '../../data/models/flight.dart';

class AppColors {
  static const Color background = Color(
    0xFF000000,
  ); // AMOLED true black scaffold
  static const Color surface = Color(0xFF0D0D0D); // Cards
  static const Color surfaceHigh = Color(0xFF161616); // Modals, bottom sheets
  static const Color border = Color(0xFF1F1F1F); // Borders for cards/chips

  static const Color accent = Color(0xFFE8704A); // Coral CTA/Active
  static const Color accentMuted = Color(0x1AE8704A); // Coral at 10% opacity

  static const Color textPrimary = Color(0xFFF2E8D9); // Warm cream
  static const Color textSecondary = Color(
    0x99F2E8D9,
  ); // Warm cream at 60% opacity

  static const Color arrived = Color(0xFF4CAF50); // Green
  static const Color delayed = Color(0xFFFFC727); // Yellow
  static const Color early = Color(0xFF00BCD4); // Cyan/Teal

  // Custom transparent/neutral colors
  static const Color transparent = Colors.transparent;

  // Semantic UI styling mappings
  static Color getStatusIndicatorBgColor({required bool isComplete}) {
    return isComplete ? arrived.withValues(alpha: 0.1) : accentMuted;
  }

  static Color getStatusIndicatorColor({required bool isComplete}) {
    return isComplete ? arrived : accent;
  }

  // Flight/Vehicle Status UI styling
  static Color getFlightStatusColor(FlightStatus status) {
    switch (status) {
      case FlightStatus.onTime:
        return accent;
      case FlightStatus.delayed:
        return delayed;
      case FlightStatus.early:
        return early;
      case FlightStatus.arrived:
        return arrived;
      case FlightStatus.unknown:
        return textSecondary;
    }
  }

  static Color getStatusChipBgColor(FlightStatus status) {
    switch (status) {
      case FlightStatus.onTime:
        return accent;
      case FlightStatus.delayed:
        return delayed;
      case FlightStatus.early:
        return early;
      case FlightStatus.arrived:
        return arrived;
      case FlightStatus.unknown:
        return border;
    }
  }

  static Color getStatusChipTextColor(FlightStatus status) {
    switch (status) {
      case FlightStatus.onTime:
        return textPrimary;
      case FlightStatus.delayed:
        return background;
      case FlightStatus.early:
        return background;
      case FlightStatus.arrived:
        return textPrimary;
      case FlightStatus.unknown:
        return textSecondary;
    }
  }

  static const Color vipGold = Color(0xFFFFC727); // Gold / VIP indicator
  static const Color vipGoldMuted = Color(0x1AFFC727); // Gold at 10% opacity

  static Color getTouristTileBgColor({
    required bool pickUp,
    required bool dropOff,
    bool isVip = false,
  }) {
    Color baseColor;
    if (pickUp && dropOff) {
      baseColor = arrived.withValues(alpha: 0.07);
    } else if (pickUp) {
      baseColor = early.withValues(alpha: 0.07);
    } else if (isVip) {
      baseColor = vipGold.withValues(alpha: 0.08);
    } else {
      baseColor = const Color(0x0AFFFFFF);
    }
    return Color.alphaBlend(baseColor, surface);
  }

  static Color getTouristTileBorderColor({
    required bool pickUp,
    required bool dropOff,
    bool isVip = false,
  }) {
    if (pickUp && dropOff) {
      return arrived.withValues(alpha: 0.3);
    }
    if (pickUp) {
      return early.withValues(alpha: 0.3);
    }
    if (isVip) {
      return vipGold.withValues(alpha: 0.4);
    }
    return border;
  }

  static Color getTouristTileIndicatorColor({
    required bool pickUp,
    required bool dropOff,
    bool isVip = false,
  }) {
    if (pickUp && dropOff) {
      return arrived;
    }
    if (pickUp) {
      return early;
    }
    if (isVip) {
      return vipGold;
    }
    return accent;
  }

  static Color getTouristTileTextColor({
    required bool pickUp,
    required bool dropOff,
  }) {
    return (pickUp && dropOff) ? textSecondary.withValues(alpha: 0.5) : textPrimary;
  }

  static Color getTouristTileCheckboxColor({required bool active, Color defaultColor = textSecondary}) {
    return active ? arrived : defaultColor;
  }

  static Color getTouristTileArrivedTimeColor() {
    return arrived.withValues(alpha: 0.8);
  }

  static Color getTouristTileConfirmBtnColor({required bool isConfirming}) {
    return isConfirming ? arrived : accent;
  }
}
