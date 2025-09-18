import 'package:flutter/material.dart';
import 'video_player_screen.dart';

class TutorialVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration duration;

  TutorialVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
  });
}

class TutorialVideosScreen extends StatefulWidget {
  const TutorialVideosScreen({Key? key}) : super(key: key);

  @override
  State<TutorialVideosScreen> createState() => _TutorialVideosScreenState();
}

class _TutorialVideosScreenState extends State<TutorialVideosScreen> {
  // 教學影片數據 - 使用本地 MP4 文件
  final List<TutorialVideo> _tutorialVideos = [
    TutorialVideo(
      id: '1',
      title: '正確的健走姿勢',
      description: '學習正確的健走姿勢，避免運動傷害',
      thumbnailUrl: 'assets/images/thumbnails/walking_posture_thumb.jpg',
      videoUrl: 'assets/videos/walking_posture.mp4',
      duration: const Duration(minutes: 5, seconds: 30),
    ),
    TutorialVideo(
      id: '2',
      title: '健走熱身運動',
      description: '在健走前進行必要的熱身運動',
      thumbnailUrl: 'assets/images/thumbnails/warm_up_thumb.jpg',
      videoUrl: 'assets/videos/warm_up_exercises.mp4',
      duration: const Duration(minutes: 3, seconds: 45),
    ),
    TutorialVideo(
      id: '3',
      title: '老人健走注意事項',
      description: '適合老年人的健走速度與方式',
      thumbnailUrl: 'assets/images/thumbnails/senior_walking_thumb.jpg',
      videoUrl: 'assets/videos/senior_walking_guide.mp4',
      duration: const Duration(minutes: 7, seconds: 20),
    ),
    TutorialVideo(
      id: '4',
      title: '健走後拉伸運動',
      description: '健走後的拉伸技巧，幫助肌肉恢復',
      thumbnailUrl: 'assets/images/thumbnails/stretching_thumb.jpg',
      videoUrl: 'assets/videos/post_walk_stretching.mp4',
      duration: const Duration(minutes: 4, seconds: 15),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教學影片'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _tutorialVideos.length,
        itemBuilder: (context, index) {
          final video = _tutorialVideos[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      title: video.title,
                      videoUrl: video.videoUrl,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 影片縮圖區域
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            video.thumbnailUrl,
                            width: 120,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.video_library,
                                  color: Colors.grey.shade600,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        ),
                        // 播放按鈕覆蓋層
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withOpacity(0.3),
                            ),
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        // 影片時長標籤
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 影片資訊區域
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(video.duration),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const SizedBox(width: 4),
                              Text(
                                '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
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
            ),
          );
        },
      ),
    );
  }

  // 格式化影片時長
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }
}