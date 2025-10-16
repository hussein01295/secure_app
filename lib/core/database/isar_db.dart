import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:silencia/features/chat/search_db/message_entity.dart';

class IsarDb {
  IsarDb._();

  static Isar? _instance;

  static Future<Isar> instance() async {
    final cached = _instance;
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [MessageEntitySchema],
      directory: dir.path,
      inspector: false,
    );
    _instance = isar;
    return isar;
  }
}
