import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/youtube_video.dart';

class YoutubeListScreen extends StatefulWidget {
  final bool embedded;

  const YoutubeListScreen({super.key, this.embedded = false});

  @override
  State<YoutubeListScreen> createState() => _YoutubeListScreenState();
}

class _YoutubeListScreenState extends State<YoutubeListScreen>
    with AutomaticKeepAliveClientMixin {
  final List<YoutubeVideo> _videos = [];
  YoutubeVideo? _currentVideo;
  YoutubePlayerController? _playerController;

  // 색상 정의
  static const Color _accentColor = Color(0xFF6B7280);

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _playerController?.close();
    super.dispose();
  }

  void _showAddVideoDialog() {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('유튜브 영상 추가'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      hintText: '영상 제목을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'YouTube URL',
                      hintText: 'https://youtube.com/watch?v=...',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    final title = titleController.text.trim();

                    if (title.isEmpty) {
                      setDialogState(() {
                        errorText = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('제목을 입력해주세요')),
                      );
                      return;
                    }

                    final videoId = YoutubeVideo.extractVideoId(url);
                    if (videoId == null) {
                      setDialogState(() {
                        errorText = '유효하지 않은 YouTube URL입니다';
                      });
                      return;
                    }

                    final video = YoutubeVideo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      videoId: videoId,
                      title: title,
                      url: url,
                    );

                    setState(() {
                      _videos.add(video);
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$title" 영상이 추가되었습니다')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteVideo(int index) {
    final video = _videos[index];

    // 현재 재생 중인 영상을 삭제하면 플레이어 닫기
    if (_currentVideo?.id == video.id) {
      _stopVideo();
    }

    setState(() {
      _videos.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${video.title}" 영상이 삭제되었습니다')),
    );
  }

  void _playVideo(YoutubeVideo video) {
    // 이미 같은 영상이 재생 중이면 무시
    if (_currentVideo?.id == video.id) return;

    // 컨트롤러가 없을 때만 생성 (재사용을 위해)
    if (_playerController == null) {
      _playerController = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          loop: false,
          enableCaption: false,
          playsInline: true,
          strictRelatedVideos: true,
          origin: "https://www.youtube-nocookie.com",
        ),
      );
    }

    // 비디오 로드 및 재생 (컨트롤러 재사용)
    _playerController!.loadVideoById(videoId: video.videoId);

    setState(() {
      _currentVideo = video;
    });
  }

  void _stopVideo() {
    // 컨트롤러는 유지하고 상태만 변경 (재사용을 위해)
    _playerController?.pauseVideo();
    setState(() {
      _currentVideo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    if (widget.embedded) {
      return _buildEmbeddedContent();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_currentVideo != null) _buildPlayer(),
            Expanded(
              child: _videos.isEmpty
                  ? _buildEmptyState()
                  : _buildVideoList(),
            ),
          ],
        ),
      ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FloatingActionButton(
            onPressed: _showAddVideoDialog,
            backgroundColor: _accentColor.withOpacity(0.9),
            elevation: 0,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentVideo != null) _buildPlayer(),
        Expanded(
          child: _videos.isEmpty
              ? _buildEmptyState()
              : _buildVideoList(),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ElevatedButton.icon(
                  onPressed: _showAddVideoDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('영상 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _stopVideo();
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            '유튜브 영상',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _playerController!,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F3),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentVideo!.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _stopVideo,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_display_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 영상이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 영상을 추가해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _buildVideoItem(video, index);
      },
    );
  }

  Widget _buildVideoItem(YoutubeVideo video, int index) {
    final isPlaying = _currentVideo?.id == video.id;

    return GestureDetector(
      onTap: () => _playVideo(video),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F3),
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: const Color(0xFFFFB6C1), width: 2)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  Image.network(
                    'https://img.youtube.com/vi/${video.videoId}/mqdefault.jpg',
                    width: 120,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.smart_display,
                          size: 40,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                      child: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  video.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteVideo(index);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
