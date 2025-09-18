import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'exercise_service.dart';

class ExerciseHistoryPage extends StatefulWidget {
  const ExerciseHistoryPage({Key? key}) : super(key: key);

  @override
  _ExerciseHistoryPageState createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  final ExerciseService _exerciseService = ExerciseService();

  String _currentFilter = '全部';
  final List<String> _filterOptions = ['全部', '本週', '本月', '本年'];

  Stream<List<Exercise>> get _exerciseStream {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (_currentFilter) {
      case '本週':
        startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
        endDate = DateTime(now.year, now.month, now.day + (7 - now.weekday));
        break;
      case '本月':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case '本年':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
    }

    return _exerciseService.getExercises(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<ExerciseStats> get _exerciseStats async {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (_currentFilter) {
      case '本週':
        startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
        endDate = DateTime(now.year, now.month, now.day + (7 - now.weekday));
        break;
      case '本月':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case '本年':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
    }

    return await _exerciseService.getExerciseStats(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('運動記錄'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportData();
              } else if (value == 'clear_all') {
                _showClearAllDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('匯出資料'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('清除所有記錄', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 統計摘要區域
          FutureBuilder<ExerciseStats>(
            future: _exerciseStats,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildStatisticsSkeleton();
              }

              final stats = snapshot.data ?? ExerciseStats.empty();
              return _buildStatisticsSummary(stats);
            },
          ),

          // 過濾選項
          _buildFilterOptions(),

          // 運動記錄列表
          Expanded(
            child: StreamBuilder<List<Exercise>>(
              stream: _exerciseStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final exercises = snapshot.data ?? [];

                if (exercises.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildExerciseList(exercises);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary(ExerciseStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentFilter}運動統計',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (stats.totalWorkouts > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stats.totalWorkouts} 次運動',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('總步數', stats.totalSteps.toString(), '步'),
              _buildStatItem('總距離', stats.totalDistance.toStringAsFixed(1), '公里'),
              _buildStatItem('總時間', (stats.totalDuration ~/ 60).toString(), '分鐘'),
              _buildStatItem('總消耗', stats.totalCalories.toString(), '卡'),
            ],
          ),
          if (stats.totalWorkouts > 0) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.blue.shade200),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('平均距離', stats.averageDistance.toStringAsFixed(1), '公里'),
                _buildStatItem('平均時間', (stats.averageDuration ~/ 60).toString(), '分鐘'),
                _buildStatItem('平均配速', stats.averagePace.toStringAsFixed(1), 'min/km'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 20,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (index) => Column(
              children: [
                Container(
                  height: 12,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 16,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, String unit) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filterOptions.map((filter) {
          final isSelected = filter == _currentFilter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentFilter = filter;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    // 按日期分組記錄
    final Map<String, List<Exercise>> groupedExercises = {};

    for (var exercise in exercises) {
      final dateStr = DateFormat('yyyy年MM月dd日', 'zh_TW').format(exercise.startTime);
      if (!groupedExercises.containsKey(dateStr)) {
        groupedExercises[dateStr] = [];
      }
      groupedExercises[dateStr]!.add(exercise);
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedExercises.length,
        itemBuilder: (context, index) {
          final dateStr = groupedExercises.keys.elementAt(index);
          final exercisesForDate = groupedExercises[dateStr]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${exercisesForDate.length} 次運動',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ...exercisesForDate.map((exercise) => _buildExerciseItem(exercise)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExerciseItem(Exercise exercise) {
    return Dismissible(
      key: Key(exercise.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _showDeleteConfirmDialog(exercise),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text(
              '刪除',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    color: Colors.blue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '健走運動',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('HH:mm', 'zh_TW').format(exercise.startTime)} - ${DateFormat('HH:mm', 'zh_TW').format(exercise.endTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${exercise.steps} 步',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(exercise.duration / 60).toStringAsFixed(0)} 分鐘',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildExerciseDetailItem(
                    Icons.straighten,
                    '${exercise.distance.toStringAsFixed(2)} 公里'
                ),
                _buildExerciseDetailItem(
                    Icons.local_fire_department,
                    '${exercise.calories} 卡'
                ),
                _buildExerciseDetailItem(
                    Icons.speed,
                    exercise.averageSpeed > 0
                        ? '${exercise.averageSpeed.toStringAsFixed(1)} km/h'
                        : '-- km/h'
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '沒有${_currentFilter}運動記錄',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '開始健走，創建您的第一個記錄吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.add),
            label: const Text('開始運動'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '載入失敗',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('重新載入'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(Exercise exercise) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除運動記錄'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('確定要刪除這筆運動記錄嗎？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('日期: ${DateFormat('yyyy/MM/dd HH:mm', 'zh_TW').format(exercise.startTime)}'),
                  Text('步數: ${exercise.steps} 步'),
                  Text('距離: ${exercise.distance.toStringAsFixed(2)} 公里'),
                  Text('時間: ${(exercise.duration / 60).toStringAsFixed(0)} 分鐘'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        final success = await _exerciseService.deleteExercise(exercise.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('運動記錄已刪除')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('刪除失敗，請重試')),
          );
        }
      }
      return confirmed;
    });
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('警告'),
          ],
        ),
        content: const Text('確定要清除所有運動記錄嗎？此操作無法復原！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllRecords();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除所有'),
          ),
        ],
      ),
    );
  }

  void _clearAllRecords() async {
    // 這裡需要實作批量刪除功能
    // 可以在 ExerciseService 中添加 clearAllExercises 方法
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('此功能尚未實作')),
    );
  }

  void _exportData() async {
    // 這裡可以實作匯出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('匯出功能尚未實作')),
    );
  }
}