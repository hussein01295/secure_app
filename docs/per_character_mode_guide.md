# Guide du Mode Per-Character (v2.2)

## Vue d'ensemble

Le mode "per-character" (v2.2) est une évolution du système de transformation de langues qui applique une langue différente à chaque caractère du message, offrant une sécurité renforcée par rapport au mode "single-language" (v2.0).

## Fonctionnalités

### ✅ Nouveautés v2.2
- **Transformation par caractère** : Chaque caractère utilise une langue différente
- **Séquence aléatoire** : La séquence de langues est générée aléatoirement
- **AAD étendu** : Format JSON avec métadonnées complètes
- **Détection automatique** : Reconnaissance automatique du mode de message
- **Cache optimisé** : Reverse-maps pré-calculées pour les performances
- **Compatibilité totale** : Fonctionne avec tous les formats existants

### 🔄 Compatibilité
- **v1.0** : Mode mono-langue (langMap unique)
- **v2.0** : Mode multi-langues (une langue par message)
- **v2.2** : Mode per-character (une langue par caractère)

## Architecture

### Format AAD v2.2
```json
{
  "v": "2.2",
  "mode": "perchar-seq",
  "seq": ["lang_01", "lang_05", "lang_09", "lang_01", "lang_04"]
}
```

### Flux de données
```
Message original → Séquence de langues → Transformation → Chiffrement → Envoi
     ↓                      ↓                  ↓             ↓
   "salut"    → [lang_01,lang_05,...]  → "qsazd"  → encrypted → content
```

## Utilisation

### Envoi de message
```dart
// Méthode unifiée (recommandée)
final result = MultiLanguageManager.prepareMessage(
  'votre message',
  multiLanguages,
  mediaKey,
  forcePerCharacterMode: true, // Active le mode per-character
);

// Récupérer les données pour l'envoi
final codedText = result['codedText'];
final encryptedAAD = result['encryptedAAD'];
```

### Réception de message
```dart
// Décodage automatique (détecte le mode)
final decodedText = MultiLanguageManager.decodeMessage(
  codedText,
  encryptedAAD,
  multiLanguages,
  mediaKey,
);
```

### Détection du mode
```dart
final modeInfo = MultiLanguageManager.detectMessageMode(encryptedAAD, mediaKey);
final isPerCharacter = modeInfo['isPerCharacter'] as bool;
final version = modeInfo['version'] as String;
```

## Optimisations

### Cache des reverse-maps
```dart
// Pré-calcul automatique
MultiLanguageManager.precomputeReverseMaps(languages);

// Statistiques du cache
final stats = MultiLanguageManager.getCacheStats();
print('Reverse-maps en cache: ${stats['reverseMapsCount']}');

// Nettoyage du cache
MultiLanguageManager.clearReverseMapsCache();
```

### Performance
- **Pré-calcul** : Les reverse-maps sont calculées une seule fois
- **Cache intelligent** : Détection automatique des changements de langues
- **Parallélisation** : Traitement optimisé caractère par caractère

## Cas d'usage

### 1. Message normal
```dart
const message = "hello world";
// Résultat : chaque caractère transformé avec une langue différente
// h(lang_03) e(lang_07) l(lang_01) l(lang_09) o(lang_02) ...
```

### 2. Caractères spéciaux
```dart
const message = "café@2024!";
// Les caractères non mappés restent inchangés
// c(lang_01) a(lang_05) f(lang_03) é(inchangé) @(inchangé) ...
```

### 3. Message vide
```dart
const message = "";
// Séquence vide, AAD valide, pas d'erreur
```

## Gestion d'erreurs

### Fallback automatique
```dart
// Si moins de 10 langues → fallback vers v2.0
final result = MultiLanguageManager.prepareMessage(
  message,
  insufficientLanguages, // < 10 langues
  mediaKey,
  forcePerCharacterMode: true,
);
// Utilise automatiquement le mode single-language
```

### Robustesse
- **Clé manquante** : Affichage du texte codé
- **AAD corrompu** : Tentative de fallback vers v2.0
- **Langue manquante** : Caractère inchangé
- **Longueur incohérente** : Affichage sécurisé

## Migration

### Depuis v1.0 (mono-langue)
```dart
// Ancien code
final coded = ChatUtils.applyLanguageMap(text, langMap);

// Nouveau code (compatible)
final result = MultiLanguageManager.prepareMessage(text, multiLanguages, mediaKey);
```

### Depuis v2.0 (multi-langues)
```dart
// Ancien code
final result = MultiLanguageManager.prepareMessageWithRandomLanguage(text, languages, mediaKey);

// Nouveau code (per-character activé)
final result = MultiLanguageManager.prepareMessage(text, languages, mediaKey, forcePerCharacterMode: true);
```

## Tests

### Tests unitaires
```bash
flutter test test/multi_language_per_character_test.dart
```

### Exemple pratique
```bash
dart run example/per_character_mode_example.dart
```

## Sécurité

### Avantages du mode per-character
- **Diversité** : Chaque caractère utilise une transformation différente
- **Imprévisibilité** : Séquence aléatoire pour chaque message
- **Résistance** : Plus difficile à analyser que le mode single-language

### Considérations
- **Métadonnées** : La séquence est chiffrée dans l'AAD
- **Clé unique** : Une seule mediaKey pour tout le processus
- **Intégrité** : Vérification de cohérence des longueurs

## Dépannage

### Problèmes courants

1. **"Langue introuvable"**
   - Vérifier que les 10 langues sont présentes
   - Contrôler la cohérence des clés (lang_00 à lang_09)

2. **"Longueur incohérente"**
   - Vérifier l'intégrité de l'AAD
   - Contrôler que le message n'a pas été tronqué

3. **"Erreur de déchiffrement"**
   - Vérifier la mediaKey
   - Contrôler la compatibilité des versions

### Debug
```dart
// Activer les logs détaillés
debugPrint('Mode détecté: ${modeInfo['mode']}');
debugPrint('Séquence: ${result['sequence']}');
debugPrint('Cache stats: ${MultiLanguageManager.getCacheStats()}');
```

## Roadmap

### Améliorations futures
- **Compression** : Optimisation de la taille des séquences
- **Patterns** : Séquences déterministes pour certains cas
- **Analytics** : Statistiques d'utilisation des langues
- **Batch processing** : Traitement par lots pour de gros volumes
