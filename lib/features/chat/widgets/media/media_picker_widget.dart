import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Widget pour sélectionner différents types de médias
class MediaPickerWidget extends StatelessWidget {
  final Function(File file, String type, String? caption) onMediaSelected;
  final VoidCallback? onCancel;

  const MediaPickerWidget({
    super.key,
    required this.onMediaSelected,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Partager un média',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onCancel ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Media options grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildMediaOption(
                  context,
                  icon: Icons.photo_camera,
                  label: 'Caméra',
                  color: Colors.blue,
                  onTap: () => _pickFromCamera(context),
                ),
                _buildMediaOption(
                  context,
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  color: Colors.green,
                  onTap: () => _pickFromGallery(context),
                ),
                _buildMediaOption(
                  context,
                  icon: Icons.videocam,
                  label: 'Vidéo',
                  color: Colors.red,
                  onTap: () => _pickVideo(context),
                ),
                _buildMediaOption(
                  context,
                  icon: Icons.audiotrack,
                  label: 'Audio',
                  color: Colors.purple,
                  onTap: () => _pickAudio(context),
                ),
                _buildMediaOption(
                  context,
                  icon: Icons.description,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () => _pickDocument(context),
                ),
                _buildMediaOption(
                  context,
                  icon: Icons.folder,
                  label: 'Fichier',
                  color: Colors.teal,
                  onTap: () => _pickAnyFile(context),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMediaOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && context.mounted) {
        Navigator.pop(context);
        _showCaptionDialog(context, File(image.path), 'image');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la prise de photo: $e');
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && context.mounted) {
        Navigator.pop(context);
        _showCaptionDialog(context, File(image.path), 'image');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la sélection d\'image: $e');
      }
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null && context.mounted) {
        Navigator.pop(context);
        _showCaptionDialog(context, File(video.path), 'video');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erreur lors de la sélection de vidéo: $e');
      }
    }
  }

  Future<void> _pickAudio(BuildContext context) async {
    try {
      // Pour l'instant, afficher un message d'information
      Navigator.pop(context);
      _showError(context, 'Sélection audio - Fonctionnalité en cours de développement');
    } catch (e) {
      _showError(context, 'Erreur lors de la sélection d\'audio: $e');
    }
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      // Pour l'instant, afficher un message d'information
      Navigator.pop(context);
      _showError(context, 'Sélection document - Fonctionnalité en cours de développement');
    } catch (e) {
      _showError(context, 'Erreur lors de la sélection de document: $e');
    }
  }

  Future<void> _pickAnyFile(BuildContext context) async {
    try {
      // Pour l'instant, afficher un message d'information
      Navigator.pop(context);
      _showError(context, 'Sélection fichier - Fonctionnalité en cours de développement');
    } catch (e) {
      _showError(context, 'Erreur lors de la sélection de fichier: $e');
    }
  }

  void _showCaptionDialog(BuildContext context, File file, String type) {
    final TextEditingController captionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une légende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview du fichier
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getFileIcon(type),
                      size: 40,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFileName(file),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                hintText: 'Ajouter une légende (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onMediaSelected(
                file, 
                type, 
                captionController.text.trim().isEmpty 
                    ? null 
                    : captionController.text.trim()
              );
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  String _getFileName(File file) {
    return file.path.split('/').last;
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Fonction utilitaire pour afficher le picker de médias
void showMediaPicker(
  BuildContext context, {
  required Function(File file, String type, String? caption) onMediaSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => MediaPickerWidget(
      onMediaSelected: onMediaSelected,
    ),
  );
}
