/// Contrat léger pour récupérer les props du widget sans dépendre de ChatScreen.
abstract class ChatScreenData {
  String get contactName;
  String get contactId;
  String get token;
  String get userId;
  String get relationId;
}
