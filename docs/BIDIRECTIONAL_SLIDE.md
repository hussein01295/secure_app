# Glissement Bidirectionnel - Guide Technique

## Vue d'ensemble

Le système de glissement permet maintenant un mouvement **bidirectionnel** : l'utilisateur peut glisser à gauche pour annuler, puis **changer d'avis** en reglissant vers la droite pour finalement envoyer le vocal.

## Comportement

### Scénario 1 : Glissement Simple (Annulation)

```
Position initiale (0px)
    │
    ├─► Glisse à gauche (-50px)
    │   └─► Progress: 41% (50/120)
    │       └─► Couleurs: Gris → Rouge (41%)
    │
    ├─► Continue à gauche (-120px)
    │   └─► Progress: 100% (120/120)
    │       └─► cancelReady = true
    │       └─► Haptique jouée ✓
    │       └─► UI: "Relâchez pour annuler" (ROUGE)
    │
    └─► Relâche
        └─► Annulation ❌
```

---

### Scénario 2 : Glissement avec Changement d'Avis (Envoi)

```
Position initiale (0px)
    │
    ├─► Glisse à gauche (-50px)
    │   └─► Progress: 41%
    │       └─► Couleurs: Gris → Rouge (41%)
    │
    ├─► Continue à gauche (-130px)
    │   └─► Progress: 108% → 100%
    │       └─► cancelReady = true
    │       └─► Haptique jouée ✓
    │       └─► UI: "Relâchez pour annuler" (ROUGE)
    │
    ├─► CHANGE D'AVIS : Reglisse à droite (-80px)
    │   └─► Progress: 66% (80/120)
    │       └─► cancelReady = false ✓
    │       └─► _hapticsPlayed = false (reset)
    │       └─► UI: "Glisser pour annuler" (Gris/Rouge 66%)
    │
    ├─► Continue à droite (-30px)
    │   └─► Progress: 25%
    │       └─► Couleurs: Gris → Rouge (25%)
    │
    └─► Relâche
        └─► Envoi du vocal ✅
```

---

### Scénario 3 : Oscillation Multiple

```
Position initiale (0px)
    │
    ├─► Glisse à gauche (-130px)
    │   └─► cancelReady = true, Haptique ✓
    │
    ├─► Reglisse à droite (-80px)
    │   └─► cancelReady = false
    │
    ├─► Re-glisse à gauche (-125px)
    │   └─► cancelReady = true, Haptique ✓ (rejoué)
    │
    ├─► Re-reglisse à droite (-50px)
    │   └─► cancelReady = false
    │
    └─► Relâche
        └─► Envoi du vocal ✅
```

---

## Implémentation Technique

### Code Clé

```dart
void _updateDrag(LongPressMoveUpdateDetails details) {
  if (!_isRecording) return;
  setState(() {
    // Utiliser offsetFromOrigin pour avoir la position absolue
    // Cela permet de glisser à gauche ET à droite
    _dx = details.offsetFromOrigin.dx;
    _dx = math.min(0, _dx); // on ne compte que vers la gauche (négatif)
    
    final progress = _cancelProgress;
    final nowReady = progress >= 1.0;
    
    // Transition vers cancelReady avec haptique
    if (nowReady && !_cancelReady) {
      _cancelReady = true;
      if (!_hapticsPlayed) {
        HapticFeedback.selectionClick();
        _hapticsPlayed = true;
      }
    } else if (!nowReady && _cancelReady) {
      // Retour en arrière : l'utilisateur a reglissé vers la droite
      _cancelReady = false;
      // Rejouer l'haptique si on repasse le seuil
      _hapticsPlayed = false;
    }
  });
}
```

### Différence Clé

**Avant** (Unidirectionnel) :
```dart
_dx += details.delta.dx;  // Accumulation incrémentale
_dx = math.min(0, _dx);   // Bloqué à gauche
```

**Après** (Bidirectionnel) :
```dart
_dx = details.offsetFromOrigin.dx;  // Position absolue depuis le début
_dx = math.min(0, _dx);              // Permet le retour vers la droite
```

---

## Calcul de la Progression

```dart
double get _cancelProgress {
  return (_dx.abs() / _cancelThreshold).clamp(0.0, 1.0);
}
```

### Exemples

| Position (_dx) | Abs | Progress | cancelReady |
|----------------|-----|----------|-------------|
| 0px            | 0   | 0%       | false       |
| -30px          | 30  | 25%      | false       |
| -60px          | 60  | 50%      | false       |
| -90px          | 90  | 75%      | false       |
| -120px         | 120 | 100%     | **true**    |
| -150px         | 150 | 100%*    | **true**    |
| -80px (retour) | 80  | 66%      | false       |
| -40px (retour) | 40  | 33%      | false       |

*Clampé à 100%

---

## Feedback Visuel Bidirectionnel

### Glissement vers la Gauche (Annulation)

```
0% ──────────────────────────────► 100%
│                                    │
Gris neutre                    Rouge alerte
│                                    │
"Glisser pour annuler"    "Relâchez pour annuler"
│                                    │
Poubelle position 0px         Poubelle -30px
│                                    │
Indicateur ◯                   Indicateur ●
```

### Glissement vers la Droite (Retour)

```
100% ◄──────────────────────────── 66%
│                                    │
Rouge alerte                   Gris/Rouge mix
│                                    │
"Relâchez pour annuler"    "Glisser pour annuler"
│                                    │
Poubelle -30px                Poubelle -20px
│                                    │
Indicateur ●                   Indicateur ◕
```

---

## Transitions d'État

### Diagramme d'État

```
┌─────────────┐
│    Idle     │
└──────┬──────┘
       │ Appui long
       ▼
┌─────────────────┐
│ Recording       │
│ (active)        │◄──────────┐
│ progress < 100% │           │
└────────┬────────┘           │
         │                    │
         │ Glisse gauche      │ Reglisse droite
         │ progress ≥ 100%    │ progress < 100%
         ▼                    │
┌─────────────────┐           │
│ Recording       │───────────┘
│ (cancelReady)   │
│ progress ≥ 100% │
└────────┬────────┘
         │
         │ Relâche
         ▼
    ┌────────┐
    │ Cancel │
    └────────┘
```

### Transitions Haptiques

```
active ──► cancelReady : Haptique jouée ✓
           _hapticsPlayed = true

cancelReady ──► active : _hapticsPlayed = false (reset)
                         Permet de rejouer l'haptique

active ──► cancelReady : Haptique rejouée ✓
           (si _hapticsPlayed = false)
```

---

## Interpolation de Couleurs Bidirectionnelle

### Fonction

```dart
Color _interpolateColor(Color a, Color b, double t) {
  return Color.lerp(a, b, t) ?? a;
}
```

### Exemples

**Glissement à gauche** :
```
t = 0.0  : surfaceContainerHighest (100%) + errorContainer (0%)
t = 0.25 : surfaceContainerHighest (75%)  + errorContainer (25%)
t = 0.50 : surfaceContainerHighest (50%)  + errorContainer (50%)
t = 0.75 : surfaceContainerHighest (25%)  + errorContainer (75%)
t = 1.0  : surfaceContainerHighest (0%)   + errorContainer (100%)
```

**Reglissement à droite** :
```
t = 1.0  : errorContainer (100%)
t = 0.66 : surfaceContainerHighest (34%)  + errorContainer (66%)
t = 0.33 : surfaceContainerHighest (67%)  + errorContainer (33%)
t = 0.0  : surfaceContainerHighest (100%)
```

---

## Animations Réactives

### Poubelle

```dart
Transform.translate(
  offset: Offset(-30 * t, 0),  // Suit la progression
  child: Transform.scale(
    scale: 0.9 + 0.2 * t,       // Suit la progression
    child: Icon(Icons.delete_outline),
  ),
)
```

**Bidirectionnel** :
- Gauche (t: 0 → 1) : Position 0px → -30px, Scale 0.9 → 1.1
- Droite (t: 1 → 0) : Position -30px → 0px, Scale 1.1 → 0.9

### Indicateur Circulaire

```dart
CircularProgressIndicator(
  value: t,  // Suit la progression bidirectionnelle
  strokeWidth: 2,
  valueColor: AlwaysStoppedAnimation<Color>(pillFg),
)
```

**Bidirectionnel** :
- Gauche (t: 0 → 1) : ◯ → ◔ → ◑ → ◕ → ●
- Droite (t: 1 → 0) : ● → ◕ → ◑ → ◔ → ◯

---

## Avantages du Glissement Bidirectionnel

✅ **Flexibilité** : L'utilisateur peut changer d'avis

✅ **Contrôle** : Pas de décision irréversible avant le relâchement

✅ **Feedback continu** : Les animations suivent le mouvement en temps réel

✅ **Haptique intelligent** : Rejoué à chaque passage du seuil

✅ **UX moderne** : Comportement identique à Instagram/WhatsApp

✅ **Prévention d'erreurs** : Évite les annulations accidentelles

---

## Tests Manuels

### Test 1 : Glissement Simple
1. Appui long sur micro
2. Glisser à gauche jusqu'à -130px
3. Observer "Relâchez pour annuler" (rouge)
4. Relâcher
5. ✅ Vérifier : Vocal annulé

### Test 2 : Changement d'Avis
1. Appui long sur micro
2. Glisser à gauche jusqu'à -130px
3. Observer "Relâchez pour annuler" (rouge)
4. **Reglisser à droite** jusqu'à -50px
5. Observer "Glisser pour annuler" (gris/rouge mix)
6. Relâcher
7. ✅ Vérifier : Vocal envoyé

### Test 3 : Oscillation
1. Appui long sur micro
2. Glisser gauche (-130px) → droite (-50px) → gauche (-130px) → droite (-30px)
3. Observer les transitions fluides
4. Sentir les vibrations à chaque passage du seuil
5. Relâcher
6. ✅ Vérifier : Vocal envoyé

---

## Performance

- **Calculs optimisés** : `offsetFromOrigin` au lieu d'accumulation
- **Rebuilds minimaux** : Seulement quand `_dx` change
- **Animations fluides** : 60 FPS garantis
- **Haptique contrôlé** : Joué une seule fois par transition

---

## Conclusion

Le glissement bidirectionnel offre une expérience utilisateur **flexible et moderne**, permettant à l'utilisateur de **changer d'avis** à tout moment avant de relâcher le bouton. C'est exactement le comportement attendu dans les applications de messagerie modernes ! 🎉

