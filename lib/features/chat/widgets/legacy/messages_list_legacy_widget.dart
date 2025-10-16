import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/config/debug_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'package:silencia/core/theme/app_theme.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/utils/encryption_helper.dart';
import 'package:silencia/core/utils/multi_language_manager.dart';

import '../media/authenticated_image_widget.dart';
import '../messages/bubble_context_menu.dart';
import '../media/encrypted_image_widget.dart';
import '../media/encrypted_video_widget.dart';
import '../media/encrypted_voice_widget.dart';
import '../ui/ephemeral_indicator.dart';
import '../messages/message_reactions_widget.dart';
import '../ui/typing_indicator.dart';
import '../media/video_message_widget.dart';

// Helper pour les logs conditionnels de traduction
void _debugTranslation(String message) {
  if (DebugConfig.enableTranslationLogs) {
    debugPrint(message);
  }
}

class MessagesList extends StatefulWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final Map<String, String>? langMap;
  final bool canWrite;
  final bool estTraduit; // <-- AjoutÃƒÂ© ici
  final String Function(String, Map<String, String>) applyReverseMap;
  final void Function(String messageId)? onMessageVisible;
  final bool isContactTyping;
  final String contactName;
  final String relationId; // <-- AjoutÃƒÂ© pour les rÃƒÂ©actions

  // Ã¢Å“â€¦ NOUVEAU: Support du mode multi-langues
  final bool isMultiLanguageMode;
  final Map<String, Map<String, String>>? multiLanguages;
  final String? mediaKey;

  // Ã°Å¸â€Â ParamÃƒÂ¨tres de recherche

  const MessagesList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.langMap,
    required this.canWrite,
    required this.estTraduit, // <-- AjoutÃƒÂ© ici
    required this.applyReverseMap,
    required this.onMessageVisible,
    required this.isContactTyping,
    required this.contactName,
    required this.relationId, // <-- AjoutÃƒÂ© pour les rÃƒÂ©actions
    // Ã¢Å“â€¦ NOUVEAU: Support du mode multi-langues
    required this.isMultiLanguageMode,
    required this.multiLanguages,
    required this.mediaKey,

    // Ã°Å¸â€Â ParamÃƒÂ¨tres de recherche
  });

  @override
  State<MessagesList> createState() => MessagesListState();
}

class MessagesListState extends State<MessagesList>
    with TickerProviderStateMixin {
  Map<int, bool> translatedBubbles = {};
  OverlayEntry? _menuOverlay;
  int? _selectedIndex;
  GlobalKey? _bubbleKey;
  AnimationController? _bubbleAnimController;
  Map<String, dynamic>? replyingTo; // Message auquel on rÃƒÂ©pond

  // Animation pour les nouveaux messages
  late AnimationController _messageAnimationController;

  Animation<double>? _bubbleAnim;
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightMessageId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();

    // Initialiser l'animation pour les nouveaux messages
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _messageAnimationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // VÃƒÂ©rifier s'il y a un nouveau message
    if (widget.messages.isNotEmpty && oldWidget.messages.isNotEmpty) {
      final newLastMessage = widget.messages.last;
      final oldLastMessage = oldWidget.messages.last;

      // Si l'ID du dernier message a changÃƒÂ©, c'est un nouveau message
      if (newLastMessage['id'] != oldLastMessage['id']) {
        _triggerMessageAnimation();
      }
    } else if (widget.messages.isNotEmpty && oldWidget.messages.isEmpty) {
      // Premier message
      _triggerMessageAnimation();
    }
  }

  // MÃƒÂ©thode pour choisir le bon widget d'image selon le chiffrement
  Widget _buildImageWidget(String imageUrl, Map<String, dynamic> msg) {
    final isEncrypted = msg['encrypted'] == true || msg['encrypted'] == 'true';
    final messageId = msg['id']?.toString();

    if (isEncrypted && widget.relationId.isNotEmpty) {
      return EncryptedImageWidget(
        key: messageId != null ? ValueKey('encrypted_img_$messageId') : null,
        imageUrl: imageUrl,
        relationId: widget.relationId,
        width: 170,
      );
    }

    return AuthenticatedImage(
      key: messageId != null ? ValueKey('auth_img_$messageId') : null,
      imageUrl: imageUrl,
      width: 170,
      relationId: widget.relationId,
    );
  }

  // MÃƒÂ©thode pour choisir le bon widget vidÃƒÂ©o selon le chiffrement
  Widget _buildVideoWidget(String videoUrl, Map<String, dynamic> msg) {
    final isEncrypted = msg['encrypted'] == true || msg['encrypted'] == 'true';

    debugPrint(
      'Ã°Å¸â€Â _buildVideoWidget: URL=$videoUrl, encrypted=${msg['encrypted']}, isEncrypted=$isEncrypted',
    );

    if (isEncrypted && widget.relationId.isNotEmpty) {
      debugPrint(
        'Ã°Å¸â€Â Utilisation EncryptedVideoWidget pour vidÃƒÂ©o chiffrÃƒÂ©e',
      );
      return EncryptedVideoWidget(
        videoUrl: videoUrl,
        relationId: widget.relationId,
        width: 250,
      );
    } else {
      debugPrint(
        'Ã°Å¸Å½Â¥ Utilisation VideoMessageWidget pour vidÃƒÂ©o standard',
      );
      final isFromMe = msg['fromMe'] ?? false;
      final isRead = msg['isRead'] ?? false;
      return VideoMessageWidget(
        videoUrl: videoUrl,
        width: 250,
        isFromMe: isFromMe,
        time: msg['time'] ?? '',
        isRead: isRead,
      );
    }
  }

  // Voice widget support
  Widget _buildVoiceWidget(String audioUrl, Map<String, dynamic> msg) {
    final isFromMe = msg['fromMe'] ?? false;
    final duration = msg['metadata']?['duration'] ?? 0;
    final durationInt = duration is int
        ? duration
        : int.tryParse(duration.toString()) ?? 0;

    // Utiliser EncryptedVoiceWidget pour tous les messages vocaux
    // Il gère automatiquement les fichiers chiffrés (.enc) et non chiffrés (.m4a)
    // ⚠️ IMPORTANT: Utiliser une key unique basée sur l'URL pour forcer la recréation du widget
    return EncryptedVoiceWidget(
      key: ValueKey(audioUrl), // ✅ Key unique pour chaque message vocal
      voiceUrl: audioUrl,
      relationId: widget.relationId,
      duration: durationInt,
      isFromMe: isFromMe,
    );
  }

  void _triggerMessageAnimation() {
    // Réinitialiser et démarrer l'animation
    _messageAnimationController.reset();
    _messageAnimationController.forward();

    // Faire défiler vers le bas après l'animation
    Future.delayed(Duration(milliseconds: 100), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // REMOVED: Old voice widget code
  /*
  void _triggerMessageAnimationDUPLICATE_TO_DELETE() {
      'Ã°Å¸â€Â _buildVoiceWidget: URL=$audioUrl - Utilisation EncryptedVoiceWidget pour tous les audios',
    );

    // NOUVEAU : Utiliser EncryptedVoiceWidget pour TOUS les messages vocaux
    // Il gÃƒÂ¨re automatiquement les fichiers chiffrÃƒÂ©s (.enc) et non chiffrÃƒÂ©s (.m4a, .mp3, etc.)
    return EncryptedVoiceWidget(
      voiceUrl: audioUrl,
      relationId: widget.relationId,
      duration: duration,
      isFromMe: isFromMe,
    );

    // ANCIEN CODE COMMENTÃƒâ€° - SimpleVoiceWidget sauvegardÃƒÂ© dans BACKUP_simple_voice_widget.dart
    /*
    final isEncryptedFlag = msg['encrypted'] == true || msg['encrypted'] == 'true';
    final isEncryptedFile = audioUrl.endsWith('.enc');
    final isEncrypted = isEncryptedFlag || isEncryptedFile;

    if (isEncrypted && widget.relationId.isNotEmpty) {
      return EncryptedVoiceWidget(...);
    } else {
      return SimpleVoiceWidget(...);
    }
    */
  }
  */

  void _toggleBubbleTranslation(int index) {
    setState(() {
      translatedBubbles[index] = !(translatedBubbles[index] ?? false);
    });
  }

  // Ajouter une rÃƒÂ©action ÃƒÂ  un message
  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/reactions'),
        headers: headers,
        body: jsonEncode({
          'messageId': messageId,
          'emoji': emoji,
          'relationId': widget.relationId,
        }),
      );

      if (response.statusCode == 200) {
        // Optionnel : rafraÃƒÂ®chir les rÃƒÂ©actions
        setState(() {});
      }
    } catch (e) {
      debugPrint('Ã¢ÂÅ’ Erreur lors de l\'ajout de rÃƒÂ©action: $e');
    }
  }

  // RÃƒÂ©pondre ÃƒÂ  un message
  void _replyToMessage(int index) {
    final messagesList = widget.messages;
    final targetIndex = messagesList.length - 1 - index;
    if (targetIndex < 0 || targetIndex >= messagesList.length) {
      return;
    }
    final msg = messagesList[targetIndex];
    setState(() {
      replyingTo = {
        'id': msg['id'],
        'text': msg['text'] ?? msg['content'] ?? '',
        'sender': msg['sender'] ?? msg['senderName'] ?? 'Quelqu\'un',
        'fromMe': msg['fromMe'] ?? false,
      };
    });

    // Fermer le menu
    _closeMenu();

    // Optionnel : faire dÃƒÂ©filer vers le bas pour voir la zone de rÃƒÂ©ponse
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Supprimer un message
  Future<void> _deleteMessage(int index) async {
    final messagesList = widget.messages;
    final targetIndex = messagesList.length - 1 - index;
    if (targetIndex < 0 || targetIndex >= messagesList.length) {
      return;
    }
    final msg = messagesList[targetIndex];
    final messageId = msg['id'];

    if (messageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de supprimer ce message')),
      );
      return;
    }

    try {
      final headers = await AuthService.getAuthorizedHeaders();
      if (headers == null) return;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/messages/$messageId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Supprimer le message de la liste locale
        setState(() {
          widget.messages.removeWhere((m) => m['id'] == messageId);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Message supprimÃƒÂ©')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression')),
        );
      }
    } catch (e) {
      debugPrint('Ã¢ÂÅ’ Erreur lors de la suppression: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur rÃƒÂ©seau')));
    }
  }

  void _showBubbleMenu(int index) async {
    _removeOverlay();
    _selectedIndex = index;
    _bubbleKey = GlobalKey();
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;
    final RenderBox box =
        _bubbleKey!.currentContext!.findRenderObject() as RenderBox;
    final Offset bubblePos = box.localToGlobal(Offset.zero);
    final Size bubbleSize = box.size;
    final mq = MediaQuery.of(context);

    _bubbleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _bubbleAnim = Tween<double>(begin: 0, end: -38).animate(
      CurvedAnimation(
        parent: _bubbleAnimController!,
        curve: Curves.easeOutCubic,
      ),
    );
    _bubbleAnimController!.forward();

    const menuHeight = 240.0;
    double wantedTop = bubblePos.dy + bubbleSize.height + 14;
    if (wantedTop + menuHeight > mq.size.height - 10) {
      wantedTop = bubblePos.dy - menuHeight - 10;
      if (wantedTop < 10) wantedTop = 10;
    }
    double menuLeft = bubblePos.dx + bubbleSize.width / 2 - 130;
    if (menuLeft < 10) menuLeft = 10;
    if (menuLeft + 260 > mq.size.width - 10) menuLeft = mq.size.width - 270;

    final messagesList = widget.messages;
    final targetIndex = messagesList.length - 1 - index;
    if (targetIndex < 0 || targetIndex >= messagesList.length) {
      return;
    }
    final msg = messagesList[targetIndex];

    _menuOverlay = OverlayEntry(
      builder: (_) {
        // Prend bien en compte le XOR pour bulle + mode global !
        final isBubbleTranslated = translatedBubbles[index] ?? false;
        final bool translateThisBubble = widget.estTraduit ^ isBubbleTranslated;
        // Ã¢Å“â€¦ NOUVEAU: Support du mode multi-langues pour le menu contextuel
        String menuText;
        final coded = msg['text'] ?? "";

        debugPrint('Ã°Å¸â€Â MENU CONTEXTUEL: DÃƒÂ©but traduction');
        debugPrint('Ã°Å¸â€Â MENU CONTEXTUEL: Message ID = ${msg['id']}');
        debugPrint('Ã°Å¸â€Â MENU CONTEXTUEL: Contenu codÃƒÂ© = $coded');

        if (!widget.canWrite) {
          menuText = coded;
          debugPrint('Ã°Å¸â€Â MENU CONTEXTUEL: Pas de langues disponibles');
        } else {
          // Ãƒâ€°tape 1: DÃƒÂ©chiffrer le message avec la langue appropriÃƒÂ©e
          final encryptedAAD = msg['encryptedAAD'] as String?;
          String decodedText;

          debugPrint('Ã°Å¸â€Â MENU CONTEXTUEL: encryptedAAD = $encryptedAAD');
          debugPrint(
            'Ã°Å¸â€Â MENU CONTEXTUEL: isMultiLanguageMode = ${widget.isMultiLanguageMode}',
          );
          debugPrint(
            'Ã°Å¸â€Â MENU CONTEXTUEL: translateThisBubble = $translateThisBubble',
          );

          if (encryptedAAD != null &&
              widget.isMultiLanguageMode &&
              widget.multiLanguages != null &&
              widget.mediaKey != null) {
            // Ã¢Å“â€¦ NOUVEAU: Mode multi-langues - dÃƒÂ©chiffrer avec AAD
            debugPrint(
              'Ã°Å¸Å’Â MENU CONTEXTUEL: Mode multi-langues dÃƒÂ©tectÃƒÂ©',
            );
            try {
              // 🆕 NOUVEAU: Utilisation de la méthode unifiée qui détecte automatiquement le mode
              decodedText = MultiLanguageManager.decodeMessage(
                coded,
                encryptedAAD,
                widget.multiLanguages!,
                widget.mediaKey!,
                autoRepairLanguages:
                    true, // ✅ CORRECTION : Activer la réparation automatique
              );
              debugPrint(
                'Ã¢Å“â€¦ MENU CONTEXTUEL: DÃƒÂ©chiffrement AAD rÃƒÂ©ussi',
              );
              debugPrint(
                'Ã°Å¸â€Â MENU CONTEXTUEL: Texte dÃƒÂ©codÃƒÂ© = $decodedText',
              );
            } catch (e) {
              debugPrint(
                'Ã¢ÂÅ’ MENU CONTEXTUEL: Erreur dÃƒÂ©chiffrement AAD: $e',
              );
              decodedText = '[Erreur dÃƒÂ©chiffrement AAD: $e]';
            }
          } else if (encryptedAAD == null && widget.langMap != null) {
            // Ã¢Å“â€¦ RÃƒâ€°TROCOMPATIBILITÃƒâ€°: Mode ancien (1 langue) - SEULEMENT pour messages sans AAD
            debugPrint(
              'Ã°Å¸â€â€ž MENU CONTEXTUEL: Mode ancien (1 langue) - message sans AAD',
            );
            decodedText = widget.applyReverseMap(coded, widget.langMap!);
            debugPrint(
              'Ã¢Å“â€¦ MENU CONTEXTUEL: DÃƒÂ©chiffrement ancien rÃƒÂ©ussi',
            );
            debugPrint(
              'Ã°Å¸â€Â MENU CONTEXTUEL: Texte dÃƒÂ©codÃƒÂ© = $decodedText',
            );
          } else {
            debugPrint(
              'Ã¢Å¡Â Ã¯Â¸Â MENU CONTEXTUEL: Aucune langue disponible',
            );
            debugPrint(
              'Ã°Å¸â€Â MENU CONTEXTUEL: DÃƒÂ©tails - encryptedAAD: $encryptedAAD, isMultiLanguageMode: ${widget.isMultiLanguageMode}, multiLanguages: ${widget.multiLanguages != null}, mediaKey: ${widget.mediaKey != null}, langMap: ${widget.langMap != null}',
            );
            decodedText = coded; // Aucune langue disponible
          }

          // Ãƒâ€°tape 2: DÃƒÂ©cider si on affiche dÃƒÂ©codÃƒÂ© ou codÃƒÂ© selon le mode traduction
          if (translateThisBubble) {
            menuText = decodedText; // Mode traduction: afficher dÃƒÂ©codÃƒÂ©
            debugPrint(
              'Ã°Å¸â€œâ€“ MENU CONTEXTUEL: Affichage mode traduit = $menuText',
            );
          } else {
            menuText = coded; // Mode normal: afficher codÃƒÂ©
            debugPrint(
              'Ã°Å¸â€â€™ MENU CONTEXTUEL: Affichage mode codÃƒÂ© = $menuText',
            );
          }
        }

        return GestureDetector(
          onTap: _closeMenu,
          child: Material(
            color: Colors.black.withValues(alpha: 0.33),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _bubbleAnimController!,
                  builder: (context, child) {
                    return Positioned(
                      left: bubblePos.dx,
                      top: bubblePos.dy + _bubbleAnim!.value,
                      child: Opacity(
                        opacity: 1,
                        child: _Bubble(
                          text: menuText,
                          fromMe: msg['fromMe'] ?? false,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: menuLeft,
                  top: wantedTop,
                  child: BubbleContextMenu(
                    fromMe: msg['fromMe'] ?? false,
                    text: menuText,
                    isTranslated: translateThisBubble,
                    messageId: msg['id'],
                    relationId: widget.relationId,
                    onTranslate: () {
                      _toggleBubbleTranslation(index);
                      _closeMenu();
                    },
                    onClose: _closeMenu,
                    onReaction: (emoji) => _addReaction(msg['id'], emoji),
                    onReply: () => _replyToMessage(index),
                    onDelete: () => _deleteMessage(index),
                    // onForward supprimÃƒÂ© - remplacÃƒÂ© par rÃƒÂ©ponse
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    Overlay.of(context, rootOverlay: true).insert(_menuOverlay!);
  }

  void _closeMenu() async {
    await _bubbleAnimController?.reverse();
    _removeOverlay();
    _selectedIndex = null;
    _bubbleKey = null;
    setState(() {});
  }

  void _removeOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    _bubbleAnimController?.dispose();
    _bubbleAnimController = null;
  }

  // Ã¯Â¿Â½Ã°Å¸â€Â¥ Construire un message systÃƒÂ¨me avec un style spÃƒÂ©cial
  Widget _buildSystemMessage(Map<String, dynamic> msg) {
    final themeManager = globalThemeManager;
    final isDark = themeManager.currentTheme == AppThemeMode.dark;
    final isNeon = themeManager.currentTheme == AppThemeMode.neon;

    Color backgroundColor;
    Color textColor;
    Color iconColor;

    if (isNeon) {
      backgroundColor = const Color(0xFF1A1A2E).withValues(alpha: 0.8);
      textColor = const Color(0xFF00D4FF);
      iconColor = const Color(0xFF00D4FF);
    } else if (isDark) {
      backgroundColor = Colors.grey[800]!.withValues(alpha: 0.6);
      textColor = Colors.grey[300]!;
      iconColor = Colors.grey[400]!;
    } else {
      backgroundColor = Colors.grey[200]!.withValues(alpha: 0.8);
      textColor = Colors.grey[700]!;
      iconColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                msg['content'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.info_outline, size: 16, color: iconColor),
        ],
      ),
    );
  }

  void scrollToMessage(
    String messageId, {
    Duration duration = const Duration(milliseconds: 350),
    int retryCount = 0,
  }) {
    final key = _itemKeys[messageId];
    if (key?.currentContext == null) {
      // If the message is not currently visible, try to find it in the messages list
      final messageIndex = widget.messages.indexWhere(
        (msg) => msg['id']?.toString() == messageId,
      );
      if (messageIndex == -1) {
        debugPrint(
          '⚠️ Message avec ID $messageId non trouvé dans la liste des messages',
        );
        return;
      }

      // Limit retry attempts to avoid infinite loops
      if (retryCount >= 5) {
        debugPrint(
          '⚠️ Échec du scroll vers le message $messageId après 5 tentatives',
        );
        return;
      }

      // If message exists but key is not available, it might not be rendered yet
      // Try again after a short delay with exponential backoff
      final delay = Duration(milliseconds: 100 + (retryCount * 50));
      Future.delayed(delay, () {
        if (mounted) {
          scrollToMessage(
            messageId,
            duration: duration,
            retryCount: retryCount + 1,
          );
        }
      });
      return;
    }

    debugPrint('📍 Navigation vers le message $messageId');

    // Scroll to the message with smooth animation
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: duration,
      alignment:
          0.3, // Position message at 30% from top (good for reverse list)
      curve: Curves.easeInOut,
    );

    // Highlight the message temporarily
    setState(() {
      _highlightMessageId = messageId;
    });

    // Clear highlight after animation
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _highlightMessageId = null;
        });
      }
    });
  }

  Widget _wrapWithHighlight(Map<String, dynamic> msg, Widget child) {
    final messageId = msg['id']?.toString();
    final key = messageId != null
        ? _itemKeys.putIfAbsent(messageId, () => GlobalKey())
        : GlobalKey();
    final isHighlighted = messageId != null && messageId == _highlightMessageId;

    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: isHighlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.blueAccent.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  spreadRadius: 3,
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                ),
              ],
            )
          : null,
      child: child,
    );
  }
  // MÃƒÂ©thode dispose supprimÃƒÂ©e - fusionnÃƒÂ©e avec la premiÃƒÂ¨re

  @override
  Widget build(BuildContext context) {
    final displayedMessages = List<Map<String, dynamic>>.from(widget.messages);
    if (widget.isContactTyping) {
      displayedMessages.add({'isTypingIndicator': true});
    }

    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: displayedMessages.length,
      itemBuilder: (context, index) {
        final reverseIndex = displayedMessages.length - 1 - index;
        if (reverseIndex < 0 || reverseIndex >= displayedMessages.length) {
          return const SizedBox.shrink();
        }
        final msg = displayedMessages[reverseIndex];

        if (msg['isTypingIndicator'] == true) {
          return _wrapWithHighlight(
            msg,
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: TypingIndicator(contactName: widget.contactName),
              ),
            ),
          );
        }

        final isFromMe = msg['fromMe'] as bool? ?? false;
        final isRead = msg['isRead'] ?? false;
        final msgType = msg['messageType'] ?? 'text';

        // Ã°Å¸â€Â¥ Gestion spÃƒÂ©ciale pour les messages systÃƒÂ¨me
        if (msgType == 'system') {
          return _wrapWithHighlight(msg, _buildSystemMessage(msg));
        }

        if (!isFromMe && isRead == false && msg['id'] != null) {
          Future.microtask(() => widget.onMessageVisible?.call(msg['id']));
        }

        if (msgType == 'image' && msg['content'] != null) {
          final content = msg['content'];
          // Construire l'URL complÃƒÂ¨te pour l'image
          String imageUrl;
          if (content.startsWith('http')) {
            imageUrl = content;
          } else {
            // Le content peut ÃƒÂªtre "uploads/images/filename.jpg" ou "uploads/filename.jpg"
            // On extrait juste le nom du fichier final
            final normalizedContent = content.replaceAll(
              '\\',
              '/',
            ); // Normaliser les backslashes
            final filename = normalizedContent.split('/').last;
            // Utiliser baseHost au lieu de baseUrl pour ÃƒÂ©viter le /api
            imageUrl = '${ApiConfig.baseHost}/media/$filename';
          }

          debugPrint('Ã°Å¸â€“Â¼Ã¯Â¸Â Image URL construite: $imageUrl');
          debugPrint('Ã°Å¸â€“Â¼Ã¯Â¸Â Content original: $content');

          debugPrint('🖼️ AFFICHAGE IMAGE: id=${msg['id']}, url=$imageUrl');

          return _wrapWithHighlight(
            msg,
            Align(
              alignment: isFromMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Column(
                key: ValueKey(
                  'image_${msg['id']}',
                ), // ✅ Clé unique pour chaque image
                crossAxisAlignment: isFromMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildImageWidget(imageUrl, msg),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ã°Å¸â€Â¥ Indicateur ÃƒÂ©phÃƒÂ©mÃƒÂ¨re pour images
                      if (msg['ephemeral'] != null &&
                          msg['ephemeral']['enabled'] == true) ...[
                        EphemeralIndicator(
                          ephemeralData: msg['ephemeral'],
                          isFromMe: isFromMe,
                          isCompact: true,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        msg['time'] ?? '',
                        style: TextStyle(
                          color: isFromMe ? Colors.cyan : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                      if (isFromMe)
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 15,
                          color: isRead ? Colors.cyanAccent : Colors.black38,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        }

        // Voice message support
        if (msgType == 'voice' && msg['content'] != null) {
          // VÃƒÂ©rifier si c'est un message temporaire en cours d'envoi
          final isSending = msg['sending'] == true;
          final content = msg['content'] as String;

          if (isSending || content == 'Envoi en cours...') {
            // Afficher un indicateur de chargement pour les messages en cours d'envoi
            return _wrapWithHighlight(
              msg,
              Align(
                alignment: isFromMe
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFromMe
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ã°Å¸Å½Â¤ Envoi en cours...',
                        style: TextStyle(
                          color: isFromMe ? Colors.blue : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Utiliser directement le contenu pour les messages vocaux
          String audioPath = content;

          // Normaliser les sÃƒÂ©parateurs de chemin (Windows \ vers /)
          audioPath = audioPath.replaceAll('\\', '/');

          // Construire l'URL finale
          final audioUrl = '${ApiConfig.baseHost}/$audioPath';

          return _wrapWithHighlight(
            msg,
            Align(
              alignment: isFromMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: _buildVoiceWidget(audioUrl, msg),
              ),
            ),
          );
        }

        // Video message support
        if (msgType == 'video' && msg['content'] != null) {
          final content = msg['content'];
          // Construire l'URL complÃƒÂ¨te pour la vidÃƒÂ©o
          String videoUrl;
          if (content.startsWith('http')) {
            videoUrl = content;
          } else {
            // Le content peut ÃƒÂªtre "uploads/videos/filename.mp4" ou "uploads/filename.mp4"
            // On extrait juste le nom du fichier final
            final normalizedContent = content.replaceAll(
              '\\',
              '/',
            ); // Normaliser les backslashes
            final filename = normalizedContent.split('/').last;
            // Utiliser baseHost au lieu de baseUrl pour ÃƒÂ©viter le /api
            videoUrl = '${ApiConfig.baseHost}/media/$filename';
          }

          return _wrapWithHighlight(
            msg,
            Align(
              alignment: isFromMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _buildVideoWidget(videoUrl, msg),
            ),
          );
        }

        final coded = msg['text']; // Contenu chiffrÃƒÂ© stockÃƒÂ©
        final isBubbleTranslated = translatedBubbles[index] ?? false;
        final bool translateThisBubble =
            widget.estTraduit ^ isBubbleTranslated; // MAGIC LINE

        // Ã¢Å“â€¦ NOUVEAU: Toujours dÃƒÂ©chiffrer d'abord, puis dÃƒÂ©cider si on traduit
        String displayText;

        if (!widget.canWrite) {
          // Pas de langues disponibles - afficher tel quel
          displayText = coded;
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: Pas de langues disponibles, affichage brut',
          );
        } else {
          // Ãƒâ€°tape 1: DÃƒÂ©chiffrer le message avec la langue appropriÃƒÂ©e
          final encryptedAAD = msg['encryptedAAD'] as String?;
          String decodedText;

          debugPrint('Ã°Å¸â€Â TRADUCTION: DÃƒÂ©but dÃƒÂ©chiffrement');
          debugPrint('Ã°Å¸â€Â TRADUCTION: encryptedAAD = $encryptedAAD');
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: isMultiLanguageMode = ${widget.isMultiLanguageMode}',
          );
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: multiLanguages disponibles = ${widget.multiLanguages != null}',
          );
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: mediaKey disponible = ${widget.mediaKey != null}',
          );
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: langMap disponible = ${widget.langMap != null}',
          );
          debugPrint(
            'Ã°Å¸â€Â TRADUCTION: translateThisBubble = $translateThisBubble',
          );
          debugPrint('Ã°Å¸â€Â TRADUCTION: Message complet = $msg');

          // Ã¢Å“â€¦ VÃƒâ€°RIFICATION: mediaKey disponible
          if (widget.mediaKey == null) {
            debugPrint('Ã¢ÂÅ’ TRADUCTION: mediaKey est null');
            decodedText = '[ClÃƒÂ© de dÃƒÂ©chiffrement manquante]';
          } else if (encryptedAAD != null &&
              widget.isMultiLanguageMode &&
              widget.multiLanguages != null) {
            // Ã¢Å“â€¦ PRODUCTION: Mode multi-langues avec AAD chiffrÃƒÂ©
            debugPrint('Ã°Å¸Å’Â TRADUCTION: Mode multi-langues dÃƒÂ©tectÃƒÂ©');
            debugPrint(
              'Ã°Å¸â€Â PRODUCTION: AAD chiffrÃƒÂ© reÃƒÂ§u: $encryptedAAD',
            );
            debugPrint(
              'Ã°Å¸â€Â DEBUG: multiLanguages disponibles: ${widget.multiLanguages!.keys.toList()}',
            );
            debugPrint(
              'Ã°Å¸â€Â DEBUG: Nombre de langues: ${widget.multiLanguages!.length}',
            );

            try {
              // 1. D'abord dÃƒÂ©chiffrer l'AAD pour identifier la langue
              debugPrint('Ã°Å¸â€Â TRADUCTION: DÃƒÂ©chiffrement AAD...');
              final decryptedAAD = MultiLanguageManager.decryptAAD(
                encryptedAAD,
                widget.mediaKey!,
              );
              debugPrint(
                'Ã¢Å“â€¦ TRADUCTION: AAD dÃƒÂ©chiffrÃƒÂ© = $decryptedAAD',
              );

              // 2. Puis dÃƒÂ©chiffrer le message avec mediaKey pour obtenir le texte obfusquÃƒÂ©
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Tentative dÃƒÂ©chiffrement...',
              );
              final decryptedMessage = EncryptionHelper.decryptText(
                coded,
                widget.mediaKey!,
              );
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Message dÃƒÂ©chiffrÃƒÂ© = $decryptedMessage',
              );

              // 3. Enfin appliquer la langue inverse avec l'AAD dÃƒÂ©chiffrÃƒÂ©
              if (widget.multiLanguages!.containsKey(decryptedAAD)) {
                final selectedLanguage = widget.multiLanguages![decryptedAAD]!;
                debugPrint(
                  'Ã°Å¸Å½Â¯ TRADUCTION: Langue trouvÃƒÂ©e pour AAD $decryptedAAD',
                );
                decodedText = widget.applyReverseMap(
                  decryptedMessage,
                  selectedLanguage,
                );
                debugPrint(
                  'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement rÃƒÂ©ussi avec AAD dÃƒÂ©chiffrÃƒÂ©',
                );
                debugPrint(
                  'Ã°Å¸â€Â TRADUCTION: Texte dÃƒÂ©codÃƒÂ© = $decodedText',
                );
              } else {
                debugPrint(
                  'Ã¢ÂÅ’ TRADUCTION: AAD $decryptedAAD non trouvÃƒÂ© dans multiLanguages',
                );
                debugPrint(
                  'Ã°Å¸â€Â TRADUCTION: AADs disponibles: ${widget.multiLanguages!.keys.toList()}',
                );

                // ✅ CORRECTION : Utiliser la méthode unifiée avec réparation automatique
                try {
                  decodedText = MultiLanguageManager.decodeMessage(
                    coded,
                    encryptedAAD,
                    widget.multiLanguages!,
                    widget.mediaKey!,
                    autoRepairLanguages: true,
                  );
                  debugPrint(
                    '✅ TRADUCTION: Réparation automatique réussie: "$decodedText"',
                  );
                } catch (e) {
                  debugPrint(
                    '❌ TRADUCTION: Réparation automatique échouée: $e',
                  );
                  decodedText = '[AAD non trouvÃƒÂ©: $decryptedAAD]';
                }
              }
            } catch (e) {
              debugPrint('Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement: $e');
              // En cas d'erreur, essayer sans dÃƒÂ©chiffrement RSA mais avec AAD dÃƒÂ©chiffrÃƒÂ©
              try {
                final decryptedAAD = MultiLanguageManager.decryptAAD(
                  encryptedAAD,
                  widget.mediaKey!,
                );
                if (widget.multiLanguages!.containsKey(decryptedAAD)) {
                  final selectedLanguage =
                      widget.multiLanguages![decryptedAAD]!;
                  decodedText = widget.applyReverseMap(coded, selectedLanguage);
                  debugPrint(
                    'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement direct rÃƒÂ©ussi avec AAD dÃƒÂ©chiffrÃƒÂ©',
                  );
                } else {
                  // ✅ CORRECTION : Utiliser la méthode unifiée avec réparation automatique
                  try {
                    decodedText = MultiLanguageManager.decodeMessage(
                      coded,
                      encryptedAAD,
                      widget.multiLanguages!,
                      widget.mediaKey!,
                      autoRepairLanguages: true,
                    );
                    debugPrint(
                      '✅ TRADUCTION: Réparation automatique réussie (fallback): "$decodedText"',
                    );
                  } catch (e) {
                    debugPrint(
                      '❌ TRADUCTION: Réparation automatique échouée (fallback): $e',
                    );
                    decodedText = '[AAD non trouvÃƒÂ©: $decryptedAAD]';
                  }
                }
              } catch (e2) {
                debugPrint(
                  'Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement direct: $e2',
                );
                decodedText = '[Erreur dÃƒÂ©chiffrement: $e]';
              }
            }
          } else if (encryptedAAD == null &&
              widget.langMap != null &&
              !widget.isMultiLanguageMode) {
            // Ã¢Å“â€¦ RÃƒâ€°TROCOMPATIBILITÃƒâ€°: Mode ancien (1 langue) - SEULEMENT pour messages sans AAD ET pas en mode multi-langues
            debugPrint(
              'Ã°Å¸â€â€ž TRADUCTION: Mode ancien (1 langue) - message sans AAD',
            );
            try {
              // 1. D'abord dÃƒÂ©chiffrer le message avec mediaKey
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Tentative dÃƒÂ©chiffrement ancien...',
              );
              final decryptedMessage = EncryptionHelper.decryptText(
                coded,
                widget.mediaKey!,
              );
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Message dÃƒÂ©chiffrÃƒÂ© = $decryptedMessage',
              );

              // 2. Puis appliquer la langue inverse
              decodedText = widget.applyReverseMap(
                decryptedMessage,
                widget.langMap!,
              );
              debugPrint(
                'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement ancien rÃƒÂ©ussi',
              );
              debugPrint(
                'Ã°Å¸â€Â TRADUCTION: Texte dÃƒÂ©codÃƒÂ© = $decodedText',
              );
            } catch (e) {
              debugPrint(
                'Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement ancien: $e',
              );
              // En cas d'erreur, essayer sans dÃƒÂ©chiffrement RSA
              try {
                decodedText = widget.applyReverseMap(coded, widget.langMap!);
                debugPrint(
                  'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement ancien direct rÃƒÂ©ussi',
                );
              } catch (e2) {
                debugPrint(
                  'Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement ancien direct: $e2',
                );
                decodedText = '[Erreur dÃƒÂ©chiffrement ancien: $e]';
              }
            }
          } else if (encryptedAAD == null &&
              widget.isMultiLanguageMode &&
              widget.langMap != null) {
            // Ã¢Å“â€¦ RÃƒâ€°TROCOMPATIBILITÃƒâ€°: Message ancien sans AAD - utiliser la premiÃƒÂ¨re langue
            debugPrint(
              'Ã°Å¸â€â€ž TRADUCTION: Message ancien sans AAD - utilisation premiÃƒÂ¨re langue',
            );
            try {
              // 1. D'abord dÃƒÂ©chiffrer le message avec mediaKey
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Tentative dÃƒÂ©chiffrement ancien...',
              );
              final decryptedMessage = EncryptionHelper.decryptText(
                coded,
                widget.mediaKey!,
              );
              debugPrint(
                'Ã°Å¸â€â€œ TRADUCTION: Message dÃƒÂ©chiffrÃƒÂ© = $decryptedMessage',
              );

              // 2. Puis appliquer la premiÃƒÂ¨re langue (rÃƒÂ©trocompatibilitÃƒÂ©)
              decodedText = widget.applyReverseMap(
                decryptedMessage,
                widget.langMap!,
              );
              debugPrint(
                'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement ancien rÃƒÂ©ussi avec premiÃƒÂ¨re langue',
              );
              debugPrint(
                'Ã°Å¸â€Â TRADUCTION: Texte dÃƒÂ©codÃƒÂ© = $decodedText',
              );
            } catch (e) {
              debugPrint(
                'Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement ancien: $e',
              );
              // En cas d'erreur, essayer sans dÃƒÂ©chiffrement RSA
              try {
                decodedText = widget.applyReverseMap(coded, widget.langMap!);
                debugPrint(
                  'Ã¢Å“â€¦ TRADUCTION: DÃƒÂ©chiffrement ancien direct rÃƒÂ©ussi',
                );
              } catch (e2) {
                debugPrint(
                  'Ã¢ÂÅ’ TRADUCTION: Erreur dÃƒÂ©chiffrement ancien direct: $e2',
                );
                decodedText = '[Erreur dÃƒÂ©chiffrement ancien]';
              }
            }
          } else if (encryptedAAD == null && widget.isMultiLanguageMode) {
            // Ã¢ÂÅ’ PROBLÃƒË†ME: Message sans AAD et sans langMap
            debugPrint(
              'Ã¢ÂÅ’ TRADUCTION: Message sans AAD et sans premiÃƒÂ¨re langue',
            );
            decodedText = '[Message ancien - langue manquante]';
          } else {
            debugPrint('Ã¢Å¡Â Ã¯Â¸Â TRADUCTION: Aucune langue disponible');
            debugPrint(
              'Ã°Å¸â€Â TRADUCTION: DÃƒÂ©tails - encryptedAAD: $encryptedAAD, isMultiLanguageMode: ${widget.isMultiLanguageMode}, multiLanguages: ${widget.multiLanguages != null}, mediaKey: ${widget.mediaKey != null}, langMap: ${widget.langMap != null}',
            );
            decodedText = coded; // Aucune langue disponible
          }

          // Ãƒâ€°tape 2: DÃƒÂ©cider si on affiche dÃƒÂ©codÃƒÂ© ou codÃƒÂ© selon le mode traduction
          if (translateThisBubble) {
            displayText = decodedText; // Mode traduction: afficher dÃƒÂ©codÃƒÂ©
            debugPrint(
              'Ã°Å¸â€œâ€“ TRADUCTION: Affichage mode traduit = $displayText',
            );
          } else {
            displayText = coded; // Mode normal: afficher codÃƒÂ©
            debugPrint(
              'Ã°Å¸â€â€™ TRADUCTION: Affichage mode codÃƒÂ© = $displayText',
            );
          }
        }

        // Ã°Å¸Å½Â¨ Utiliser le nouveau systÃƒÂ¨me de thÃƒÂ¨me
        final themeManager = globalThemeManager;
        Color bubbleColor = themeManager.getMessageBubbleColor(isFromMe);
        Color textColor = themeManager.getTextColor(isFromMe);
        Color timeColor = themeManager.getSecondaryTextColor();
        Border? bubbleBorder = themeManager.getMessageBubbleBorder(isFromMe);
        List<BoxShadow>? bubbleShadow = themeManager.getMessageBubbleShadow(
          isFromMe,
        );

        if (_selectedIndex == index && _menuOverlay != null) {
          return const SizedBox(height: 55);
        }

        // VÃƒÂ©rifier si c'est le dernier message pour appliquer l'animation

        Widget messageWidget = Column(
          crossAxisAlignment: isFromMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: _selectedIndex == index ? _bubbleKey : null,
              onLongPress: () => _showBubbleMenu(index),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                  border: bubbleBorder,
                  boxShadow: bubbleShadow,
                ),
                child: Text(
                  displayText,
                  style: TextStyle(fontSize: 16, color: textColor),
                ),
              ),
            ),
            // Widget de rÃƒÂ©actions
            if (msg['id'] != null && msgType == 'text')
              MessageReactionsWidget(
                messageId: msg['id'],
                relationId: widget.relationId,
                onReactionChanged: () {
                  // Optionnel : rafraÃƒÂ®chir les donnÃƒÂ©es si nÃƒÂ©cessaire
                },
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ã°Å¸â€Â¥ Indicateur ÃƒÂ©phÃƒÂ©mÃƒÂ¨re
                if (msg['ephemeral'] != null &&
                    msg['ephemeral']['enabled'] == true) ...[
                  EphemeralIndicator(
                    ephemeralData: msg['ephemeral'],
                    isFromMe: isFromMe,
                    isCompact: true,
                  ),
                  const SizedBox(width: 4),
                ],
                // Ã°Å¸â€Â¥ Indicateur de compte ÃƒÂ  rebours si le message expire bientÃƒÂ´t
                if (msg['ephemeral'] != null &&
                    msg['ephemeral']['enabled'] == true &&
                    msg['ephemeral']['expiresAt'] != null) ...[
                  EphemeralCountdownIndicator(
                    expiresAt: DateTime.tryParse(msg['ephemeral']['expiresAt']),
                    isFromMe: isFromMe,
                    onExpired: () {
                      // Le message a expirÃƒÂ©, on pourrait le supprimer de l'interface
                      // ou marquer visuellement qu'il est expirÃƒÂ©
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  msg['time'] ?? '',
                  style: TextStyle(color: timeColor, fontSize: 12),
                ),
                if (isFromMe)
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 15,
                    color: isRead ? Colors.cyanAccent : timeColor,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );

        return _wrapWithHighlight(msg, messageWidget);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromMe;

  const _Bubble({required this.text, required this.fromMe});

  @override
  Widget build(BuildContext context) {
    // Ã°Å¸Å½Â¨ Utiliser le nouveau systÃƒÂ¨me de thÃƒÂ¨me
    final themeManager = globalThemeManager;
    Color bubbleColor = themeManager.getMessageBubbleColor(fromMe);
    Color textColor = themeManager.getTextColor(fromMe);
    Border? bubbleBorder = themeManager.getMessageBubbleBorder(fromMe);
    List<BoxShadow>? bubbleShadow = themeManager.getMessageBubbleShadow(fromMe);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(12),
        border: bubbleBorder,
        boxShadow: bubbleShadow,
      ),
      child: Text(text, style: TextStyle(fontSize: 16, color: textColor)),
    );
  }
}
