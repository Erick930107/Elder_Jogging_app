import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:jogging/exercise_history.dart';
import 'package:jogging/exercise_tracking.dart';
import 'package:jogging/login_screen.dart';
import 'package:jogging/register_screen.dart';
import 'package:jogging/tutorial_videos_screen.dart';
import 'package:jogging/weather.dart';
import 'package:jogging/services/auth_service.dart';
import 'package:jogging/exercise_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW', null);
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '步步驚心',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'NotoSansTC',
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

// 認證包裝器 - 決定顯示登入頁面還是主頁面
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const ExerciseTrackingPage(),
    const TutorialVideosScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk),
            label: '運動',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: '影片',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

// Weather Data Model
class WeatherData {
  final DateTime date;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String description;
  final String icon;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final int visibility;
  final int windDirection;

  WeatherData({
    required this.date,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibility,
    required this.windDirection,
  });
}

// Real Weather Service using OpenWeatherMap API
class WeatherService {
  static const String _apiKey = 'f8a3aebc83fa5b87debd70fdbc4e57a9';
  static const double _chiayi_lat = 23.4801; // 嘉義市緯度
  static const double _chiayi_lon = 120.4491; // 嘉義市經度

  static Future<WeatherData?> getCurrentWeather() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$_chiayi_lat&lon=$_chiayi_lon&appid=$_apiKey&units=metric&lang=zh_tw'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return WeatherData(
          date: DateTime.now(),
          temperature: data['main']['temp']?.toDouble() ?? 0.0,
          feelsLike: data['main']['feels_like']?.toDouble() ?? 0.0,
          condition: data['weather'][0]['main'] ?? 'Unknown',
          description: data['weather'][0]['description'] ?? '未知',
          icon: data['weather'][0]['icon'] ?? '01d',
          humidity: data['main']['humidity']?.toInt() ?? 0,
          windSpeed: data['wind']['speed']?.toDouble() ?? 0.0,
          pressure: data['main']['pressure']?.toInt() ?? 0,
          visibility: data['visibility']?.toInt() ?? 0,
          windDirection: data['wind']['deg']?.toInt() ?? 0,
        );
      } else {
        print('Weather API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  static String getWalkingSuggestion(WeatherData weather) {
    final temp = weather.temperature;
    final condition = weather.condition.toLowerCase();

    if (condition.contains('clear') || condition.contains('sun')) {
      if (temp > 30) {
        return '天氣晴朗但較炎熱，建議清晨或傍晚時段健走，記得擦防曬霜並多補充水分。';
      } else if (temp > 20) {
        return '天氣晴朗，溫度適宜，非常適合外出健走！記得擦防曬霜。';
      } else if (temp > 10) {
        return '天氣晴朗但稍涼，適合健走，建議穿著輕薄外套。';
      } else {
        return '天氣晴朗但偏冷，如要健走請注意保暖。';
      }
    } else if (condition.contains('cloud')) {
      if (temp > 25) {
        return '多雲天氣，氣溫適中，是健走的好時機。';
      } else if (temp > 15) {
        return '多雲天氣，溫度舒適，適合外出健走。';
      } else {
        return '多雲微涼，健走時建議穿著輕薄外套。';
      }
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return '今天有雨，如需外出健走請攜帶雨具，或考慮室內活動。';
    } else if (condition.contains('snow')) {
      return '今天下雪，路面可能濕滑，建議室內活動或選擇安全的健走路線。';
    } else if (condition.contains('mist') || condition.contains('fog')) {
      return '今天有霧，能見度較低，外出健走時請注意安全。';
    } else {
      return '今天天氣${weather.description}，建議根據實際情況決定是否外出健走。';
    }
  }

  static String getChineseCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '晴天';
      case 'clouds':
        return '多雲';
      case 'rain':
        return '雨天';
      case 'drizzle':
        return '小雨';
      case 'thunderstorm':
        return '雷雨';
      case 'snow':
        return '雪天';
      case 'mist':
      case 'fog':
        return '霧';
      case 'haze':
        return '霾';
      default:
        return condition;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ExerciseService _exerciseService = ExerciseService();

  // 從 Firebase 讀取的數據
  int _currentSteps = 0;
  final int _dailyGoal = 5000;
  WeatherData? _currentWeather;
  String _weatherDescription = '載入中...';
  bool _isLoadingWeather = true;
  bool _isLoadingExercises = true;
  bool _isLoadingSteps = true;
  String _userName = '用戶';
  String _userEmail = '';
  int _userAge = 0;
  String _userGender = '';

  List<Exercise> _recentExercises = [];

  double get _progressPercentage => _currentSteps / _dailyGoal;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
    _loadUserProfile();
    _loadTodaySteps();
    _loadRecentExercises();
  }

  Future<void> _loadWeatherData() async {
    try {
      setState(() {
        _isLoadingWeather = true;
      });

      final weatherData = await WeatherService.getCurrentWeather();

      if (mounted) {
        setState(() {
          _currentWeather = weatherData;
          if (weatherData != null) {
            _weatherDescription = WeatherService.getWalkingSuggestion(weatherData);
          } else {
            _weatherDescription = '無法獲取天氣資訊，建議根據實際情況決定是否外出健走。';
          }
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      print('載入天氣資料失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _weatherDescription = '無法獲取天氣資訊，請檢查網絡連接。';
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('userStats')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['name'] ?? '用戶';
            _userEmail = userData['email'] ?? '';
            _userAge = userData['age'] ?? 0;
            _userGender = userData['gender'] ?? '';
          });
        }
      } catch (e) {
        print('載入用戶資料失敗: $e');
      }
    }
  }

  Future<void> _loadTodaySteps() async {
    try {
      setState(() {
        _isLoadingSteps = true;
      });

      print('開始載入今日步數...');
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      print('查詢時間範圍: $startOfDay 到 $endOfDay');

      final todayExercises = await _exerciseService.getExercises(
        startDate: startOfDay,
        endDate: endOfDay,
      ).first;

      print('今日運動記錄數量: ${todayExercises.length}');

      int totalSteps = 0;
      for (var exercise in todayExercises) {
        totalSteps += exercise.steps;
        print('運動記錄: ${exercise.steps} 步');
      }

      print('今日總步數: $totalSteps');

      if (mounted) {
        setState(() {
          _currentSteps = totalSteps;
          _isLoadingSteps = false;
        });
      }
    } catch (e) {
      print('載入今日步數失敗: $e');
      if (mounted) {
        setState(() {
          _currentSteps = 0; // 設置默認值
          _isLoadingSteps = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入步數失敗: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadRecentExercises() async {
    try {
      setState(() {
        _isLoadingExercises = true;
      });

      final exercises = await _exerciseService.getExercises().first;

      // 取最近的3筆記錄
      final recentExercises = exercises.take(3).toList();

      if (mounted) {
        setState(() {
          _recentExercises = recentExercises;
          _isLoadingExercises = false;
        });
      }
    } catch (e) {
      print('載入最近運動記錄失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingExercises = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('步步驚心', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingSection(),
                const SizedBox(height: 20),
                _buildStepProgressSection(),
                const SizedBox(height: 24),
                _buildWeatherSection(),
                const SizedBox(height: 24),
                _buildRecentExercisesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadWeatherData();
    await _loadUserProfile();
    await _loadTodaySteps();
    await _loadRecentExercises();
  }

  Widget _buildGreetingSection() {
    final now = DateTime.now();
    String greeting;

    if (now.hour < 12) {
      greeting = '早安';
    } else if (now.hour < 18) {
      greeting = '午安';
    } else {
      greeting = '晚安';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting，$_userName',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          DateFormat('yyyy年MM月dd日 EEEE', 'zh_TW').format(now),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepProgressSection() {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日步數',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '目標: $_dailyGoal步',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingSteps)
            const CircularProgressIndicator()
          else
            CircularPercentIndicator(
              radius: 120.0,
              lineWidth: 15.0,
              percent: _progressPercentage > 1.0 ? 1.0 : _progressPercentage,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentSteps.toString(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '步',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              progressColor: Colors.blue,
              backgroundColor: Colors.blue.withOpacity(0.2),
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 1200,
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStepInfoItem('距離', '${(_currentSteps * 0.0008).toStringAsFixed(1)}', '公里'),
              _buildStepInfoItem('消耗', '${(_currentSteps * 0.04).toInt()}', '卡路里'),
              _buildStepInfoItem('時間', '${(_currentSteps / 100).toInt()}', '分鐘'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepInfoItem(String title, String value, String unit) {
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherSection() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeatherPage(),
          ),
        );
      },
      child: Container(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '今日天氣',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isLoadingWeather)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '嘉義市',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weatherDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(
                  _getWeatherIcon(_currentWeather?.condition ?? 'clear'),
                  size: 32,
                  color: _getWeatherColor(_currentWeather?.condition ?? 'clear'),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentWeather != null
                      ? '${_currentWeather!.temperature.round()}°C'
                      : '--°C',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
      case 'drizzle':
        return Icons.beach_access;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.cloud;
      default:
        return Icons.wb_sunny;
    }
  }

  Color _getWeatherColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Colors.orange;
      case 'clouds':
        return Colors.grey;
      case 'rain':
      case 'drizzle':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.deepPurple;
      case 'snow':
        return Colors.lightBlue;
      case 'mist':
      case 'fog':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  Widget _buildRecentExercisesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近運動記錄',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingExercises)
          _buildExerciseLoadingSkeleton()
        else if (_recentExercises.isEmpty)
          _buildNoExerciseState()
        else
          ..._recentExercises.map((exercise) => _buildExerciseItem(exercise)),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              _showExerciseHistory();
            },
            child: Text(
              '查看更多',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseLoadingSkeleton() {
    return Column(
      children: List.generate(2, (index) => Container(
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
        child: Row(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 16,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildNoExerciseState() {
    return Container(
      padding: const EdgeInsets.all(32),
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
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.directions_walk_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有運動記錄',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '開始您的第一次健走吧！',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(Exercise exercise) {
    return Container(
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
      child: Row(
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
                  DateFormat('MM月dd日 HH:mm', 'zh_TW').format(exercise.startTime),
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
                '${(exercise.duration / 60).toStringAsFixed(0)} 分鐘 | ${exercise.distance.toStringAsFixed(1)} 公里',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startExerciseTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseTrackingPage(),
      ),
    );
  }

  void _showExerciseHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseHistoryPage(),
      ),
    );
  }

  void _showTutorialVideos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TutorialVideosScreen(),
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('運動提醒設置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('每日運動提醒'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // 處理提醒設置
                  },
                ),
              ),
              ListTile(
                title: const Text('目標達成提醒'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // 處理提醒設置
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('設置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('個人資料'),
                onTap: () {
                  Navigator.of(context).pop();
                  // 導航到個人資料頁面
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('通知設置'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showNotificationSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('幫助'),
                onTap: () {
                  Navigator.of(context).pop();
                  // 顯示幫助資訊
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic> _userProfile = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('userStats')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _userProfile = userDoc.data()!;
            _userProfile['email'] = user.email;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('載入用戶資料失敗: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認登出'),
          content: const Text('您確定要登出嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('登出'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('登出失敗: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildProfileInfo(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 32),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userProfile['name'] ?? '用戶',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userProfile['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            '個人資訊',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('姓名', _userProfile['name'] ?? '未設定'),
          _buildInfoRow('年齡', '${_userProfile['age'] ?? 0} 歲'),
          _buildInfoRow('性別', _userProfile['gender'] ?? '未設定'),
          _buildInfoRow('電子郵件', _userProfile['email'] ?? '未設定'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            '設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            icon: Icons.edit,
            title: '編輯個人資料',
            onTap: () {
              // TODO: 導航到編輯個人資料頁面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能即將推出')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.notifications,
            title: '通知設定',
            onTap: () {
              // TODO: 導航到通知設定頁面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能即將推出')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.help,
            title: '幫助與支援',
            onTap: () {
              // TODO: 導航到幫助頁面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能即將推出')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.info,
            title: '關於應用',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('關於步步驚心'),
                  content: const Text('版本 1.0.0\n\n這是一個專為長者設計的健走應用程式，幫助您維持健康的生活方式。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('確定'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          '登出',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
