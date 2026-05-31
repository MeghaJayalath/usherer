void main() {
  try {
    final uri = Uri.parse(
      'https://aerodatabox.p.rapidapi.com/flights/number/AI 281',
    );
    print('Uri parsed successfully: $uri');
  } catch (e) {
    print('Uri parsing failed: $e');
  }
}
