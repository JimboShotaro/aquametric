import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:aquametric_app/core/models/swim_session.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add logging interceptor for debug
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Upload sensor data from wearable
  Future<String> uploadSession({
    required Uint8List sensorData,
    required int poolLength,
    required DateTime startTime,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          sensorData,
          filename: 'sensor_data.bin',
        ),
        'pool_length': poolLength,
        'start_time': startTime.toIso8601String(),
      });

      final response = await _dio.post(
        '/sessions/upload',
        data: formData,
      );

      return response.data['session_id'] as String;
    } on DioException catch (e) {
      throw ApiException('Upload failed: ${e.message}');
    }
  }

  /// Get session status
  Future<String> getSessionStatus(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/status');
      return response.data['status'] as String;
    } on DioException catch (e) {
      throw ApiException('Failed to get status: ${e.message}');
    }
  }

  /// Get session analysis result
  Future<SwimSession?> getSession(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/analysis');
      return SwimSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw ApiException('Failed to get session: ${e.message}');
    }
  }

  /// Get all sessions for the user
  Future<List<SwimSession>> getSessions({int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/sessions',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      
      final sessions = (response.data['sessions'] as List<dynamic>)
          .map((e) => SwimSession.fromJson(e as Map<String, dynamic>))
          .toList();
      
      return sessions;
    } on DioException catch (e) {
      throw ApiException('Failed to get sessions: ${e.message}');
    }
  }

  /// Get daily stats for calendar heatmap
  Future<List<DailyStat>> getDailyStats(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _dio.get(
        '/users/stats/calendar',
        queryParameters: {
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
        },
      );
      
      final stats = (response.data as List<dynamic>)
          .map((e) => DailyStat.fromJson(e as Map<String, dynamic>))
          .toList();
      
      return stats;
    } on DioException catch (e) {
      throw ApiException('Failed to get stats: ${e.message}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
