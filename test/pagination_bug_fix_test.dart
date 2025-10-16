import 'package:flutter_test/flutter_test.dart';

/// 🔥 Test de la correction du bug de pagination
/// 
/// Ce test vérifie que la logique de fusion intelligente des messages
/// fonctionne correctement côté Flutter.

void main() {
  group('🔄 Fusion intelligente des messages', () {
    
    /// Fonction de fusion intelligente (copiée de la logique client)
    List<Map<String, dynamic>> mergeMessagesIntelligently(
      List<Map<String, dynamic>> currentMessages,
      List<Map<String, dynamic>> backendMessages,
    ) {
      // Préserver les messages locaux récents qui ne sont pas encore sur le serveur
      final localRecentMessages = currentMessages.where((localMsg) {
        // Garder les messages temporaires (en cours d'envoi)
        if (localMsg['sending'] == true) {
          return true;
        }
        
        // Garder les messages récents qui ne sont pas dans la réponse du serveur
        final messageId = localMsg['id'];
        if (messageId == null) return true;
        
        // Vérifier si ce message existe dans la réponse du serveur
        final existsInBackend = backendMessages.any((backendMsg) => 
          backendMsg['_id'] == messageId || backendMsg['id'] == messageId);
        
        return !existsInBackend;
      }).toList();

      // Créer la liste fusionnée
      final mergedMessages = <Map<String, dynamic>>[];
      
      // Ajouter d'abord les messages du serveur (les plus récents en premier)
      mergedMessages.addAll(backendMessages);
      
      // Ajouter ensuite les messages locaux récents qui ne sont pas sur le serveur
      for (final localMsg in localRecentMessages) {
        // Éviter les doublons en vérifiant l'ID et le contenu
        final isDuplicate = mergedMessages.any((msg) => 
          (msg['_id'] == localMsg['id'] || msg['id'] == localMsg['id']) ||
          (msg['content'] == localMsg['content'] && 
           msg['fromMe'] == localMsg['fromMe'] && 
           msg['messageType'] == localMsg['messageType']));
        
        if (!isDuplicate) {
          mergedMessages.add(localMsg);
        }
      }

      // Trier par timestamp pour maintenir l'ordre chronologique
      mergedMessages.sort((a, b) {
        final aTime = a['timestamp'] ?? a['time'] ?? '';
        final bTime = b['timestamp'] ?? b['time'] ?? '';
        return aTime.toString().compareTo(bTime.toString());
      });

      return mergedMessages;
    }

    test('🔥 Doit préserver les messages temporaires lors de la fusion', () {
      // Messages locaux avec un message temporaire
      final currentMessages = [
        {
          'id': 'msg1',
          'content': 'Message existant',
          'fromMe': false,
          'timestamp': '2024-01-01T10:00:00Z'
        },
        {
          'id': 'temp1',
          'content': 'Message en cours d\'envoi',
          'fromMe': true,
          'sending': true, // Message temporaire
          'timestamp': '2024-01-01T12:00:00Z'
        }
      ];

      // Messages du serveur (sans le message temporaire)
      final backendMessages = [
        {
          '_id': 'msg1',
          'content': 'Message existant',
          'fromMe': false,
          'timestamp': '2024-01-01T10:00:00Z'
        },
        {
          '_id': 'msg2',
          'content': 'Nouveau message du serveur',
          'fromMe': false,
          'timestamp': '2024-01-01T11:00:00Z'
        }
      ];

      final result = mergeMessagesIntelligently(currentMessages, backendMessages);

      // Vérifications
      expect(result.length, 3); // 2 du serveur + 1 temporaire
      expect(result.any((m) => m['sending'] == true), true);
      expect(result.any((m) => m['content'] == 'Message en cours d\'envoi'), true);
    });

    test('🔥 Doit éviter les doublons lors de la fusion', () {
      // Messages locaux avec un doublon
      final currentMessages = [
        {
          'id': 'msg1',
          'content': 'Message dupliqué',
          'fromMe': true,
          'timestamp': '2024-01-01T10:00:00Z'
        },
        {
          'id': 'temp1',
          'content': 'Message unique local',
          'fromMe': true,
          'sending': true,
          'timestamp': '2024-01-01T12:00:00Z'
        }
      ];

      // Messages du serveur avec le même message
      final backendMessages = [
        {
          '_id': 'msg1',
          'content': 'Message dupliqué',
          'fromMe': true,
          'timestamp': '2024-01-01T10:00:00Z'
        }
      ];

      final result = mergeMessagesIntelligently(currentMessages, backendMessages);

      // Vérifications
      expect(result.length, 2); // 1 du serveur + 1 temporaire (pas de doublon)
      expect(result.where((m) => m['content'] == 'Message dupliqué').length, 1);
      expect(result.any((m) => m['sending'] == true), true);
    });

    test('🔥 Doit préserver les messages récents non présents sur le serveur', () {
      // Messages locaux avec un message récent
      final currentMessages = [
        {
          'id': 'msg1',
          'content': 'Message ancien',
          'fromMe': false,
          'timestamp': '2024-01-01T10:00:00Z'
        },
        {
          'id': 'recent1',
          'content': 'Message récent local',
          'fromMe': true,
          'timestamp': '2024-01-01T12:00:00Z'
        }
      ];

      // Messages du serveur (sans le message récent)
      final backendMessages = [
        {
          '_id': 'msg1',
          'content': 'Message ancien',
          'fromMe': false,
          'timestamp': '2024-01-01T10:00:00Z'
        }
      ];

      final result = mergeMessagesIntelligently(currentMessages, backendMessages);

      // Vérifications
      expect(result.length, 2); // 1 du serveur + 1 récent local
      expect(result.any((m) => m['content'] == 'Message récent local'), true);
    });

    test('🔥 Scénario complet : Bug de pagination corrigé', () {
      // Simulation du scénario problématique :
      // 1. UserA a des messages locaux incluant un message récent
      // 2. La pagination du serveur ne retourne que les 30 derniers messages
      // 3. Le message récent de UserA n'est pas dans cette page
      // 4. La fusion doit préserver le message récent

      final currentMessages = [
        // Messages anciens (simulés comme déjà synchronisés)
        {
          'id': 'old1',
          'content': 'Message ancien 1',
          'fromMe': false,
          'timestamp': '2024-01-01T09:00:00Z'
        },
        // Message récent de UserA qui n'est pas encore dans la pagination du serveur
        {
          'id': 'recent_userA',
          'content': 'Message récent de UserA',
          'fromMe': true,
          'timestamp': '2024-01-01T15:00:00Z'
        }
      ];

      // Pagination du serveur (ne contient que les 30 derniers messages)
      // Le message récent de UserA n'y est pas car il n'a pas encore été synchronisé
      final backendMessages = [
        {
          '_id': 'old1',
          'content': 'Message ancien 1',
          'fromMe': false,
          'timestamp': '2024-01-01T09:00:00Z'
        },
        {
          '_id': 'other1',
          'content': 'Autre message',
          'fromMe': false,
          'timestamp': '2024-01-01T14:00:00Z'
        }
      ];

      final result = mergeMessagesIntelligently(currentMessages, backendMessages);

      // Vérifications : le message récent de UserA doit être préservé
      expect(result.length, 3);
      final userAMessage = result.firstWhere(
        (m) => m['content'] == 'Message récent de UserA',
        orElse: () => <String, dynamic>{},
      );
      expect(userAMessage.isNotEmpty, true);
      expect(userAMessage['fromMe'], true);
    });

    test('🔥 Doit trier les messages par timestamp', () {
      // Messages locaux
      final currentMessages = [
        {
          'id': 'temp1',
          'content': 'Message temporaire récent',
          'fromMe': true,
          'sending': true,
          'timestamp': '2024-01-01T14:00:00Z'
        }
      ];

      // Messages du serveur
      final backendMessages = [
        {
          '_id': 'msg2',
          'content': 'Message du milieu',
          'fromMe': false,
          'timestamp': '2024-01-01T12:00:00Z'
        },
        {
          '_id': 'msg1',
          'content': 'Message ancien',
          'fromMe': false,
          'timestamp': '2024-01-01T10:00:00Z'
        }
      ];

      final result = mergeMessagesIntelligently(currentMessages, backendMessages);

      // Vérifications du tri
      expect(result.length, 3);
      expect(result[0]['content'], 'Message ancien');
      expect(result[1]['content'], 'Message du milieu');
      expect(result[2]['content'], 'Message temporaire récent');
    });
  });
}
