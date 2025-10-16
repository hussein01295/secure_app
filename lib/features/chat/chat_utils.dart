class ChatUtils {
  static String applyLanguageMap(String text, Map<String, String> map) {
    return text.split('').map((c) => map[c] ?? c).join('');
  }

  static String applyReverseMap(String text, Map<String, String> map) {
    final reverseMap = {for (var e in map.entries) e.value: e.key};
    return text.split('').map((c) => reverseMap[c] ?? c).join('');
  }

  static String normalize(String input) {
    const accentReplacements = {
      '\u00E0': 'a', // à
      '\u00E1': 'a', // á
      '\u00E2': 'a', // â
      '\u00E3': 'a', // ã
      '\u00E4': 'a', // ä
      '\u00E6': 'a', // æ
      '\u00E7': 'c', // ç
      '\u00E8': 'e', // è
      '\u00E9': 'e', // é
      '\u00EA': 'e', // ê
      '\u00EB': 'e', // ë
      '\u00EC': 'i', // ì
      '\u00ED': 'i', // í
      '\u00EE': 'i', // î
      '\u00EF': 'i', // ï
      '\u00F1': 'n', // ñ
      '\u00F2': 'o', // ò
      '\u00F3': 'o', // ó
      '\u00F4': 'o', // ô
      '\u00F5': 'o', // õ
      '\u00F6': 'o', // ö
      '\u0153': 'e', // œ
      '\u00F9': 'u', // ù
      '\u00FA': 'u', // ú
      '\u00FB': 'u', // û
      '\u00FC': 'u', // ü
      '\u00FD': 'y', // ý
      '\u00FF': 'y', // ÿ
    };

    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(accentReplacements[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool fuzzyContains(String haystack, String needle) {
    if (needle.isEmpty) return true;
    return normalize(haystack).contains(normalize(needle));
  }
}
