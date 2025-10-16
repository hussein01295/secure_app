import 'package:isar/isar.dart';

part 'message_entity.g.dart';

@collection
class MessageEntity {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index(composite: [CompositeIndex('ts')])
  late String relationId;

  @Index()
  int ts = 0;

  bool fromMe = false;
  String type = 'text';

  String? coded;
  String? decoded;
  String? encryptedAAD;
  String? timeLabel;
  bool isRead = false;

  @Index(type: IndexType.hash, caseSensitive: false)
  late String searchNorm;

  @Index(type: IndexType.hash, caseSensitive: false)
  String? searchNormCoded;

  String? metadataJson;
}
