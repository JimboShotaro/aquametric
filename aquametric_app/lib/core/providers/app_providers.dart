import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquametric_app/core/models/swim_session.dart';
import 'package:aquametric_app/core/services/api_service.dart';
import 'package:aquametric_app/core/services/ble_service.dart';
import 'package:aquametric_app/core/database/database_helper.dart';
import 'package:aquametric_app/core/database/session_repository.dart';
import 'package:aquametric_app/core/controllers/swim_session_controller.dart';

// Database Helper Provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// Session Repository Provider
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

// Swim Session Controller Provider
final swimSessionControllerProvider = Provider<SwimSessionController>((ref) {
  return SwimSessionController(
    poolLength: 25,
    userWeightKg: 70.0,
  );
});

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// BLE Service Provider
final bleServiceProvider = Provider<BleService>((ref) {
  return BleService();
});

// Sessions Provider (now from local database)
final sessionsProvider = FutureProvider<List<SessionSummary>>((ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getAllSessions();
});

// Single Session Provider (from local database)
final sessionDetailProvider = FutureProvider.family<SessionDetail?, String>((ref, sessionId) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getSessionDetail(sessionId);
});

// Overall Stats Provider
final overallStatsProvider = FutureProvider<OverallStats>((ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getOverallStats();
});

// This Month Sessions Provider
final thisMonthSessionsProvider = FutureProvider<List<SessionSummary>>((ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getThisMonthSessions();
});

// Daily Stats Provider (for calendar heatmap)
final dailyStatsProvider = FutureProvider.family<List<DailyStat>, DateRange>((ref, range) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getDailyStats(range.start, range.end);
});

// BLE Connection State
final bleConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.connectionStateStream;
});

// Recording State Notifier
class RecordingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRecording(bool value) => state = value;
}

final isRecordingProvider = NotifierProvider<RecordingNotifier, bool>(() {
  return RecordingNotifier();
});

// Current Session ID Notifier
class SessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSessionId(String? value) => state = value;
}

final currentSessionIdProvider = NotifierProvider<SessionIdNotifier, String?>(() {
  return SessionIdNotifier();
});

// Helper class for date range
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
