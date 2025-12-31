import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import '../analysis/analysis_engine.dart';

/// セッションリポジトリ
/// セッションデータのCRUD操作を提供
class SessionRepository {
  final DatabaseHelper _db;
  final Uuid _uuid = const Uuid();

  SessionRepository({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  /// 新しいセッションを開始
  Future<String> startSession({
    int poolLength = 25,
    String? deviceName,
  }) async {
    final sessionId = _uuid.v4();
    await _db.createSession(
      id: sessionId,
      startedAt: DateTime.now(),
      poolLength: poolLength,
      deviceName: deviceName,
    );
    return sessionId;
  }

  /// センサーデータを保存
  Future<void> saveSensorData({
    required String sessionId,
    required List<SensorReading> readings,
  }) async {
    await _db.saveSensorDataBatch(
      sessionId: sessionId,
      readings: readings,
    );
  }

  /// セッションを終了し解析結果を保存
  Future<AnalysisResult> finishSession({
    required String sessionId,
    required AnalysisResult result,
  }) async {
    await _db.endSession(sessionId);
    await _db.updateSessionWithResult(result);
    return result;
  }

  /// セッション詳細を取得
  Future<SessionDetail?> getSessionDetail(String sessionId) async {
    final session = await _db.getSession(sessionId);
    if (session == null) return null;

    final laps = await _db.getLapsForSession(sessionId);

    return SessionDetail.fromMap(session, laps);
  }

  /// 全セッション一覧を取得
  Future<List<SessionSummary>> getAllSessions({
    int? limit,
    int? offset,
  }) async {
    final sessions = await _db.getAllSessions(limit: limit, offset: offset);
    return sessions.map((s) => SessionSummary.fromMap(s)).toList();
  }

  /// 期間内のセッションを取得
  Future<List<SessionSummary>> getSessionsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final sessions = await _db.getSessionsInRange(start: start, end: end);
    return sessions.map((s) => SessionSummary.fromMap(s)).toList();
  }

  /// 今月のセッションを取得
  Future<List<SessionSummary>> getThisMonthSessions() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getSessionsInRange(start: start, end: end);
  }

  /// 全体統計を取得
  Future<OverallStats> getOverallStats() async {
    final stats = await _db.getOverallStats();
    return OverallStats.fromMap(stats);
  }

  /// セッションを削除
  Future<void> deleteSession(String sessionId) async {
    await _db.deleteSession(sessionId);
  }

  /// センサーデータを取得（再解析用）
  Future<List<SensorReading>> getSensorData(String sessionId) async {
    return await _db.getSensorDataForSession(sessionId);
  }
}

/// セッションサマリー（一覧表示用）
class SessionSummary {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int poolLength;
  final int totalLaps;
  final int totalDistance;
  final Duration totalDuration;
  final double averageSwolf;
  final double estimatedCalories;

  SessionSummary({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.poolLength,
    required this.totalLaps,
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSwolf,
    required this.estimatedCalories,
  });

  factory SessionSummary.fromMap(Map<String, dynamic> map) {
    return SessionSummary(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      poolLength: map['pool_length'] as int? ?? 25,
      totalLaps: map['total_laps'] as int? ?? 0,
      totalDistance: map['total_distance'] as int? ?? 0,
      totalDuration: Duration(seconds: map['total_duration_seconds'] as int? ?? 0),
      averageSwolf: (map['average_swolf'] as num?)?.toDouble() ?? 0.0,
      estimatedCalories: (map['estimated_calories'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// セッション詳細（詳細画面用）
class SessionDetail extends SessionSummary {
  final double averagePace;
  final double averageStrokeRate;
  final String? deviceName;
  final String? notes;
  final List<LapSummary> laps;

  SessionDetail({
    required super.id,
    required super.startedAt,
    super.endedAt,
    required super.poolLength,
    required super.totalLaps,
    required super.totalDistance,
    required super.totalDuration,
    required super.averageSwolf,
    required super.estimatedCalories,
    required this.averagePace,
    required this.averageStrokeRate,
    this.deviceName,
    this.notes,
    required this.laps,
  });

  factory SessionDetail.fromMap(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> lapMaps,
  ) {
    return SessionDetail(
      id: session['id'] as String,
      startedAt: DateTime.parse(session['started_at'] as String),
      endedAt: session['ended_at'] != null
          ? DateTime.parse(session['ended_at'] as String)
          : null,
      poolLength: session['pool_length'] as int? ?? 25,
      totalLaps: session['total_laps'] as int? ?? 0,
      totalDistance: session['total_distance'] as int? ?? 0,
      totalDuration: Duration(seconds: session['total_duration_seconds'] as int? ?? 0),
      averageSwolf: (session['average_swolf'] as num?)?.toDouble() ?? 0.0,
      estimatedCalories: (session['estimated_calories'] as num?)?.toDouble() ?? 0.0,
      averagePace: (session['average_pace'] as num?)?.toDouble() ?? 0.0,
      averageStrokeRate: (session['average_stroke_rate'] as num?)?.toDouble() ?? 0.0,
      deviceName: session['device_name'] as String?,
      notes: session['notes'] as String?,
      laps: lapMaps.map((l) => LapSummary.fromMap(l)).toList(),
    );
  }
}

/// ラップサマリー
class LapSummary {
  final int lapNumber;
  final String strokeType;
  final double durationSeconds;
  final int strokeCount;
  final int swolf;
  final double pacePerHundred;

  LapSummary({
    required this.lapNumber,
    required this.strokeType,
    required this.durationSeconds,
    required this.strokeCount,
    required this.swolf,
    required this.pacePerHundred,
  });

  factory LapSummary.fromMap(Map<String, dynamic> map) {
    return LapSummary(
      lapNumber: map['lap_number'] as int,
      strokeType: map['stroke_type'] as String,
      durationSeconds: (map['duration_seconds'] as num).toDouble(),
      strokeCount: map['stroke_count'] as int? ?? 0,
      swolf: map['swolf'] as int? ?? 0,
      pacePerHundred: (map['pace_per_100m'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).floor();
    final seconds = (durationSeconds % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 全体統計
class OverallStats {
  final int totalSessions;
  final int totalDistance;
  final Duration totalDuration;
  final double totalCalories;

  OverallStats({
    required this.totalSessions,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalCalories,
  });

  factory OverallStats.fromMap(Map<String, dynamic> map) {
    return OverallStats(
      totalSessions: map['total_sessions'] as int? ?? 0,
      totalDistance: map['total_distance'] as int? ?? 0,
      totalDuration: Duration(seconds: map['total_duration_seconds'] as int? ?? 0),
      totalCalories: (map['total_calories'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
