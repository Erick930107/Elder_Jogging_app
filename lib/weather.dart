import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({Key? key}) : super(key: key);

  @override
  _WeatherPageState createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  String _cityName = '嘉義市';
  WeatherData? _currentWeather;
  List<WeatherData> _forecast = [];
  DateTime? _sunrise;
  DateTime? _sunset;

  // 嘉義市座標
  static const double _chiayi_lat = 23.4801;
  static const double _chiayi_lon = 120.4491;

  Map<String, String> _weatherSuggestions = {
    'Clear': '天氣晴朗，非常適合外出健走！記得擦防曬霜。',
    'Clouds': '雲層較多，氣溫適宜，是健走的好時機。',
    'Rain': '今天有雨，如需外出健走請攜帶雨具，或考慮室內活動。',
    'Drizzle': '微雨，建議帶上輕便雨具再出門健走。',
    'Thunderstorm': '有雷雨，不建議外出健走，可進行室內活動。',
    'Snow': '有雪，路面可能濕滑，外出健走請特別小心。',
    'Mist': '有霧，能見度較低，外出健走請注意安全。',
    'Fog': '大霧，不建議外出健走，可在室內進行運動。',
  };

  @override
  void initState() {
    super.initState();
    _getWeatherData();
  }

  Future<void> _getWeatherData() async {
    try {
      final apiKey = 'f8a3aebc83fa5b87debd70fdbc4e57a9';

      // 獲取當前天氣 - 使用嘉義市座標
      final currentResponse = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$_chiayi_lat&lon=$_chiayi_lon&appid=$apiKey&units=metric&lang=zh_tw'
      ));

      // 獲取天氣預報 - 使用嘉義市座標
      final forecastResponse = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?lat=$_chiayi_lat&lon=$_chiayi_lon&appid=$apiKey&units=metric&lang=zh_tw'
      ));

      if (currentResponse.statusCode == 200 && forecastResponse.statusCode == 200) {
        final currentData = json.decode(currentResponse.body);
        final forecastData = json.decode(forecastResponse.body);

        setState(() {
          _cityName = currentData['name'] ?? '嘉義市';

          // 解析日出日落時間
          if (currentData['sys'] != null) {
            if (currentData['sys']['sunrise'] != null) {
              _sunrise = DateTime.fromMillisecondsSinceEpoch(
                  currentData['sys']['sunrise'] * 1000
              );
            }
            if (currentData['sys']['sunset'] != null) {
              _sunset = DateTime.fromMillisecondsSinceEpoch(
                  currentData['sys']['sunset'] * 1000
              );
            }
          }

          _currentWeather = WeatherData(
            date: DateTime.now(),
            temperature: currentData['main']['temp']?.toDouble() ?? 0.0,
            feelsLike: currentData['main']['feels_like']?.toDouble() ?? 0.0,
            condition: currentData['weather'][0]['main'] ?? 'Unknown',
            description: currentData['weather'][0]['description'] ?? '未知',
            icon: currentData['weather'][0]['icon'] ?? '01d',
            humidity: currentData['main']['humidity']?.toInt() ?? 0,
            windSpeed: currentData['wind']['speed']?.toDouble() ?? 0.0,
            pressure: currentData['main']['pressure']?.toInt() ?? 0,
            visibility: currentData['visibility']?.toInt() ?? 0,
            windDirection: currentData['wind']['deg']?.toInt() ?? 0,
          );

          // 處理預報數據
          _forecast = [];
          if (forecastData['list'] != null) {
            for (var item in forecastData['list']) {
              _forecast.add(WeatherData(
                date: DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000),
                temperature: item['main']['temp']?.toDouble() ?? 0.0,
                feelsLike: item['main']['feels_like']?.toDouble() ?? 0.0,
                condition: item['weather'][0]['main'] ?? 'Unknown',
                description: item['weather'][0]['description'] ?? '未知',
                icon: item['weather'][0]['icon'] ?? '01d',
                humidity: item['main']['humidity']?.toInt() ?? 0,
                windSpeed: item['wind']['speed']?.toDouble() ?? 0.0,
                pressure: item['main']['pressure']?.toInt() ?? 0,
                visibility: 10000, // 預報資料通常沒有能見度
                windDirection: item['wind']['deg']?.toInt() ?? 0,
              ));
            }
          }

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '獲取天氣數據失敗，請稍後再試。';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '連接天氣服務失敗，請檢查網絡連接。';
      });
    }
  }

  // 獲取健走建議
  String _getWalkingSuggestion() {
    if (_currentWeather == null) return '';

    String suggestion = _weatherSuggestions[_currentWeather!.condition] ??
        '今天天氣不錯，可以考慮外出健走。';

    // 根據溫度補充建議
    if (_currentWeather!.temperature < 10) {
      suggestion += ' 溫度較低，請穿著保暖衣物。';
    } else if (_currentWeather!.temperature > 30) {
      suggestion += ' 溫度較高，請避免中午時段運動，多補充水分。';
    }

    // 根據風速補充建議
    if (_currentWeather!.windSpeed > 8.0) {
      suggestion += ' 風速較大，外出時請注意安全。';
    }

    // 根據能見度補充建議
    if (_currentWeather!.visibility < 5000) {
      suggestion += ' 能見度較低，請特別注意安全。';
    }

    return suggestion;
  }

  // 獲取適宜的健走時間
  List<String> _getSuitableWalkingTime() {
    if (_forecast.isEmpty) return [];

    List<String> bestTimes = [];

    // 檢查未來48小時內的好時段
    for (int i = 0; i < 16 && i < _forecast.length; i++) {
      final weather = _forecast[i];
      final hour = weather.date.hour;

      // 判斷是否適合健走的時間
      bool suitable = weather.condition != 'Rain' &&
          weather.condition != 'Thunderstorm' &&
          weather.temperature > 10 &&
          weather.temperature < 30 &&
          weather.windSpeed < 8.0;

      if (suitable) {
        // 檢查是否是合理的健走時間
        if ((hour >= 6 && hour <= 10) || (hour >= 16 && hour <= 19)) {
          String timeStr = DateFormat('MM/dd HH:mm', 'zh_TW').format(weather.date);
          bestTimes.add(timeStr);

          if (bestTimes.length >= 3) break;
        }
      }
    }

    return bestTimes;
  }

  // 獲取風向文字描述
  String _getWindDirection(int degree) {
    if (degree >= 338 || degree < 23) return '北';
    if (degree >= 23 && degree < 68) return '東北';
    if (degree >= 68 && degree < 113) return '東';
    if (degree >= 113 && degree < 158) return '東南';
    if (degree >= 158 && degree < 203) return '南';
    if (degree >= 203 && degree < 248) return '西南';
    if (degree >= 248 && degree < 293) return '西';
    if (degree >= 293 && degree < 338) return '西北';
    return '無風向';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('天氣提示'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              _getWeatherData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage.isNotEmpty
          ? _buildErrorView()
          : _buildWeatherView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在獲取天氣數據...'),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              _getWeatherData();
            },
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherView() {
    if (_currentWeather == null) return Container();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 當前位置和更新時間
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _cityName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '更新於 ${DateFormat('HH:mm', 'zh_TW').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 當前天氣
          _buildCurrentWeatherCard(),

          const SizedBox(height: 24),

          // 健走建議
          _buildWalkingSuggestionCard(),

          const SizedBox(height: 24),

          // 未來天氣預報
          const Text(
            '未來天氣預報',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _forecast.length > 8 ? 8 : _forecast.length,
              itemBuilder: (context, index) {
                return _buildForecastItem(_forecast[index]);
              },
            ),
          ),

          const SizedBox(height: 24),

          // 適宜健走時間
          _buildSuitableTimeCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
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
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentWeather!.temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '體感溫度 ${_currentWeather!.feelsLike.toStringAsFixed(1)}°C',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWeather!.description,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '氣壓 ${_currentWeather!.pressure} hPa',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '能見度 ${(_currentWeather!.visibility / 1000).toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Image.network(
              'https://openweathermap.org/img/wn/${_currentWeather!.icon}@2x.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _getWeatherIcon(_currentWeather!.condition),
                  size: 64,
                  color: _getWeatherColor(_currentWeather!.condition),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkingSuggestionCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                '今日健走建議',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getWalkingSuggestion(),
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherDetailItem(
                icon: Icons.water_drop,
                value: '${_currentWeather!.humidity}%',
                label: '濕度',
              ),
              _buildWeatherDetailItem(
                icon: Icons.air,
                value: '${_currentWeather!.windSpeed.toStringAsFixed(1)} m/s',
                label: '${_getWindDirection(_currentWeather!.windDirection)}風',
              ),
              _buildWeatherDetailItem(
                icon: Icons.wb_sunny,
                value: _sunset != null
                    ? DateFormat('HH:mm', 'zh_TW').format(_sunset!)
                    : '--:--',
                label: '日落',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuitableTimeCard() {
    final suitableTimes = _getSuitableWalkingTime();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text(
                '建議健走時間',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suitableTimes.isEmpty)
            const Text(
              '未來兩天內未找到特別適合健走的時段，建議在室內進行運動。',
              style: TextStyle(fontSize: 16),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未來適合健走的時間：',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...suitableTimes.map((time) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildForecastItem(WeatherData weather) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('MM/dd', 'zh_TW').format(weather.date),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            DateFormat('HH:mm', 'zh_TW').format(weather.date),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            _getWeatherIcon(weather.condition),
            color: _getWeatherColor(weather.condition),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            weather.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${weather.temperature.toStringAsFixed(1)}°C',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.blue[700],
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return Icons.wb_sunny;
      case 'Clouds':
        return Icons.cloud;
      case 'Rain':
        return Icons.beach_access;
      case 'Drizzle':
        return Icons.grain;
      case 'Thunderstorm':
        return Icons.flash_on;
      case 'Snow':
        return Icons.ac_unit;
      case 'Mist':
      case 'Fog':
        return Icons.cloud_queue;
      default:
        return Icons.cloud;
    }
  }

  Color _getWeatherColor(String condition) {
    switch (condition) {
      case 'Clear':
        return Colors.orange;
      case 'Clouds':
        return Colors.grey;
      case 'Rain':
        return Colors.blue;
      case 'Drizzle':
        return Colors.lightBlue;
      case 'Thunderstorm':
        return Colors.deepPurple;
      case 'Snow':
        return Colors.lightBlue;
      case 'Mist':
      case 'Fog':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}

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