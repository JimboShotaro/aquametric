import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquametric_app/core/models/swim_session.dart';
import 'package:aquametric_app/core/services/api_service.dart';
import 'package:aquametric_app/core/services/ble_service.dart';

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// BLE Service Provider
final bleServiceProvider = Provider<BleService>((ref) {
  return BleService();
});

// Sessions Provider
final sessionsProvider = FutureProvider<List<SwimSession>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getSessions();
});

// Single Session Provider
final sessionProvider = FutureProvider.family<SwimSession?, String>((ref, sessionId) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getSession(sessionId);
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
