import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;

/// Widget de test pour envoyer 10 images distinctes et vérifier la réception
class TestMultipleImages extends StatefulWidget {
  final Function(File file, String type, String? caption) onSendMedia;
  
  const TestMultipleImages({
    super.key,
    required this.onSendMedia,
  });

  @override
  State<TestMultipleImages> createState() => _TestMultipleImagesState();
}

class _TestMultipleImagesState extends State<TestMultipleImages> {
  final List<String> _sentImages = [];
  bool _isSending = false;

  /// Génère une image unique avec un numéro
  Future<File> _generateTestImage(int number) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Fond de couleur unique basé sur le numéro
    final paint = Paint()
      ..color = Color.fromARGB(
        255,
        (number * 25) % 256,
        (number * 50) % 256,
        (number * 75) % 256,
      );
    
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 400), paint);
    
    // Texte avec le numéro
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'IMAGE #$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 60,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (400 - textPainter.width) / 2,
        (400 - textPainter.height) / 2,
      ),
    );
    
    // Convertir en image
    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 400);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    
    // Sauvegarder dans un fichier temporaire
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/test_image_$number.png');
    await file.writeAsBytes(buffer);
    
    debugPrint('✅ Image générée: ${file.path}');
    return file;
  }

  /// Envoie 10 images distinctes
  Future<void> _sendMultipleImages() async {
    setState(() {
      _isSending = true;
      _sentImages.clear();
    });

    try {
      for (int i = 1; i <= 10; i++) {
        debugPrint('📤 Envoi image $i/10...');
        
        // Générer l'image
        final imageFile = await _generateTestImage(i);
        _sentImages.add(imageFile.path);
        
        // Envoyer via le callback
        await widget.onSendMedia(imageFile, 'image', 'Test Image #$i');
        
        debugPrint('✅ Image $i envoyée: ${imageFile.path}');
        
        // Attendre un peu entre chaque envoi pour éviter la surcharge
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {});
      }
      
      debugPrint('🎉 Toutes les 10 images ont été envoyées !');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 10 images envoyées ! Vérifiez la réception.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 TEST: Envoi de 10 images distinctes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chaque image aura une couleur et un numéro différent.\nVérifiez que vous recevez bien 10 images DIFFÉRENTES.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          
          if (_isSending)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text('Envoi: ${_sentImages.length}/10 images...'),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _sendMultipleImages,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer 10 images de test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          
          if (_sentImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Images envoyées: ${_sentImages.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

