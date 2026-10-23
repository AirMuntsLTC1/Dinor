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
  final List<AssetEntity> _selectedMedia = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoad() async {
    final PermissionStatus status = await Permission.photos.request();
    final PermissionStatus videoStatus = await Permission.videos.request();

    if (status.isGranted || videoStatus.isGranted) {
      setState(() => _hasPermission = true);
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

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedMedia.contains(asset)) {
        _selectedMedia.remove(asset);
      } else {
        _selectedMedia.add(asset);
      }
    });
  }

  void _sendMedia() {
    // Return the selected media and the caption back to ChatScreen
    Navigator.pop(context, {
      'media': _selectedMedia,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use a Column aligned to the bottom so the keyboard naturally pushes everything up
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // Padding uses MediaQuery.viewInsets.bottom so the caption bar rides the keyboard
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                // 1. Drag Handle
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
                
                // 2. Header (Title + Done Button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gallery',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (_selectedMedia.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            // If they have selections, focus the caption to let them type
                            _captionFocus.requestFocus();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF229ED9),
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Done (${_selectedMedia.length})'),
                        ),
                    ],
                  ),
                ),

                // 3. Media Grid
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
                                final isSelected = _selectedMedia.contains(asset);

                                return GestureDetector(
                                  onTap: () => _toggleSelection(asset),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Image Thumbnail
                                      Container(
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
                                      
                                      // Selection Overlay
                                      if (isSelected)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF229ED9).withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF229ED9), width: 3),
                                          ),
                                          child: Center(
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: const Color(0xFF229ED9),
                                              child: Text(
                                                _selectedMedia.indexOf(asset).toString(),
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),

                // 4. Caption Composer (Only shows when media is selected)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: _selectedMedia.isNotEmpty ? 60 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: _selectedMedia.isNotEmpty
                      ? Row(
                          children: [
                            // Preview of the first selected photo
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: FutureBuilder<Widget>(
                                future: _buildThumbnail(_selectedMedia.first),
                                builder: (context, snapshot) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.grey[200],
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: snapshot.hasData ? snapshot.data : const SizedBox(),
                                  );
                                },
                              ),
                            ),
                            // Caption Input
                            Expanded(
                              child: TextField(
                                controller: _captionController,
                                focusNode: _captionFocus,
                                decoration: const InputDecoration(
                                  hintText: 'Add a caption...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                            // Send Button
                            IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFF229ED9)),
                              onPressed: _sendMedia,
                            ),
                          ],
                        )
                      : null,
                ),
              ],
            ),
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
