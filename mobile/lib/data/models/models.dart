/// AquaMetric Mobile - Data Models
/// 
/// ドメインモデルとデータクラスの定義

// ========================================
// Swimming Session
// ========================================

/// 水泳セッションの完全なデータ
class SwimSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int poolLengthM;
  final SessionStatus status;
  final List<SwimLap> laps;
  final SessionSummary? summary;
  
  SwimSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.poolLengthM = 25,
    this.status = SessionStatus.pending,
    this.laps = const [],
    this.summary,
  });
  
  /// セッションの所要時間
  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }
  
  /// 総距離
  int get totalDistanceM => laps.length * poolLengthM;
  
  /// JSON変換
  Map<String, dynamic> toJson() => {
    'id': id,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'pool_length_m': poolLengthM,
    'status': status.name,
    'laps': laps.map((l) => l.toJson()).toList(),
  };
  
  factory SwimSession.fromJson(Map<String, dynamic> json) => SwimSession(
    id: json['id'],
    startTime: DateTime.parse(json['start_time']),
    endTime: json['end_time'] != null 
        ? DateTime.parse(json['end_time']) 
        : null,
    poolLengthM: json['pool_length_m'] ?? 25,
    status: SessionStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => SessionStatus.pending,
    ),
    laps: (json['laps'] as List?)
        ?.map((l) => SwimLap.fromJson(l))
        .toList() ?? [],
  );
}

enum SessionStatus {
  pending,    // デバイスに保存中、未同期
  syncing,    // 同期中
  processing, // サーバーで解析中
  completed,  // 解析完了
  failed,     // 失敗
}

// ========================================
// Swimming Lap
// ========================================

/// 1ラップの詳細データ
class SwimLap {
  final int lapNumber;
  final StrokeType strokeType;
  final double durationSec;
  final int strokeCount;
  final int swolf;
  final double pacePer100m;
  final double startTime;  // セッション開始からの秒数
  final double endTime;
  
  SwimLap({
    required this.lapNumber,
    required this.strokeType,
    required this.durationSec,
    required this.strokeCount,
    required this.swolf,
    required this.pacePer100m,
    required this.startTime,
    required this.endTime,
  });
  
  Map<String, dynamic> toJson() => {
    'lap_number': lapNumber,
    'stroke_type': strokeType.name,
    'duration_sec': durationSec,
    'stroke_count': strokeCount,
    'swolf': swolf,
    'pace_per_100m': pacePer100m,
    'start_time': startTime,
    'end_time': endTime,
  };
  
  factory SwimLap.fromJson(Map<String, dynamic> json) => SwimLap(
    lapNumber: json['lap_number'],
    strokeType: StrokeType.values.firstWhere(
      (s) => s.name == json['stroke_type'],
      orElse: () => StrokeType.unknown,
    ),
    durationSec: (json['duration_sec'] as num).toDouble(),
    strokeCount: json['stroke_count'],
    swolf: json['swolf'],
    pacePer100m: (json['pace_per_100m'] as num).toDouble(),
    startTime: (json['start_time'] as num).toDouble(),
    endTime: (json['end_time'] as num).toDouble(),
  );
}

// ========================================
// Stroke Type
// ========================================

/// 泳法の種類
enum StrokeType {
  freestyle,     // クロール
  backstroke,    // 背泳ぎ
  breaststroke,  // 平泳ぎ
  butterfly,     // バタフライ
  unknown,
  rest,
  turn,
}

extension StrokeTypeExtension on StrokeType {
  String get displayName {
    switch (this) {
      case StrokeType.freestyle:
        return 'クロール';
      case StrokeType.backstroke:
        return '背泳ぎ';
      case StrokeType.breaststroke:
        return '平泳ぎ';
      case StrokeType.butterfly:
        return 'バタフライ';
      case StrokeType.unknown:
        return '不明';
      case StrokeType.rest:
        return '休憩';
      case StrokeType.turn:
        return 'ターン';
    }
  }
  
  String get icon {
    switch (this) {
      case StrokeType.freestyle:
        return '🏊';
      case StrokeType.backstroke:
        return '🔙';
      case StrokeType.breaststroke:
        return '🐸';
      case StrokeType.butterfly:
        return '🦋';
      default:
        return '❓';
    }
  }
}

// ========================================
// Session Summary
// ========================================

/// セッションのサマリー統計
class SessionSummary {
  final int totalLaps;
  final int totalDistanceM;
  final double totalDurationSec;
  final double avgPacePer100m;
  final double avgSwolf;
  final StrokeType primaryStroke;
  final Map<StrokeType, int> strokeBreakdown;
  
  SessionSummary({
    required this.totalLaps,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.avgPacePer100m,
    required this.avgSwolf,
    required this.primaryStroke,
    required this.strokeBreakdown,
  });
  
  /// 平均ペースを "分:秒/100m" 形式で取得
  String get paceFormatted {
    final minutes = (avgPacePer100m ~/ 60);
    final seconds = (avgPacePer100m % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/100m';
  }
}

// ========================================
// Daily Statistics
// ========================================

/// カレンダー表示用の日別統計
class DailySwimStat {
  final DateTime date;
  final int totalDistanceM;
  final Duration totalDuration;
  final int sessionCount;
  final int intensityLevel; // 0-4 for heatmap color
  
  DailySwimStat({
    required this.date,
    required this.totalDistanceM,
    required this.totalDuration,
    required this.sessionCount,
    required this.intensityLevel,
  });
  
  /// heatmap用のカラーレベル (0.0 - 1.0)
  double get intensity => intensityLevel / 4.0;
}

// ========================================
// User Profile
// ========================================

/// ユーザープロフィール
class UserProfile {
  final String id;
  final String name;
  final String email;
  final int defaultPoolLengthM;
  final DateTime createdAt;
  
  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.defaultPoolLengthM = 25,
    required this.createdAt,
  });
}

// ========================================
// User Statistics
// ========================================

/// ユーザーの累積統計
class UserStats {
  final int totalSessions;
  final int totalDistanceM;
  final Duration totalDuration;
  final double avgSwolf;
  final StrokeType favoriteStroke;
  final int currentStreakDays;
  final int bestStreakDays;
  final int thisWeekDistanceM;
  final int thisMonthDistanceM;
  
  UserStats({
    required this.totalSessions,
    required this.totalDistanceM,
    required this.totalDuration,
    required this.avgSwolf,
    required this.favoriteStroke,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.thisWeekDistanceM,
    required this.thisMonthDistanceM,
  });
}
