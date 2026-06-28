import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(const LobsterAlbumApp());
}

class LobsterAlbumApp extends StatelessWidget {
  const LobsterAlbumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '龙虾相册',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEE6C4D)),
        useMaterial3: true,
      ),
      home: const AlbumHomePage(),
    );
  }
}

class AlbumHomePage extends StatefulWidget {
  const AlbumHomePage({super.key});

  @override
  State<AlbumHomePage> createState() => _AlbumHomePageState();
}

class _AlbumHomePageState extends State<AlbumHomePage> {
  bool _loading = false;
  bool _permissionDenied = false;
  String _statusText = '点击按钮开始读取本地照片和视频';
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _media = [];
  String _currentAlbumName = '全部媒体';
  int _previewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loading = true;
      _statusText = '正在申请权限并读取本地相册...';
      _permissionDenied = false;
    });

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _statusText = permission.isLimited
            ? '当前是部分授权，请到系统设置里打开完整访问权限。'
            : '未获得相册权限，请允许访问照片和视频。';
      });
      return;
    }

    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );
      final allAlbum = albums.isNotEmpty ? albums.first : null;
      final assets = allAlbum == null
          ? <AssetEntity>[]
          : await allAlbum.getAssetListPaged(page: 0, size: 300);

      if (!mounted) return;
      setState(() {
        _albums = albums;
        _media = assets;
        _currentAlbumName = allAlbum?.name ?? '全部媒体';
        _loading = false;
        _statusText = '已读取 ${assets.length} 个本地媒体文件';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = '读取失败：$e';
      });
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _showAlbum(AssetPathEntity? album) async {
    setState(() {
      _loading = true;
      _statusText = '正在切换相册...';
      _permissionDenied = false;
    });

    try {
      final assets = album == null
          ? <AssetEntity>[]
          : await album.getAssetListPaged(page: 0, size: 300);
      if (!mounted) return;
      setState(() {
        _media = assets;
        _currentAlbumName = album?.name ?? '全部媒体';
        _loading = false;
        _statusText = '已显示 ${album?.name ?? '全部媒体'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = '切换相册失败：$e';
      });
    }
  }

  Future<void> _openPreview(int index) async {
    if (_media.isEmpty) return;
    _previewIndex = index;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MediaPreviewPage(
          media: _media,
          initialIndex: index,
          onDelete: _deleteAsset,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除成功，已移到回收站')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _deleteAsset(AssetEntity asset) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除到回收站'),
        content: const Text('确定要把这张照片/视频删除到系统回收站吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return false;

    final deletedIds = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (!mounted) return false;

    final success = deletedIds.contains(asset.id);
    setState(() {
      _media.removeWhere((item) => deletedIds.contains(item.id));
      _statusText = success
          ? '删除成功，已移到回收站'
          : '删除失败或系统未允许删除';
      _previewIndex = _previewIndex.clamp(0, _media.isEmpty ? 0 : _media.length - 1);
    });
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('龙虾相册'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadMedia,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _HeaderCard(
                statusText: _statusText,
                albumCount: _albums.length,
                mediaCount: _media.length,
                loading: _loading,
                permissionDenied: _permissionDenied,
                onRetry: _loadMedia,
                onOpenSettings: _openSettings,
              ),
            ),
            if (_albums.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    return FilterChip(
                      selected: album.name == _currentAlbumName,
                      label: Text(album.name),
                      onSelected: (_) => _showAlbum(album),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _albums.length,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentAlbumName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => _showAlbum(null),
                    child: const Text('全部媒体'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _media.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _media.isEmpty
                      ? const _EmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _media.length,
                          itemBuilder: (context, index) {
                            return _MediaTile(
                              asset: _media[index],
                              onTap: () => _openPreview(index),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.statusText,
    required this.albumCount,
    required this.mediaCount,
    required this.loading,
    required this.permissionDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String statusText;
  final int albumCount;
  final int mediaCount;
  final bool loading;
  final bool permissionDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEE6C4D), Color(0xFFF4A261)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本地相册 Demo',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: '相册', value: albumCount.toString()),
              _StatChip(label: '媒体', value: mediaCount.toString()),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: loading ? null : onRetry,
                child: const Text('重新读取'),
              ),
              if (permissionDenied)
                OutlinedButton(
                  onPressed: onOpenSettings,
                  child: const Text('打开设置'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            '没有读取到本地照片或视频',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '请确认手机里有媒体文件，并已授予相册权限。',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(
                const ThumbnailSize.square(300),
                quality: 80,
              ),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return Container(color: Colors.grey.shade300);
                }
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  asset.type == AssetType.video
                      ? Icons.videocam_rounded
                      : Icons.image_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({super.key, required this.media, required this.initialIndex, required this.onDelete});

  final List<AssetEntity> media;
  final int initialIndex;
  final Future<bool> Function(AssetEntity asset) onDelete;

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAsset = widget.media[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.media.length}'),
        actions: [
          IconButton(
            onPressed: () async {
              final deleted = await widget.onDelete(currentAsset);
              if (!mounted) return;
              if (deleted) {
                Navigator.of(context).pop(true);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final asset = widget.media[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(
                    ThumbnailSize(
                      constraints.maxWidth.toInt() * 2,
                      constraints.maxHeight.toInt() * 2,
                    ),
                    quality: 100,
                  ),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }
                    if (bytes == null) {
                      return const Text(
                        '无法加载预览',
                        style: TextStyle(color: Colors.white),
                      );
                    }
                    return GestureDetector(
                      onDoubleTap: () {},
                      child: InteractiveViewer(
                        clipBehavior: Clip.none,
                        boundaryMargin: const EdgeInsets.all(200),
                        minScale: 0.8,
                        maxScale: 5,
                        panEnabled: true,
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
