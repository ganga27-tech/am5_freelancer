import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/freelance_api.dart';

class DemoVideoSection extends StatefulWidget {
  const DemoVideoSection({super.key});

  @override
  State<DemoVideoSection> createState() => _DemoVideoSectionState();
}

class _DemoVideoSectionState extends State<DemoVideoSection> {
  static const Color _primary = Color(0xFF142B6F);
  static const Color _textColor = Color(0xFF17233D);
  static const Color _mutedColor = Color(0xFF6B7280);

  final FreelanceApi _api = FreelanceApi();
  List<_DemoVideo> _videos = [];
  bool _loadingVideos = true;
  String? _videoError;

  YoutubePlayerController? _playerController;
  int? _playingVideoIndex;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loadingVideos = true;
      _videoError = null;
    });
    try {
      final rawVideos = await _api.demoVideos();
      final videos =
          rawVideos
              .whereType<Map>()
              .map(
                (item) => _DemoVideo.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loadingVideos = false;
        _videoError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingVideos = false;
        _videoError = error is ApiException
            ? error.message
            : 'Unable to load demo videos.';
      });
    }
  }

  String? _extractVideoId(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(videoUrl);

    if (uri == null) return null;

    if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }

    if (uri.host.contains('youtube.com')) {
      if (uri.path == '/watch') {
        return uri.queryParameters['v'];
      }

      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'embed' ||
              uri.pathSegments.first == 'shorts')) {
        return uri.pathSegments[1];
      }
    }

    return null;
  }

  void _playVideo(int index) {
    final String? videoId = _extractVideoId(_videos[index].videoUrl);

    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video will be available soon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );

    final oldController = _playerController;

    setState(() {
      _playerController = controller;
      _playingVideoIndex = index;
    });

    oldController?.close();
  }

  void _closeVideo() {
    final controller = _playerController;

    setState(() {
      _playerController = null;
      _playingVideoIndex = null;
    });

    controller?.close();
  }

  @override
  void dispose() {
    _playerController?.close();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 600;
              final int columns = isMobile ? 1 : 2;
              const double spacing = 18;

              final double cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              if (_loadingVideos) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_videoError != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _videoError!,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                    TextButton.icon(
                      onPressed: _loadVideos,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (_videos.isEmpty) {
                return const Text(
                  'No demo videos are available yet.',
                  style: TextStyle(color: _mutedColor),
                );
              }
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(_videos.length, (index) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildVideoCard(_videos[index], index),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionIntro() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.play_circle_outline_rounded,
            color: _primary,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore AM5 ROYAL',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Step-by-step product walkthroughs',
                style: TextStyle(color: _mutedColor, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(_DemoVideo video, int index) {
    final bool isPlaying = _playingVideoIndex == index;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPlaying && _playerController != null)
              _buildInlinePlayer()
            else
              _buildThumbnail(video, index),
            Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.category,
                    style: TextStyle(
                      color: video.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isPlaying)
                        IconButton(
                          tooltip: 'Close video',
                          onPressed: _closeVideo,
                          icon: const Icon(Icons.close_rounded),
                          color: video.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    video.subtitle,
                    style: const TextStyle(
                      color: _mutedColor,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEDF0F5)),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isPlaying ? 'Now playing' : 'Watch video',
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(controller: _playerController!, aspectRatio: 16 / 9),
    );
  }

  Widget _buildThumbnail(_DemoVideo video, int index) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _thumbnailFallback(video);
                    },
                  )
                : _thumbnailFallback(video),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _playVideo(index),
                child: Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.94),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 43,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Only the fallback icons have been removed.
  // All other UI and functionality remain unchanged.
  Widget _thumbnailFallback(_DemoVideo video) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [video.accent, Color.lerp(video.accent, Colors.black, 0.35)!],
        ),
      ),
    );
  }
}

class _DemoVideo {
  final String title;
  final String subtitle;
  final String category;
  final Color accent;
  final String videoUrl;
  final String thumbnailUrl;
  final int displayOrder;

  const _DemoVideo({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.accent,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.displayOrder,
  });

  factory _DemoVideo.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Demo video is missing $key.');
      }
      return value.trim();
    }

    return _DemoVideo(
      title: requiredString('title'),
      subtitle: requiredString('duration'),
      category: requiredString('type'),
      accent: _DemoVideoStateColors.accent,
      videoUrl: requiredString('video_url'),
      thumbnailUrl: requiredString('thumbnail_url'),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract final class _DemoVideoStateColors {
  static const accent = Color(0xFF142B6F);
}
