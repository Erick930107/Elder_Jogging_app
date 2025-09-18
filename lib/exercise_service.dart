import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExerciseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // 保存運動記錄
  Future<String?> saveExercise({
    required int steps,
    required int duration,
    required double distance,
    required int calories,
    required DateTime startTime,
    required DateTime endTime,
    required List<GeoPoint> trackPoints,
  }) async {
    try {
      if (_userId.isEmpty) {
        throw Exception('用戶未登入');
      }

      final exerciseData = {
        'userId': _userId,
        'steps': steps,
        'duration': duration, // 秒數
        'distance': distance, // 公里
        'calories': calories,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'trackPoints': trackPoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        'averagePace': distance > 0 ? (duration / 60) / distance : 0.0, // 分鐘/公里
        'averageSpeed': duration > 0 ? (distance * 3600) / duration : 0.0, // 公里/小時
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('準備寫入 Firestore...');
      final docRef = await _firestore.collection('exercises').add(exerciseData);
      print('運動記錄已保存，ID: ${docRef.id}');

      print('開始更新用戶統計...');
      await _updateUserStats(steps, distance, calories, duration);
      print('用戶統計已更新');

      return docRef.id;
    } catch (e) {
      print('保存運動記錄失敗: $e');
      print('錯誤詳情: ${e.toString()}');
      return null;
    }
  }

  // 獲取運動記錄列表
  Stream<List<Exercise>> getExercises({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      if (_userId.isEmpty) {
        return Stream.value([]);
      }

      Query query = _firestore
          .collection('exercises')
          .where('userId', isEqualTo: _userId)
          .orderBy('startTime', descending: true);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Exercise.fromFirestore(doc.id, data);
        }).toList();
      });
    } catch (e) {
      print('獲取運動記錄失敗: $e');
      return Stream.value([]);
    }
  }

  // 獲取運動統計
  Future<ExerciseStats> getExerciseStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_userId.isEmpty) {
        return ExerciseStats.empty();
      }

      Query query = _firestore
          .collection('exercises')
          .where('userId', isEqualTo: _userId);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      int totalSteps = 0;
      double totalDistance = 0;
      int totalCalories = 0;
      int totalDuration = 0;
      int totalWorkouts = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalSteps += (data['steps'] as num?)?.toInt() ?? 0;
        totalDistance += (data['distance'] as num?)?.toDouble() ?? 0.0;
        totalCalories += (data['calories'] as num?)?.toInt() ?? 0;
        totalDuration += (data['duration'] as num?)?.toInt() ?? 0;
      }

      return ExerciseStats(
        totalSteps: totalSteps,
        totalDistance: totalDistance,
        totalCalories: totalCalories,
        totalDuration: totalDuration,
        totalWorkouts: totalWorkouts,
        averageDistance: totalWorkouts > 0 ? totalDistance / totalWorkouts : 0.0,
        averageDuration: totalWorkouts > 0 ? (totalDuration / totalWorkouts).round() : 0,
        averagePace: totalDistance > 0 ? (totalDuration / 60) / totalDistance : 0.0,
      );
    } catch (e) {
      print('獲取統計數據失敗: $e');
      return ExerciseStats.empty();
    }
  }

  // 刪除運動記錄
  Future<bool> deleteExercise(String exerciseId) async {
    try {
      await _firestore.collection('exercises').doc(exerciseId).delete();
      return true;
    } catch (e) {
      print('刪除運動記錄失敗: $e');
      return false;
    }
  }

  // 更新用戶統計資料
  Future<void> _updateUserStats(int steps, double distance, int calories, int duration) async {
    try {
      final userStatsRef = _firestore.collection('userStats').doc(_userId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userStatsRef);

        if (snapshot.exists) {
          final data = snapshot.data()!;
          transaction.update(userStatsRef, {
            'totalSteps': (data['totalSteps'] ?? 0) + steps,
            'totalDistance': (data['totalDistance'] ?? 0.0) + distance,
            'totalCalories': (data['totalCalories'] ?? 0) + calories,
            'totalDuration': (data['totalDuration'] ?? 0) + duration,
            'totalWorkouts': (data['totalWorkouts'] ?? 0) + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(userStatsRef, {
            'userId': _userId,
            'totalSteps': steps,
            'totalDistance': distance,
            'totalCalories': calories,
            'totalDuration': duration,
            'totalWorkouts': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('更新用戶統計失敗: $e');
    }
  }

  // 獲取用戶總體統計
  Stream<UserStats?> getUserStats() {
    if (_userId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('userStats')
        .doc(_userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return UserStats.fromFirestore(snapshot.data()!);
      }
      return null;
    });
  }
}

// 運動記錄模型
class Exercise {
  final String id;
  final String userId;
  final int steps;
  final int duration;
  final double distance;
  final int calories;
  final DateTime startTime;
  final DateTime endTime;
  final List<GeoPoint> trackPoints;
  final double averagePace;
  final double averageSpeed;
  final DateTime createdAt;

  Exercise({
    required this.id,
    required this.userId,
    required this.steps,
    required this.duration,
    required this.distance,
    required this.calories,
    required this.startTime,
    required this.endTime,
    required this.trackPoints,
    required this.averagePace,
    required this.averageSpeed,
    required this.createdAt,
  });

  factory Exercise.fromFirestore(String id, Map<String, dynamic> data) {
    return Exercise(
      id: id,
      userId: data['userId'] ?? '',
      steps: (data['steps'] as num?)?.toInt() ?? 0,
      duration: (data['duration'] as num?)?.toInt() ?? 0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      calories: (data['calories'] as num?)?.toInt() ?? 0,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trackPoints: (data['trackPoints'] as List<dynamic>?)
          ?.map((point) => GeoPoint(
        point['latitude'] as double,
        point['longitude'] as double,
      ))
          .toList() ?? [],
      averagePace: (data['averagePace'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (data['averageSpeed'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'steps': steps,
      'duration': duration,
      'distance': distance,
      'calories': calories,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'trackPoints': trackPoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'averagePace': averagePace,
      'averageSpeed': averageSpeed,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// 運動統計模型
class ExerciseStats {
  final int totalSteps;
  final double totalDistance;
  final int totalCalories;
  final int totalDuration;
  final int totalWorkouts;
  final double averageDistance;
  final int averageDuration;
  final double averagePace;

  ExerciseStats({
    required this.totalSteps,
    required this.totalDistance,
    required this.totalCalories,
    required this.totalDuration,
    required this.totalWorkouts,
    required this.averageDistance,
    required this.averageDuration,
    required this.averagePace,
  });

  factory ExerciseStats.empty() {
    return ExerciseStats(
      totalSteps: 0,
      totalDistance: 0.0,
      totalCalories: 0,
      totalDuration: 0,
      totalWorkouts: 0,
      averageDistance: 0.0,
      averageDuration: 0,
      averagePace: 0.0,
    );
  }
}

// 用戶統計模型
class UserStats {
  final String userId;
  final int totalSteps;
  final double totalDistance;
  final int totalCalories;
  final int totalDuration;
  final int totalWorkouts;
  final DateTime createdAt;
  final DateTime lastUpdated;

  UserStats({
    required this.userId,
    required this.totalSteps,
    required this.totalDistance,
    required this.totalCalories,
    required this.totalDuration,
    required this.totalWorkouts,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory UserStats.fromFirestore(Map<String, dynamic> data) {
    return UserStats(
      userId: data['userId'] ?? '',
      totalSteps: (data['totalSteps'] as num?)?.toInt() ?? 0,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (data['totalCalories'] as num?)?.toInt() ?? 0,
      totalDuration: (data['totalDuration'] as num?)?.toInt() ?? 0,
      totalWorkouts: (data['totalWorkouts'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}