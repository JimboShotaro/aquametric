import 'package:flutter/foundation.dart';

enum StrokeType {
  freestyle('クロール', 'Freestyle'),
  backstroke('背泳ぎ', 'Backstroke'),
  breaststroke('平泳ぎ', 'Breaststroke'),
  butterfly('バタフライ', 'Butterfly'),
  unknown('不明', 'Unknown'),
  rest('休憩', 'Rest');

  const StrokeType(this.japaneseName, this.englishName);
  final String japaneseName;
  final String englishName;
}

@immutable
class SwimLap {
  final int lapNumber;
  final StrokeType strokeType;
  final Duration duration;
  final int strokeCount;
  final int swolf;
  final double pacePerHundred; // seconds per 100m

  const SwimLap({
    required this.lapNumber,
    required this.strokeType,
    required this.duration,
    required this.strokeCount,
    required this.swolf,
    required this.pacePerHundred,
  });

  factory SwimLap.fromJson(Map<String, dynamic> json) {
    return SwimLap(
      lapNumber: json['lap_number'] as int,
      strokeType: StrokeType.values.firstWhere(
        (e) => e.englishName.toLowerCase() == (json['stroke_type'] as String).toLowerCase(),
        orElse: () => StrokeType.unknown,
      ),
      duration: Duration(milliseconds: ((json['duration'] as num) * 1000).toInt()),
      strokeCount: json['stroke_count'] as int,
      swolf: json['swolf'] as int,
      pacePerHundred: (json['pace_per_100m'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'lap_number': lapNumber,
    'stroke_type': strokeType.englishName.toLowerCase(),
    'duration': duration.inMilliseconds / 1000,
    'stroke_count': strokeCount,
    'swolf': swolf,
    'pace_per_100m': pacePerHundred,
  };
}

@immutable
class SwimSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int poolLength;
  final List<SwimLap> laps;
  final int totalDistance;
  final Duration totalDuration;
  final double avgPace;
  final int avgSwolf;
  final String status; // processing, completed, failed

  const SwimSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.poolLength = 25,
    this.laps = const [],
    this.totalDistance = 0,
    this.totalDuration = Duration.zero,
    this.avgPace = 0,
    this.avgSwolf = 0,
    this.status = 'processing',
  });

  int get totalLaps => laps.length;

  Map<StrokeType, int> get strokeDistribution {
    final distribution = <StrokeType, int>{};
    for (final lap in laps) {
      distribution[lap.strokeType] = (distribution[lap.strokeType] ?? 0) + 1;
    }
    return distribution;
  }

  factory SwimSession.fromJson(Map<String, dynamic> json) {
    return SwimSession(
      id: json['session_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'] as String) 
          : null,
      poolLength: json['pool_length'] as int? ?? 25,
      laps: (json['laps'] as List<dynamic>?)
          ?.map((e) => SwimLap.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      totalDistance: json['total_distance'] as int? ?? 0,
      totalDuration: Duration(
        seconds: (json['total_duration_sec'] as num?)?.toInt() ?? 0,
      ),
      avgPace: (json['avg_pace'] as num?)?.toDouble() ?? 0,
      avgSwolf: json['avg_swolf'] as int? ?? 0,
      status: json['status'] as String? ?? 'processing',
    );
  }
}

@immutable
class DailyStat {
  final DateTime date;
  final int totalDistance;
  final Duration totalDuration;
  final int sessionCount;
  final int intensityLevel; // 0-4 for heatmap

  const DailyStat({
    required this.date,
    required this.totalDistance,
    required this.totalDuration,
    required this.sessionCount,
    required this.intensityLevel,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) {
    return DailyStat(
      date: DateTime.parse(json['date'] as String),
      totalDistance: json['total_distance'] as int,
      totalDuration: Duration(seconds: json['total_duration_sec'] as int),
      sessionCount: json['session_count'] as int? ?? 1,
      intensityLevel: json['intensity_level'] as int,
    );
  }
}
