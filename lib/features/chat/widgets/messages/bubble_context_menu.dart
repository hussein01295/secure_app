import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BubbleContextMenu extends StatelessWidget {
  final bool fromMe;
  final String text;
  final bool isTranslated;
  final VoidCallback onTranslate;
  final VoidCallback onClose;
  final String? messageId;
  final String? relationId;
  final Function(String emoji)? onReaction;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;

  const BubbleContextMenu({
    super.key,
    required this.fromMe,
    required this.text,
    required this.isTranslated,
    required this.onTranslate,
    required this.onClose,
    this.messageId,
    this.relationId,
    this.onReaction,
    this.onReply,
    this.onDelete,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onClose,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF24242A),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heure du message
                Text(
                  TimeOfDay.now().format(context),
                  style: TextStyle(color: Colors.white54, fontSize: 13)
                ),
                SizedBox(height: 6),

                // Réactions rapides
                if (onReaction != null) ...[
                  _buildQuickReactions(),
                  SizedBox(height: 8),
                  Divider(height: 1, color: Colors.white12),
                ],

                // Actions principales
                _menuItem(Icons.translate, isTranslated ? "Afficher codé" : "Traduire", onTranslate),

                if (onReply != null)
                  _menuItem(Icons.reply, "Répondre", () {
                    onClose();
                    onReply!();
                  }),

                _menuItem(Icons.copy, "Copier", () {
                  Clipboard.setData(ClipboardData(text: text));
                  onClose();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Copié !"))
                  );
                }),

                // Transférer remplacé par Répondre (déjà présent plus haut)
                // if (onForward != null)
                //   _menuItem(Icons.forward, "Transférer", () {
                //     onClose();
                //     onForward!();
                //   }),

                if (fromMe && onDelete != null)
                  _menuItem(Icons.delete, "Supprimer", () {
                    onClose();
                    onDelete!(); // Suppression directe sans confirmation
                  }),

                if (onReaction != null)
                  _menuItem(Icons.add_reaction, "Plus de réactions", () {
                    onClose();
                    _showAllReactions(context);
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(text, style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReactions() {
    final quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickEmojis.map((emoji) =>
          GestureDetector(
            onTap: () {
              onReaction!(emoji);
              onClose();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }

  // Méthode de confirmation supprimée - suppression directe maintenant

  void _showAllReactions(BuildContext context) {
    final allEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡', '🔥', '👏', '🎉', '💯'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Color(0xFF24242A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Choisir une réaction',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: allEmojis.map((emoji) =>
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onReaction!(emoji);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ).toList(),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
