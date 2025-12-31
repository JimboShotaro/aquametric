/// AquaMetric Mobile - API Client
/// 
/// バックエンドAPIとの通信を抽象化するクライアント
/// 
/// 使用例:
/// ```dart
/// final client = AquaMetricApiClient(baseUrl: 'https://api.aquametric.app');
/// final result = await client.uploadSession(sessionData);
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ========================================
// API Endpoints Definition
// ========================================

class ApiEndpoints {
  static const String sessions = '/api/v1/sessions';
  static const String upload = '/api/v1/sessions/upload';
  static const String users = '/api/v1/users';
  static const String analysis = '/api/v1/analysis';
  
  static String sessionStatus(String sessionId) => 
      '/api/v1/sessions/$sessionId/status';
  
  static String sessionAnalysis(String sessionId) => 
      '/api/v1/sessions/$sessionId/analysis';
  
  static String calendarStats(String startDate, String endDate) =>
      '/api/v1/users/stats/calendar?start_date=$startDate&end_date=$endDate';
}

// ========================================
// Data Transfer Objects (DTOs)
// ========================================

/// セッションアップロードのリクエスト
class SessionUploadRequest {
  final List<SensorReading> readings;
  final int poolLengthM;
  final String deviceType;
  final String? notes;
  
  SessionUploadRequest({
    required this.readings,
    this.poolLengthM = 25,
    this.deviceType = 'apple_watch',
    this.notes,
  });
  
  Map<String, dynamic> toJson() => {
    'readings': readings.map((r) => r.toJson()).toList(),
    'pool_length_m': poolLengthM,
    'device_type': deviceType,
    if (notes != null) 'notes': notes,
  };
}

/// センサーデータの1サンプル
class SensorReading {
  final double timestamp;
  final double accX;
  final double accY;
  final double accZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double? magX;
  final double? magY;
  final double? magZ;
  
  SensorReading({
    required this.timestamp,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'acc_x': accX,
    'acc_y': accY,
    'acc_z': accZ,
    'gyro_x': gyroX,
    'gyro_y': gyroY,
    'gyro_z': gyroZ,
    if (magX != null) 'mag_x': magX,
    if (magY != null) 'mag_y': magY,
    if (magZ != null) 'mag_z': magZ,
  };
  
  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
    timestamp: json['timestamp'].toDouble(),
    accX: json['acc_x'].toDouble(),
    accY: json['acc_y'].toDouble(),
    accZ: json['acc_z'].toDouble(),
    gyroX: json['gyro_x'].toDouble(),
    gyroY: json['gyro_y'].toDouble(),
    gyroZ: json['gyro_z'].toDouble(),
    magX: json['mag_x']?.toDouble(),
    magY: json['mag_y']?.toDouble(),
    magZ: json['mag_z']?.toDouble(),
  );
}

/// セッションステータス
enum SessionStatus {
  uploading,
  processing,
  completed,
  failed,
}

/// セッションステータスのレスポンス
class SessionStatusResponse {
  final String sessionId;
  final SessionStatus status;
  final int? progressPercent;
  final String? errorMessage;
  
  SessionStatusResponse({
    required this.sessionId,
    required this.status,
    this.progressPercent,
    this.errorMessage,
  });
  
  factory SessionStatusResponse.fromJson(Map<String, dynamic> json) =>
    SessionStatusResponse(
      sessionId: json['session_id'],
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.processing,
      ),
      progressPercent: json['progress_percent'],
      errorMessage: json['error_message'],
    );
}

/// ラップ詳細
class LapDetail {
  final int lapNumber;
  final String strokeType;
  final double durationSec;
  final int strokeCount;
  final int swolf;
  final double pacePer100m;
  
  LapDetail({
    required this.lapNumber,
    required this.strokeType,
    required this.durationSec,
    required this.strokeCount,
    required this.swolf,
    required this.pacePer100m,
  });
  
  factory LapDetail.fromJson(Map<String, dynamic> json) => LapDetail(
    lapNumber: json['lap_number'],
    strokeType: json['stroke_type'],
    durationSec: json['duration_sec'].toDouble(),
    strokeCount: json['stroke_count'],
    swolf: json['swolf'],
    pacePer100m: json['pace_per_100m'].toDouble(),
  );
}

/// 解析結果
class AnalysisResult {
  final String sessionId;
  final DateTime processedAt;
  final int poolLengthM;
  final int totalLaps;
  final int totalDistanceM;
  final List<LapDetail> laps;
  final String summaryText;
  
  AnalysisResult({
    required this.sessionId,
    required this.processedAt,
    required this.poolLengthM,
    required this.totalLaps,
    required this.totalDistanceM,
    required this.laps,
    required this.summaryText,
  });
  
  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
    sessionId: json['session_id'],
    processedAt: DateTime.parse(json['processed_at']),
    poolLengthM: json['pool_length_m'],
    totalLaps: json['total_laps'],
    totalDistanceM: json['total_distance_m'],
    laps: (json['laps'] as List)
        .map((l) => LapDetail.fromJson(l))
        .toList(),
    summaryText: json['summary_text'],
  );
}

/// カレンダー用日別統計
class DailyStat {
  final DateTime date;
  final int totalDistanceM;
  final int totalDurationSec;
  final int sessionCount;
  final int intensityLevel;
  
  DailyStat({
    required this.date,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.sessionCount,
    required this.intensityLevel,
  });
  
  factory DailyStat.fromJson(Map<String, dynamic> json) => DailyStat(
    date: DateTime.parse(json['date']),
    totalDistanceM: json['total_distance_m'],
    totalDurationSec: json['total_duration_sec'],
    sessionCount: json['session_count'],
    intensityLevel: json['intensity_level'],
  );
}

// ========================================
// API Client Interface
// ========================================

/// API通信の抽象インターフェース
abstract class IAquaMetricApi {
  /// セッションデータをアップロード
  Future<String> uploadSession(SessionUploadRequest request);
  
  /// セッションのステータスを取得
  Future<SessionStatusResponse> getSessionStatus(String sessionId);
  
  /// 解析結果を取得
  Future<AnalysisResult> getAnalysisResult(String sessionId);
  
  /// カレンダー統計を取得
  Future<List<DailyStat>> getCalendarStats(DateTime start, DateTime end);
}

// ========================================
// Mock Implementation (for development)
// ========================================

/// 開発用のモックAPIクライアント
class MockAquaMetricApi implements IAquaMetricApi {
  @override
  Future<String> uploadSession(SessionUploadRequest request) async {
    await Future.delayed(Duration(seconds: 1));
    return 'mock-session-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  @override
  Future<SessionStatusResponse> getSessionStatus(String sessionId) async {
    await Future.delayed(Duration(milliseconds: 500));
    return SessionStatusResponse(
      sessionId: sessionId,
      status: SessionStatus.completed,
      progressPercent: 100,
    );
  }
  
  @override
  Future<AnalysisResult> getAnalysisResult(String sessionId) async {
    await Future.delayed(Duration(milliseconds: 500));
    return AnalysisResult(
      sessionId: sessionId,
      processedAt: DateTime.now(),
      poolLengthM: 25,
      totalLaps: 10,
      totalDistanceM: 250,
      laps: List.generate(10, (i) => LapDetail(
        lapNumber: i + 1,
        strokeType: 'freestyle',
        durationSec: 25.0 + (i * 0.5),
        strokeCount: 18 + (i % 3),
        swolf: 43 + (i % 5),
        pacePer100m: 100.0 + (i * 2),
      )),
      summaryText: 'Completed 10 laps (250m). Primary stroke: freestyle.',
    );
  }
  
  @override
  Future<List<DailyStat>> getCalendarStats(DateTime start, DateTime end) async {
    await Future.delayed(Duration(milliseconds: 300));
    final stats = <DailyStat>[];
    var current = start;
    while (current.isBefore(end)) {
      if (current.weekday <= 5 && current.day % 2 == 0) {
        stats.add(DailyStat(
          date: current,
          totalDistanceM: 1000 + (current.day * 50),
          totalDurationSec: 1800 + (current.day * 30),
          sessionCount: 1,
          intensityLevel: (current.day % 4) + 1,
        ));
      }
      current = current.add(Duration(days: 1));
    }
    return stats;
  }
}
