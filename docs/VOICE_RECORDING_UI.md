# Interface d'Enregistrement Vocal - Guide Visuel

## Vue d'ensemble

L'interface d'enregistrement vocal a été optimisée pour éliminer la duplication des icônes et offrir une expérience utilisateur plus cohérente et élégante.

## États de l'Interface

### 1. État Normal (Idle)

```
┌─────────────────────────────────────────────────┐
│ [📷]  [  Ecrire un message...        ]  [🎤]   │
└─────────────────────────────────────────────────┘
```

**Éléments** :
- **Bouton photo** (gauche) : Accès au sélecteur de médias
- **Champ de texte** (centre) : Saisie de message
- **Bouton micro** (droite) : Appui long pour enregistrer

---

### 2. Début d'Enregistrement (t = 0%)

```
┌─────────────────────────────────────────────────┐
│ [●]  [🗑️ ← Glisser pour annuler  00:03 ◯]  [●🎤]│
└─────────────────────────────────────────────────┘
```

**Éléments** :
- **Point pulsant** (gauche) : Indicateur d'enregistrement actif
- **Pavé d'enregistrement** (centre) :
  - Icône poubelle
  - Flèche vers la gauche (←)
  - Texte "Glisser pour annuler"
  - Timer (00:03)
  - Indicateur circulaire de progression
- **Micro pulsant** (droite) : Cercle animé avec icône micro

**Couleurs** :
- Fond du pavé : `surfaceContainerHighest` (gris clair/foncé selon thème)
- Texte : `onSurfaceVariant`
- Point pulsant : `primary`

---

### 3. Glissement Progressif (t = 30-70%)

```
┌─────────────────────────────────────────────────┐
│ [●]  [🗑️  Glisser pour annuler  00:08 ◐]  [●🎤] │
└─────────────────────────────────────────────────┘
```

**Changements** :
- **Poubelle** : Glisse vers la gauche (-30px * t)
- **Poubelle** : Scale augmente (0.9 → 1.1)
- **Flèche** : Disparaît progressivement (opacity 1.0 → 0.0)
- **Couleurs** : Interpolation vers l'alerte
  - Fond : `surfaceContainerHighest` → `errorContainer`
  - Texte : `onSurfaceVariant` → `onErrorContainer`
- **Indicateur circulaire** : Se remplit progressivement
- **Pavé** : Translate légèrement à gauche (-8px * t)

---

### 4. Seuil Atteint (t = 100%, cancelReady)

```
┌─────────────────────────────────────────────────┐
│ [●]  [🗑️ Relâchez pour annuler  00:15 ●]  [●🎤] │
└─────────────────────────────────────────────────┘
     ↑ ROUGE                              ↑ ROUGE
```

**Changements** :
- **Texte** : "Relâchez pour annuler" (bold)
- **Couleurs** : Tout devient rouge
  - Fond : `errorContainer`
  - Texte : `onErrorContainer`
  - Point pulsant : `error`
  - Micro : `errorContainer`
- **Poubelle** : Scale maximum (1.1)
- **Indicateur circulaire** : Complètement rempli
- **Ombre** : Rouge avec alpha 0.2
- **Haptique** : Vibration jouée une seule fois

---

## Animations

### Pulse du Point Indicateur (gauche)

```dart
ScaleTransition(
  scale: Tween<double>(begin: 0.8, end: 1.0).animate(_pulseCtrl),
  child: Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _cancelReady ? error : primary,
    ),
  ),
)
```

**Durée** : 900ms (répété en boucle)

---

### Pulse du Micro (droite)

```dart
ScaleTransition(
  scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseCtrl),
  child: Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: interpolateColor(primaryContainer, errorContainer, t),
    ),
  ),
)
```

**Durée** : 900ms (répété en boucle)

---

### Glissement de la Poubelle

```dart
Transform.translate(
  offset: Offset(-30 * t, 0),
  child: Transform.scale(
    scale: 0.9 + 0.2 * t,
    child: Icon(Icons.delete_outline),
  ),
)
```

**Progression** :
- t = 0% : Position initiale, scale 0.9
- t = 50% : -15px, scale 1.0
- t = 100% : -30px, scale 1.1

---

### Disparition de la Flèche

```dart
if (t < 0.3)
  Opacity(
    opacity: 1.0 - (t / 0.3),
    child: Icon(Icons.arrow_back),
  )
```

**Progression** :
- t = 0% : Opacity 1.0 (visible)
- t = 15% : Opacity 0.5
- t = 30% : Opacity 0.0 (invisible)

---

### Translation du Pavé

```dart
Transform.translate(
  offset: Offset(-8 * t, 0),
  child: Row(...),
)
```

**Progression** :
- t = 0% : Position initiale
- t = 100% : -8px vers la gauche

---

## Interpolation de Couleurs

### Fond du Pavé

```
surfaceContainerHighest ──────────► errorContainer
     (gris neutre)         t=0→1      (rouge clair)
```

### Texte du Pavé

```
onSurfaceVariant ──────────► onErrorContainer
   (gris foncé)      t=0→1      (rouge foncé)
```

### Cercle du Micro

```
primaryContainer ──────────► errorContainer
    (bleu clair)     t=0→1      (rouge clair)
```

---

## Indicateur de Progression Circulaire

```
◯  →  ◔  →  ◑  →  ◕  →  ●
0%    25%   50%   75%   100%
```

**Implémentation** :
```dart
CircularProgressIndicator(
  value: t,
  strokeWidth: 2,
  valueColor: AlwaysStoppedAnimation<Color>(pillFg),
)
```

---

## Ombres et Élévation

### État Normal (t < 100%)

```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.05),
  blurRadius: 8,
  offset: Offset(0, 2),
)
```

### État cancelReady (t = 100%)

```dart
BoxShadow(
  color: theme.colorScheme.error.withValues(alpha: 0.2),
  blurRadius: 8,
  offset: Offset(0, 2),
)
```

---

## Gestes et Interactions

### Appui Long sur le Micro

```
Utilisateur appuie ──► _startRecording()
                       │
                       ├─► Timer démarre
                       ├─► Pulse démarre
                       └─► UI passe en mode Recording
```

### Glissement Horizontal

```
Utilisateur glisse ──► _updateDrag(details)
                       │
                       ├─► _dx mis à jour
                       ├─► _cancelProgress calculé
                       ├─► UI mise à jour
                       └─► Si t ≥ 1.0 → cancelReady + haptique
```

### Relâchement

```
Utilisateur relâche ──► _stopAndResolve()
                        │
                        ├─► Si cancelReady
                        │   └─► Annulation
                        │
                        └─► Sinon
                            └─► Envoi du vocal
```

---

## Avantages de la Nouvelle Interface

✅ **Pas de duplication** : Une seule icône poubelle dans le pavé

✅ **Feedback visuel clair** : Point pulsant à gauche indique l'enregistrement

✅ **Progression visible** : Indicateur circulaire montre la progression

✅ **Flèche guidante** : Apparaît au début puis disparaît

✅ **Interpolation fluide** : Transitions de couleurs progressives

✅ **Ombres adaptatives** : Changent selon l'état (normal/alerte)

✅ **Cohérence visuelle** : Tous les éléments suivent le même design system

---

## Accessibilité

- **Contraste AA** : Toutes les couleurs respectent le ratio minimum
- **Feedback haptique** : Vibration au passage du seuil
- **Animations fluides** : 60 FPS garantis
- **Tailles tactiles** : Minimum 48x48 dp pour tous les boutons
- **Sémantique** : Labels appropriés pour les lecteurs d'écran

---

## Performance

- **Frame budget** : < 16ms par frame
- **Animations** : Utilisation de `AnimatedContainer` et `Transform`
- **Interpolation** : `Color.lerp` optimisé
- **Rebuilds** : Minimisés avec `AnimatedSwitcher`

