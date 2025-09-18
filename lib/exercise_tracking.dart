import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exercise_service.dart';

class ExerciseTrackingPage extends StatefulWidget {
  const ExerciseTrackingPage({Key? key}) : super(key: key);

  @override
  _ExerciseTrackingPageState createState() => _ExerciseTrackingPageState();
}

class _ExerciseTrackingPageState extends State<ExerciseTrackingPage> {
  final ExerciseService _exerciseService = ExerciseService();

  bool _isTracking = false;
  bool _isPaused = false;
  bool _isSaving = false;
  int _steps = 0;
  int _duration = 0;
  double _distance = 0.0;
  int _calories = 0;
  double _averagePace = 0.0;

  DateTime? _startTime;
  DateTime? _pauseStartTime;
  int _totalPausedSeconds = 0;
  Timer? _timer;

  // 步數計算參數
  double _stepThreshold = 11.0;
  double _minStepInterval = 0.3;
  DateTime? _lastStepTime;

  // 位置追踪
  final List<Position> _trackPoints = [];
  StreamSubscription<Position>? _positionStream;

  // 加速度感應器
  StreamSubscription<AccelerometerEvent>? _accelerometerStream;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // 檢查並請求位置權限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('無法取得位置權限，部分功能可能無法使用');
      }
    }

    // 檢查活動權限
    final activityStatus = await Permission.activityRecognition.status;
    if (activityStatus.isDenied) {
      await Permission.activityRecognition.request();
    }
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _steps = 0;
      _duration = 0;
      _distance = 0.0;
      _calories = 0;
      _averagePace = 0.0;
      _totalPausedSeconds = 0;
      _pauseStartTime = null; // 確保重置暫停時間
      _trackPoints.clear();
    });

    _startTimer();
    _startLocationTracking();
    _startStepCounting();
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
    });

    _timer?.cancel();
    _positionStream?.pause();
    _accelerometerStream?.pause();
  }

  void _resumeTracking() {
    if (_pauseStartTime != null) {
      _totalPausedSeconds += DateTime.now().difference(_pauseStartTime!).inSeconds;
    }

    setState(() {
      _isPaused = false;
      _pauseStartTime = null;
    });

    _startTimer();
    _positionStream?.resume();
    _accelerometerStream?.resume();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && !_isPaused) {
        setState(() {
          _duration = DateTime.now().difference(_startTime!).inSeconds - _totalPausedSeconds;

          if (_distance > 0) {
            _averagePace = (_duration / 60) / _distance;
          }

          // 估算卡路里
          _calories = (_steps * 0.04).round();
        });
      }
    });
  }

  void _stopTracking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('結束運動'),
        content: const Text('你確定要結束這次運動嗎？運動記錄將會被保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finishExercise();
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishExercise() async {
    if (_startTime == null) {
      _showSnackBar('沒有運動記錄可以保存');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 停止所有追踪
      _timer?.cancel();
      await _positionStream?.cancel();
      await _accelerometerStream?.cancel();

      final endTime = DateTime.now();

      // 修正時間計算邏輯
      int finalDuration;
      if (_isPaused && _pauseStartTime != null) {
        // 如果目前是暫停狀態，使用當前的 _duration（不包含最後暫停的時間）
        finalDuration = _duration;
      } else {
        // 如果沒有暫停，計算到結束時間的總時長
        finalDuration = endTime.difference(_startTime!).inSeconds - _totalPausedSeconds;
      }

      // 確保時間不為負數
      finalDuration = math.max(0, finalDuration);

      print('保存運動記錄 - 步數: $_steps, 時長: $finalDuration 秒, 距離: $_distance km');

      // 轉換 Position 為 GeoPoint
      final trackPoints = _trackPoints.map((position) =>
          GeoPoint(position.latitude, position.longitude)
      ).toList();

      // 保存到 Firebase
      final exerciseId = await _exerciseService.saveExercise(
        steps: _steps,
        duration: finalDuration,
        distance: _distance,
        calories: _calories,
        startTime: _startTime!,
        endTime: endTime,
        trackPoints: trackPoints,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isTracking = false;
          _isPaused = false;
        });

        if (exerciseId != null) {
          // 更新最終數據用於顯示
          _duration = finalDuration;
          _showExerciseCompletedDialog();
        } else {
          _showSnackBar('保存運動記錄失敗，請重試');
        }
      }
    } catch (e) {
      print('保存運動記錄錯誤: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showSnackBar('保存運動記錄時發生錯誤: ${e.toString()}');
      }
    }
  }

  void _showExerciseCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text('運動完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '恭喜您完成了這次運動！',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('步數', '$_steps 步'),
            _buildSummaryRow('距離', '${_distance.toStringAsFixed(2)} 公里'),
            _buildSummaryRow('時間', _formatDuration(_duration)),
            _buildSummaryRow('卡路里', '$_calories 卡'),
            if (_averagePace > 0 && !_averagePace.isInfinite && !_averagePace.isNaN)
              _buildSummaryRow('平均配速', '${_averagePace.toStringAsFixed(2)} min/km'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 先關閉對話框
              Navigator.of(dialogContext).pop();

              // 等待一小段時間確保對話框完全關閉
              await Future.delayed(const Duration(milliseconds: 100));

              // 檢查是否可以安全返回
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
          (Position position) {
        if (_trackPoints.isNotEmpty) {
          final lastPosition = _trackPoints.last;
          final distanceInMeters = Geolocator.distanceBetween(
            lastPosition.latitude,
            lastPosition.longitude,
            position.latitude,
            position.longitude,
          );

          if (distanceInMeters > 3) { // 只有移動超過3公尺才更新
            setState(() {
              _distance += distanceInMeters / 1000;
            });
          }
        }

        _trackPoints.add(position);
      },
      onError: (error) {
        print('位置追踪錯誤: $error');
      },
    );
  }

  void _startStepCounting() {
    _accelerometerStream = accelerometerEvents.listen(
          (AccelerometerEvent event) {
        _detectStep(event);
      },
      onError: (error) {
        print('加速度感應器錯誤: $error');
      },
    );
  }

  void _detectStep(AccelerometerEvent event) {
    final double acceleration = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z);

    if (acceleration > _stepThreshold) {
      final now = DateTime.now();

      if (_lastStepTime == null ||
          now.difference(_lastStepTime!).inMilliseconds > (_minStepInterval * 1000)) {
        setState(() {
          _steps++;
          _lastStepTime = now;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _accelerometerStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健走追蹤'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isTracking)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPaused ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isPaused ? '已暫停' : '追蹤中',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 背景圖示
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Center(
                  child: Icon(
                    Icons.directions_walk,
                    size: 200,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ),

            // 主要內容
            Column(
              children: [
                // 計時器顯示
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _isPaused ? Colors.orange : Colors.blue,
                        ),
                      ),
                      Text(
                        '開始時間: ${_startTime != null ? DateFormat('HH:mm', 'zh_TW').format(_startTime!) : "--:--"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 步數、距離、卡路里
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatusItem(
                          title: '步數',
                          value: _steps.toString(),
                          icon: Icons.directions_walk,
                        ),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          title: '距離',
                          value: '${_distance.toStringAsFixed(2)} km',
                          icon: Icons.straighten,
                        ),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          title: '卡路里',
                          value: '$_calories',
                          icon: Icons.local_fire_department,
                        ),
                      ),
                    ],
                  ),
                ),

                // 配速
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            color: Colors.blue[800],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '平均配速',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _averagePace.isNaN || _averagePace.isInfinite
                              ? '-- min/km'
                              : '${_averagePace.toStringAsFixed(2)} min/km',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 操作按鈕
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 停止按鈕
                  if (_isTracking)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: FloatingActionButton(
                        heroTag: 'stopButton',
                        backgroundColor: Colors.red,
                        child: _isSaving
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.stop),
                        onPressed: _isSaving ? null : _stopTracking,
                      ),
                    ),

                  // 開始/暫停按鈕
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: FloatingActionButton(
                      heroTag: 'startButton',
                      backgroundColor: _isTracking
                          ? (_isPaused ? Colors.green : Colors.orange)
                          : Colors.green,
                      child: Icon(_isTracking
                          ? (_isPaused ? Icons.play_arrow : Icons.pause)
                          : Icons.play_arrow),
                      onPressed: _isSaving ? null : () {
                        if (_isTracking) {
                          if (_isPaused) {
                            _resumeTracking();
                          } else {
                            _pauseTracking();
                          }
                        } else {
                          _startTracking();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 保存進度指示器
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        '正在保存運動記錄...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.blue[800],
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}