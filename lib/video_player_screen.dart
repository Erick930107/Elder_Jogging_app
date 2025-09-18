import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  const VideoPlayerScreen({
    Key? key,
    required this.title,
    required this.videoUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // 判斷是本地檔案還是網路檔案
      if (widget.videoUrl.startsWith('assets/')) {
        // 本地 asset 檔案
        _videoPlayerController = VideoPlayerController.asset(widget.videoUrl);
      } else if (widget.videoUrl.startsWith('http')) {
        // 網路檔案
        _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      } else {
        // 本地檔案系統路徑
        _videoPlayerController = VideoPlayerController.file(
            File(widget.videoUrl)
        );
      }

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              '影片載入出錯: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('影片初始化錯誤: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chewieController == null
          ? const Center(
        child: Text(
          '影片載入失敗',
          style: TextStyle(fontSize: 18),
        ),
      )
          : Chewie(controller: _chewieController!),
    );
  }
}