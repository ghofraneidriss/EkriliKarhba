import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/vehicle_photo.dart';

/// Zone « Photos du véhicule » du formulaire : prise de vue ou galerie,
/// miniatures, suppression, choix de la photo principale (la première).
/// Les photos sont copiées dans le dossier de l'application pour que leur
/// chemin reste valable.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.photos,
    required this.onChanged,
    this.maxPhotos = 8,
  });

  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int maxPhotos;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  int get _remaining => widget.maxPhotos - widget.photos.length;

  Future<void> _add() async {
    if (_remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.maxPhotos} photos maximum.')),
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1280,
          imageQuality: 70,
        );
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await _picker.pickMultiImage(
          maxWidth: 1280,
          imageQuality: 70,
        );
      }
      final saved = await _copyToAppFolder(picked.take(_remaining).toList());
      if (saved.isNotEmpty) widget.onChanged([...widget.photos, ...saved]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'ajouter la photo : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>> _copyToAppFolder(List<XFile> files) async {
    if (files.isEmpty) return const [];
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(base.path, 'vehicle_photos'));
    await folder.create(recursive: true);
    final paths = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final extension = p.extension(file.path).isEmpty
          ? '.jpg'
          : p.extension(file.path);
      final target = p.join(
        folder.path,
        'veh_${DateTime.now().microsecondsSinceEpoch}_$i$extension',
      );
      await file.saveTo(target);
      paths.add(target);
    }
    return paths;
  }

  void _remove(int index) {
    final next = [...widget.photos]..removeAt(index);
    widget.onChanged(next);
  }

  void _makeMain(int index) {
    if (index == 0) return;
    final next = [...widget.photos];
    final photo = next.removeAt(index);
    next.insert(0, photo);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.blueLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _busy ? null : _add,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos du véhicule',
                          style: TextStyle(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Avant, arrière, intérieur et documents',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded,
                          color: AppColors.primaryBlue),
                ],
              ),
            ),
          ),
        ),
        if (widget.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _Thumbnail(
                path: widget.photos[index],
                isMain: index == 0,
                onRemove: () => _remove(index),
                onMakeMain: () => _makeMain(index),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Appui long sur une photo : la mettre en principale.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.path,
    required this.isMain,
    required this.onRemove,
    required this.onMakeMain,
  });

  final String path;
  final bool isMain;
  final VoidCallback onRemove;
  final VoidCallback onMakeMain;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onMakeMain,
      child: SizedBox(
        width: 110,
        child: Stack(
          children: [
            Positioned.fill(
              child: VehiclePhoto(
                path: path,
                height: 84,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (isMain)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Principale',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
