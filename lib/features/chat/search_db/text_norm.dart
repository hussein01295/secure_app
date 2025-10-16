import 'package:silencia/features/chat/chat_utils.dart';

class TextNorm {
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final basic = ChatUtils.normalize(input);
    final stripped = basic.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
