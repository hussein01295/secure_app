# Implémentation "Slide-to-Cancel" pour Messages Vocaux

## Vue d'ensemble

Cette fonctionnalité implémente un système d'enregistrement vocal avec annulation par glissement, inspiré d'Instagram et d'autres applications de messagerie modernes.

## Spécifications Techniques

### États

1. **Idle** : Pas d'enregistrement en cours
2. **Recording(active)** : Enregistrement en cours, UI "glisser pour annuler" visible
3. **Recording(cancelReady)** : Seuil d'annulation dépassé, UI passe en mode "relâcher pour annuler"

### Gestes

- **Appui long sur le micro** → Démarre l'enregistrement (Recording active)
- **Glissement horizontal vers la gauche** pendant l'appui :
  - Calcul de `cancelProgress = clamp((-dx) / cancelThreshold, 0..1)`
  - Quand `cancelProgress ≥ 1` → passe en Recording(cancelReady) avec haptique
- **Relâcher** :
  - Si `cancelReady` → annule l'enregistrement
  - Sinon → envoie le message vocal

### Constantes UX

```dart
static const double _cancelThreshold = 120.0;  // mobile (160px pour tablette)
static const Duration _pulseDuration = Duration(milliseconds: 900);
static const Duration _animDuration = Duration(milliseconds: 180);
```

## Interface Utilisateur

### Pavé Indicatif (Pill)

Affiche pendant l'enregistrement avec :
- **Texte dynamique** : "Glisser ← pour annuler" → "Relâchez pour annuler"
- **Icône poubelle** : Glisse de droite à gauche selon `cancelProgress`
- **Barre de progression** : Indicateur visuel de 0 à 100%
- **Timer** : Affiche la durée d'enregistrement (format mm:ss)

### Animations

1. **Cercle "on parle"** au-dessus du micro :
   - Pulse avec scale 0.9 ↔ 1.1
   - Couleur interpole vers l'alerte à mesure que `cancelProgress` augmente
   - `primaryContainer` → `errorContainer`

2. **Pavé indicatif** :
   - Se déplace légèrement à gauche (TranslateX: -8px * progress)
   - Change de couleur progressivement (neutre → alerte)
   - `surfaceVariant` → `errorContainer`

3. **Icône poubelle** :
   - Translation horizontale : -24px * progress
   - Scale : 0.9 + 0.2 * progress

### État cancelReady

Quand le seuil est atteint :
- Texte devient "Relâchez pour annuler"
- Couleur d'arrière-plan rouge clair (`errorContainer`)
- Icône poubelle accentuée (scale 1.1)
- Vibration haptique (jouée une seule fois)

## Interpolation de Couleurs

```dart
Color _interpolateColor(Color a, Color b, double t) {
  return Color.lerp(a, b, t) ?? a;
}
```

Utilisée pour :
- Background du pavé : `surfaceVariant` → `errorContainer`
- Texte du pavé : `onSurfaceVariant` → `onErrorContainer`
- Cercle du micro : `primaryContainer` → `errorContainer`

## Accessibilité

- Annonce sémantique : "Glisser à gauche pour annuler l'enregistrement"
- Contraste AA sur toutes les couleurs
- Feedback haptique pour confirmer l'entrée en mode cancelReady

## Critères d'Acceptation

✅ En appui long, l'UI affiche le pavé "Glisser ← pour annuler" + poubelle animée + cercle "on parle"

✅ Le progress visuel suit la distance de glisse (couleur, translation, icône)

✅ Au-delà du seuil, le texte passe à "Relâchez pour annuler", haptique jouée une seule fois

✅ Relâcher avant seuil → envoi du vocal

✅ Relâcher après seuil → annulation

✅ Aucune saccade (> 16ms frame budget) sur appareils cibles

## Architecture du Code

### Fichier Principal

`lib/features/chat/widgets/input/chat_input_bar_widget.dart`

### Variables d'État

```dart
bool _isRecording = false;
bool _cancelReady = false;
Duration _recordDuration = Duration.zero;
Timer? _timer;
double _dx = 0.0;  // déplacement horizontal
bool _hapticsPlayed = false;
```

### Méthodes Principales

1. **`_startRecording()`** : Démarre l'enregistrement et le timer
2. **`_updateDrag(LongPressMoveUpdateDetails)`** : Met à jour la progression du glissement
3. **`_stopAndResolve()`** : Décide d'envoyer ou d'annuler selon `_cancelReady`
4. **`_cancelRecording()`** : Annule et réinitialise l'état
5. **`_buildRecordingUI()`** : Construit l'interface d'enregistrement avec animations

### Calculs

```dart
double get _cancelProgress {
  return (_dx.abs() / _cancelThreshold).clamp(0.0, 1.0);
}
```

## Intégration

Le widget `ChatInputBar` gère automatiquement :
- Le basculement entre mode texte et mode vocal
- L'affichage du bouton photo/média
- L'animation du bouton micro avec pulse
- Le glissement pour annulation

### Callbacks

```dart
ChatInputBar(
  onSendMessage: () async {},
  controller: textController,
  chatController: chatController,
  enabled: true,
  onSendVoice: (Duration duration) {
    // Traiter l'envoi du message vocal
  },
  onSendText: (String text) {
    // Traiter l'envoi du message texte
  },
)
```

## Performance

- Animations à 60 FPS garanties
- Utilisation de `AnimatedContainer` pour les transitions fluides
- `ScaleTransition` pour le pulse du cercle
- Interpolation de couleurs optimisée avec `Color.lerp`

## Tests

Pour tester manuellement :
1. Appui long sur le bouton micro
2. Observer le pavé "Glisser ← pour annuler"
3. Glisser vers la gauche progressivement
4. Observer les changements de couleur et d'échelle
5. Dépasser le seuil (120px) pour voir "Relâchez pour annuler"
6. Sentir la vibration haptique
7. Relâcher pour annuler ou revenir en arrière pour envoyer

## Améliorations Futures

- [ ] Support tablette avec seuil de 160px
- [ ] Callback `onCancel` pour afficher un toast/snackbar
- [ ] Enregistrement audio réel avec package `record`
- [ ] Upload vers le backend avec chiffrement
- [ ] Lecture des messages vocaux reçus avec `just_audio`

## Références

- Spécification originale : Voir le document de spécification "Slide-to-cancel"
- Inspiration : Instagram, WhatsApp, Telegram
- Package audio (futur) : `record: ^6.1.1`, `just_audio: ^0.10.4`

