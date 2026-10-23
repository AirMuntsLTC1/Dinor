import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class CustomMediaPicker extends StatefulWidget {
  const CustomMediaPicker({super.key});

  @override
  State<CustomMediaPicker> createState() => _CustomMediaPickerState();
}

class _CustomMediaPickerState extends State<CustomMediaPicker> {
  List<AssetEntity> _media = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    // 1. Request Permission
    final PermissionStatus status = await Permission.photos.request();
    final PermissionStatus videoStatus = await Permission.videos.request();

    if (status.isGranted || videoStatus.isGranted) {
      setState(() => _hasPermission = true);
      // 2. Load Media
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );
      if (paths.isNotEmpty) {
        final assets = await paths.first.getAssetListPaged(page: 0, size: 100);
        setState(() {
          _media = assets;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // Starts at half screen
      minChildSize: 0.3,     // Can drag down to 30%
      maxChildSize: 0.95,    // Can drag up to 95% (almost full screen)
      snap: true,            // Snaps smoothly to these sizes
      snapSizes: const [0.5, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Gallery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasPermission
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock, size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text("Permission needed to view photos."),
                                TextButton(
                                  onPressed: _requestPermissionAndLoad,
                                  child: const Text("Grant Access"),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _media.length,
                            itemBuilder: (context, index) {
                              final asset = _media[index];
                              return GestureDetector(
                                onTap: () {
                                  // TODO: Return selected media to chat
                                  Navigator.pop(context, asset);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[200],
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: FutureBuilder<Widget>(
                                    future: _buildThumbnail(asset),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) return snapshot.data!;
                                      return const Center(child: Icon(Icons.image, color: Colors.grey));
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    final thumbData = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    if (thumbData != null) {
      return Image.memory(thumbData, fit: BoxFit.cover);
    }
    return const Icon(Icons.broken_image);
  }
}
