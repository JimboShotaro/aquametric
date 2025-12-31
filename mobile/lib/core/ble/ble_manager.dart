/// AquaMetric Mobile - BLE Manager
/// 
/// 腕時計（ウェアラブル）との Bluetooth Low Energy 通信を管理
/// 
/// 機能:
/// - デバイス検出とペアリング
/// - センサーデータの受信
/// - セッションデータのバッチ転送
/// 
/// 使用例:
/// ```dart
/// final bleManager = BleManager();
/// await bleManager.startDiscovery();
/// final device = await bleManager.connectToDevice(deviceId);
/// final data = await bleManager.syncSessionData();
/// ```

import 'dart:async';
import 'dart:typed_data';

// ========================================
// BLE Service UUIDs
// ========================================

/// AquaMetric カスタムBLEサービスUUID定義
class AquaMetricBleUuids {
  /// メインサービスUUID
  static const String swimService = '12345678-1234-5678-1234-56789abcdef0';
  
  /// センサーデータ通知用 Characteristic
  static const String sensorDataChar = '12345678-1234-5678-1234-56789abcdef1';
  
  /// セッション情報 Characteristic
  static const String sessionInfoChar = '12345678-1234-5678-1234-56789abcdef2';
  
  /// 同期コマンド Characteristic
  static const String syncCommandChar = '12345678-1234-5678-1234-56789abcdef3';
  
  /// デバイス情報 Characteristic
  static const String deviceInfoChar = '12345678-1234-5678-1234-56789abcdef4';
}

// ========================================
// Data Models
// ========================================

/// 検出されたBLEデバイス
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final bool isAquaMetricDevice;
  
  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isAquaMetricDevice,
  });
}

/// 接続されたデバイス情報
class ConnectedDevice {
  final String id;
  final String name;
  final String firmwareVersion;
  final int batteryLevel;
  final DateTime lastSyncTime;
  
  ConnectedDevice({
    required this.id,
    required this.name,
    required this.firmwareVersion,
    required this.batteryLevel,
    required this.lastSyncTime,
  });
}

/// 同期するセッションデータ
class PendingSession {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int sampleCount;
  final int bytesTotal;
  
  PendingSession({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.sampleCount,
    required this.bytesTotal,
  });
}

/// 同期の進捗状況
class SyncProgress {
  final String sessionId;
  final int bytesReceived;
  final int bytesTotal;
  final double progressPercent;
  final SyncState state;
  
  SyncProgress({
    required this.sessionId,
    required this.bytesReceived,
    required this.bytesTotal,
    required this.progressPercent,
    required this.state,
  });
}

enum SyncState {
  idle,
  discovering,
  connecting,
  syncing,
  completed,
  error,
}

// ========================================
// BLE Manager Interface
// ========================================

/// BLE通信の抽象インターフェース
abstract class IBleManager {
  /// Bluetoothが有効かどうか
  Future<bool> isBluetoothEnabled();
  
  /// AquaMetricデバイスを検出
  Stream<DiscoveredDevice> startDiscovery();
  
  /// 検出を停止
  Future<void> stopDiscovery();
  
  /// デバイスに接続
  Future<ConnectedDevice> connect(String deviceId);
  
  /// デバイスから切断
  Future<void> disconnect();
  
  /// 未同期のセッション一覧を取得
  Future<List<PendingSession>> getPendingSessions();
  
  /// セッションデータを同期
  Stream<SyncProgress> syncSession(String sessionId);
  
  /// 全ての未同期セッションを同期
  Stream<SyncProgress> syncAllSessions();
}

// ========================================
// センサーデータのバイナリフォーマット
// ========================================

/// センサーデータのProtobuf/バイナリパース
/// 
/// フォーマット (1サンプル = 28バイト):
/// - timestamp: int64 (8 bytes) - ナノ秒
/// - acc_x: float32 (4 bytes)
/// - acc_y: float32 (4 bytes)
/// - acc_z: float32 (4 bytes)
/// - gyro_x: float32 (4 bytes)
/// - gyro_y: float32 (4 bytes)
/// - gyro_z: float32 (4 bytes) -- 合計 32 bytes
class SensorDataParser {
  static const int bytesPerSample = 32;
  
  /// バイナリデータをセンサーデータのリストに変換
  static List<Map<String, double>> parse(Uint8List data) {
    final samples = <Map<String, double>>[];
    final buffer = data.buffer.asByteData();
    
    for (var offset = 0; offset < data.length; offset += bytesPerSample) {
      if (offset + bytesPerSample > data.length) break;
      
      samples.add({
        'timestamp': buffer.getInt64(offset, Endian.little).toDouble(),
        'acc_x': buffer.getFloat32(offset + 8, Endian.little).toDouble(),
        'acc_y': buffer.getFloat32(offset + 12, Endian.little).toDouble(),
        'acc_z': buffer.getFloat32(offset + 16, Endian.little).toDouble(),
        'gyro_x': buffer.getFloat32(offset + 20, Endian.little).toDouble(),
        'gyro_y': buffer.getFloat32(offset + 24, Endian.little).toDouble(),
        'gyro_z': buffer.getFloat32(offset + 28, Endian.little).toDouble(),
      });
    }
    
    return samples;
  }
}

// ========================================
// Mock Implementation
// ========================================

/// 開発用のモックBLEマネージャー
class MockBleManager implements IBleManager {
  bool _isConnected = false;
  
  @override
  Future<bool> isBluetoothEnabled() async => true;
  
  @override
  Stream<DiscoveredDevice> startDiscovery() async* {
    await Future.delayed(Duration(seconds: 1));
    yield DiscoveredDevice(
      id: 'mock-device-001',
      name: 'AquaMetric Watch',
      rssi: -45,
      isAquaMetricDevice: true,
    );
    
    await Future.delayed(Duration(milliseconds: 500));
    yield DiscoveredDevice(
      id: 'mock-device-002',
      name: 'Other BLE Device',
      rssi: -72,
      isAquaMetricDevice: false,
    );
  }
  
  @override
  Future<void> stopDiscovery() async {}
  
  @override
  Future<ConnectedDevice> connect(String deviceId) async {
    await Future.delayed(Duration(seconds: 2));
    _isConnected = true;
    return ConnectedDevice(
      id: deviceId,
      name: 'AquaMetric Watch',
      firmwareVersion: '1.0.0',
      batteryLevel: 85,
      lastSyncTime: DateTime.now().subtract(Duration(hours: 2)),
    );
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }
  
  @override
  Future<List<PendingSession>> getPendingSessions() async {
    if (!_isConnected) return [];
    
    return [
      PendingSession(
        sessionId: 'session-001',
        startTime: DateTime.now().subtract(Duration(hours: 1)),
        endTime: DateTime.now().subtract(Duration(minutes: 30)),
        sampleCount: 54000,  // 30 min * 60 sec * 30 Hz
        bytesTotal: 54000 * 32,
      ),
    ];
  }
  
  @override
  Stream<SyncProgress> syncSession(String sessionId) async* {
    for (var i = 0; i <= 100; i += 10) {
      await Future.delayed(Duration(milliseconds: 200));
      yield SyncProgress(
        sessionId: sessionId,
        bytesReceived: (54000 * 32 * i / 100).round(),
        bytesTotal: 54000 * 32,
        progressPercent: i.toDouble(),
        state: i < 100 ? SyncState.syncing : SyncState.completed,
      );
    }
  }
  
  @override
  Stream<SyncProgress> syncAllSessions() async* {
    final sessions = await getPendingSessions();
    for (final session in sessions) {
      await for (final progress in syncSession(session.sessionId)) {
        yield progress;
      }
    }
  }
}
