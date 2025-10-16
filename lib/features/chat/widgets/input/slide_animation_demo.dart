import 'package:flutter/material.dart';

/// Démo de l'animation de glissement pour annulation d'enregistrement vocal
/// 
/// Cette démo montre comment l'animation de glissement fonctionne :
/// 1. Appui long sur le microphone → début d'enregistrement
/// 2. Glissement vers la gauche → animation de glissement avec indicateur
/// 3. Glissement au-delà du seuil → annulation automatique
/// 4. Relâchement avant le seuil → retour à la position initiale
class SlideAnimationDemo extends StatefulWidget {
  const SlideAnimationDemo({super.key});

  @override
  State<SlideAnimationDemo> createState() => _SlideAnimationDemoState();
}

class _SlideAnimationDemoState extends State<SlideAnimationDemo>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isDragging = false;
  double _dragDistance = 0.0;
  static const double _cancelThreshold = 100.0;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _isDragging = false;
      _dragDistance = 0.0;
    });
    _slideCtrl.reset();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isRecording) {
      setState(() {
        _isDragging = true;
        _dragDistance = 0.0;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isRecording && _isDragging) {
      setState(() {
        _dragDistance = -details.localPosition.dx.clamp(-_cancelThreshold * 2, 0.0);
      });
      
      final progress = (_dragDistance.abs() / _cancelThreshold).clamp(0.0, 1.0);
      _slideCtrl.value = progress;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isRecording && _isDragging) {
      if (_dragDistance.abs() >= _cancelThreshold) {
        _stopRecording();
      } else {
        _slideCtrl.animateTo(0.0);
        setState(() {
          _isDragging = false;
          _dragDistance = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Démo Animation Glissement'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions :',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Appui long sur le microphone pour commencer'),
                    const Text('2. Glissez vers la gauche pour voir l\'animation'),
                    const Text('3. Glissez au-delà de la ligne rouge pour annuler'),
                    const Text('4. Relâchez avant la ligne pour continuer'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Zone de démonstration
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: _isRecording
                  ? GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Stack(
                          children: [
                            // Interface d'enregistrement
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isDragging && _dragDistance.abs() > _cancelThreshold * 0.5
                                        ? 'Relâchez pour annuler'
                                        : 'Enregistrement en cours...',
                                    style: TextStyle(
                                      color: _isDragging && _dragDistance.abs() > _cancelThreshold * 0.5
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Indicateur de glissement
                            if (_isDragging && _dragDistance.abs() > 20)
                              Positioned(
                                right: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: _dragDistance.abs() > _cancelThreshold * 0.5
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.outline,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecording(),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Indicateurs visuels
            if (_isRecording) ...[
              Text(
                'Distance de glissement: ${_dragDistance.abs().toInt()}px',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_dragDistance.abs() / _cancelThreshold).clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _dragDistance.abs() > _cancelThreshold * 0.5
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seuil d\'annulation: ${_cancelThreshold.toInt()}px',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
