# Migration AES-CBC vers AES-256-GCM

## 🎯 Objectif

Remplacer l'usage d'AES-CBC par AES-256-GCM (AEAD) pour tous les chiffrages applicatifs afin d'ajouter intégrité/authenticité et éviter les vulnérabilités padding-oracle.

## 📋 Spécifications Techniques

### Algorithme
- **AES-256-GCM** (AEAD)
- **Tag d'authentification** : 128 bits
- **IV/Nonce** : 12 bytes (96 bits) aléatoires cryptographiquement sûrs
- **Format** : `base64(nonce || ciphertext || tag)`

### Versions Supportées
- **v2.3** : Mode per-character avec GCM
- **v2.2** : Mode per-character avec CBC (rétrocompatibilité)
- **v2.0** : Mode single-language avec CBC (rétrocompatibilité)

## 🔧 Implémentation

### 1. Nouveau Module GCM

```dart
// lib/core/utils/encryption_gcm_helper.dart
class EncryptionGCMHelper {
  static const String GCM_VERSION = '2.3';
  static const int NONCE_SIZE = 12;
  static const int TAG_SIZE = 16;
  
  static String encryptTextGCM(String plainText, String mediaKey, {String? aadData});
  static String decryptTextGCM(String encryptedPayload, String mediaKey, {String? aadData});
  static bool isGCMFormat(String payload);
}
```

### 2. Extension MultiLanguageManager

```dart
// Nouvelles méthodes ajoutées
static Map<String, dynamic> prepareMessageWithPerCharacterModeGCM(...);
static String decodeMessageWithPerCharacterModeGCM(...);
static String decodeMessageUnified(...); // Détection automatique CBC/GCM
```

### 3. Méthode Unifiée

```dart
// Utilisation recommandée
final prepared = MultiLanguageManager.prepareMessage(
  message,
  languages,
  mediaKey,
  useGCMEncryption: true, // Active GCM
  useAuthenticatedAAD: true, // AAD authentifié mais non chiffré
);

final decoded = MultiLanguageManager.decodeMessageUnified(
  prepared['encryptedContent'],
  prepared['encryptedAAD'],
  languages,
  mediaKey,
);
```

## 🔄 Processus de Migration

### Phase 1 : Déploiement Graduel
1. **Déployer le code** avec support GCM + rétrocompatibilité CBC
2. **Activer GCM** progressivement (feature flag)
3. **Monitorer** les métriques d'authentification

### Phase 2 : Migration Active
1. **Nouveaux messages** en GCM par défaut
2. **Anciens messages** décodés en CBC
3. **Conversations mixtes** supportées

### Phase 3 : Finalisation
1. **Désactiver CBC** pour nouveaux messages
2. **Conserver support lecture** CBC pour historique
3. **Monitoring continu** des échecs d'authentification

## 📊 Formats de Message

### Format GCM (v2.3)

```json
{
  "receiver": "user_id",
  "content": "base64(nonce||ciphertext||tag)",
  "encryptedAAD": "base64(aad_json)", // Option A: AAD authentifié
  "encryptedAAD": "base64(nonce||aad_cipher||tag)", // Option B: AAD chiffré
  "relationId": "conversation_id"
}
```

### AAD Structure (v2.3)

```json
{
  "v": "2.3",
  "enc": "gcm",
  "mode": "perchar-seq",
  "seq": ["lang_00", "lang_04", "lang_02", ...],
  "msgLen": 5,
  "timestamp": 1640995200000
}
```

## 🛡️ Sécurité

### Avantages GCM
- ✅ **Authentification** : Détection de modification
- ✅ **Intégrité** : Vérification automatique
- ✅ **Performance** : Parallélisable
- ✅ **Standard** : Largement adopté

### Gestion des Erreurs
```dart
try {
  final decoded = decodeMessageUnified(...);
} catch (e) {
  if (e is AuthenticationException) {
    // Message compromis ou corrompu
    showError("Message compromis");
  }
}
```

## 📈 Monitoring

### Métriques Clés
- **Taux d'échec authentification GCM** : < 0.01%
- **Latence chiffrement/déchiffrement** : p50/p95
- **Répartition CBC vs GCM** : pendant migration
- **Erreurs de format** : détection problèmes

### Alertes
- **Pic d'échecs authentification** : possible attaque
- **Dégradation performance** : problème implémentation
- **Erreurs de format** : problème compatibilité

## 🧪 Tests

### Tests Unitaires
```bash
flutter test test/encryption_gcm_migration_test.dart
```

### Tests d'Acceptation
1. **Round-trip GCM** : message → chiffré → déchiffré ✅
2. **Détection tampering** : modification → échec auth ✅
3. **Rétrocompatibilité** : CBC → GCM décodage ✅
4. **Performance** : GCM ≤ 3x temps CBC ✅

## 🚀 Déploiement

### Checklist Pré-Déploiement
- [ ] Tests unitaires passent (100%)
- [ ] Tests d'intégration validés
- [ ] Monitoring configuré
- [ ] Feature flags préparés
- [ ] Plan de rollback défini
- [ ] Documentation mise à jour

### Commandes de Déploiement
```bash
# Tests complets
flutter test

# Build avec GCM activé
flutter build apk --release --dart-define=ENABLE_GCM=true

# Vérification
flutter analyze
```

## 🔧 Configuration

### Variables d'Environnement
```dart
// Activation GCM
const bool enableGCM = bool.fromEnvironment('ENABLE_GCM', defaultValue: true);

// Mode AAD
const bool useAuthenticatedAAD = bool.fromEnvironment('USE_AUTH_AAD', defaultValue: true);
```

### Feature Flags
```dart
// Contrôle fin de la migration
final gcmConfig = {
  'enableGCMEncryption': true,
  'enableGCMDecryption': true,
  'fallbackToCBC': true,
  'monitoringEnabled': true,
};
```

## 📚 Références

### Standards
- **RFC 5116** : AEAD Interface
- **NIST SP 800-38D** : GCM Mode
- **RFC 7539** : ChaCha20-Poly1305 (alternative)

### Documentation Interne
- `docs/how_per_character_works.md` : Mode per-character
- `docs/troubleshooting_language_sync.md` : Dépannage
- `test/encryption_gcm_migration_test.dart` : Tests complets

## ⚠️ Notes Importantes

### Sécurité Critique
- **JAMAIS réutiliser un nonce** avec la même clé
- **Toujours vérifier le tag** avant utilisation
- **Rotation des clés** recommandée périodiquement

### Performance
- **Cache des reverse-maps** maintenu
- **Pré-calcul** des transformations
- **Parallélisation** possible avec GCM

### Compatibilité
- **Support CBC** maintenu pour lecture
- **Détection automatique** du format
- **Migration transparente** pour utilisateurs

---

**Status** : ✅ Implémentation complète  
**Version** : v2.3  
**Date** : 2024-01-01  
**Auteur** : Migration Team
