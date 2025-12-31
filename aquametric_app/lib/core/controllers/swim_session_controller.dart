import 'dart:typed_data';
import '../analysis/analysis_engine.dart';
import '../database/session_repository.dart';

/// 水泳セッションコントローラー
/// BLEデータ受信→解析→DB保存のパイプラインを管理
class SwimSessionController {
  final AnalysisEngine _analysisEngine;
  final SessionRepository _repository;

  String? _currentSessionId;
  final List<SensorReading> _sensorBuffer = [];
  DateTime? _sessionStartTime;
  bool _isRecording = false;

  /// バッファサイズ（この数に達したらDBにフラッシュ）
  static const int _bufferFlushSize = 1000;

  SwimSessionController({
    int poolLength = 25,
    double userWeightKg = 70.0,
    SessionRepository? repository,
    AnalysisEngine? analysisEngine,
  })  : _repository = repository ?? SessionRepository(),
        _analysisEngine = analysisEngine ??
            AnalysisEngine(
              poolLength: poolLength,
              userWeightKg: userWeightKg,
            );

  /// 現在のセッションID
  String? get currentSessionId => _currentSessionId;

  /// 記録中かどうか
  bool get isRecording => _isRecording;

  /// セッション開始時刻
  DateTime? get sessionStartTime => _sessionStartTime;

  /// バッファ内のデータ数
  int get bufferSize => _sensorBuffer.length;

  /// セッションを開始
  Future<String> startSession({
    int poolLength = 25,
    String? deviceName,
  }) async {
    if (_isRecording) {
      throw StateError('Session already in progress');
    }

    _currentSessionId = await _repository.startSession(
      poolLength: poolLength,
      deviceName: deviceName,
    );
    _sessionStartTime = DateTime.now();
    _sensorBuffer.clear();
    _isRecording = true;

    return _currentSessionId!;
  }

  /// センサーデータを追加（BLEから受信時に呼び出し）
  Future<void> addSensorReading(SensorReading reading) async {
    if (!_isRecording || _currentSessionId == null) {
      return;
    }

    _sensorBuffer.add(reading);

    // バッファが一定サイズに達したらDBにフラッシュ
    if (_sensorBuffer.length >= _bufferFlushSize) {
      await _flushBuffer();
    }
  }

  /// 複数のセンサーデータを追加（バッチ処理）
  Future<void> addSensorReadings(List<SensorReading> readings) async {
    if (!_isRecording || _currentSessionId == null) {
      return;
    }

    _sensorBuffer.addAll(readings);

    if (_sensorBuffer.length >= _bufferFlushSize) {
      await _flushBuffer();
    }
  }

  /// バッファをDBにフラッシュ
  Future<void> _flushBuffer() async {
    if (_currentSessionId == null || _sensorBuffer.isEmpty) {
      return;
    }

    await _repository.saveSensorData(
      sessionId: _currentSessionId!,
      readings: List.from(_sensorBuffer),
    );
    _sensorBuffer.clear();
  }

  /// セッションを終了し解析を実行
  Future<AnalysisResult> finishSession() async {
    if (!_isRecording || _currentSessionId == null) {
      throw StateError('No session in progress');
    }

    // 残りのバッファをフラッシュ
    await _flushBuffer();

    // 全センサーデータを取得
    final allReadings = await _repository.getSensorData(_currentSessionId!);

    // 解析実行
    final result = await _analysisEngine.analyze(
      sessionId: _currentSessionId!,
      rawData: allReadings,
    );

    // 結果を保存
    await _repository.finishSession(
      sessionId: _currentSessionId!,
      result: result,
    );

    // 状態リセット
    _isRecording = false;
    _currentSessionId = null;
    _sessionStartTime = null;

    return result;
  }

  /// セッションをキャンセル（データ破棄）
  Future<void> cancelSession() async {
    if (_currentSessionId != null) {
      await _repository.deleteSession(_currentSessionId!);
    }

    _isRecording = false;
    _currentSessionId = null;
    _sessionStartTime = null;
    _sensorBuffer.clear();
  }

  /// 経過時間を取得
  Duration get elapsedTime {
    if (_sessionStartTime == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_sessionStartTime!);
  }
}

/// BLEパケットをSensorReadingに変換するユーティリティ
class BleDataParser {
  /// BLEパケットからセンサーデータをパース
  /// パケットフォーマット: [timestamp(8), accX(4), accY(4), accZ(4), gyroX(4), gyroY(4), gyroZ(4)]
  static SensorReading? parsePacket(List<int> data) {
    if (data.length < 32) {
      return null;
    }

    try {
      final bytes = Uint8List.fromList(data);
      final byteData = ByteData.sublistView(bytes);

      final timestamp = byteData.getFloat64(0, Endian.little);
      final accX = byteData.getFloat32(8, Endian.little);
      final accY = byteData.getFloat32(12, Endian.little);
      final accZ = byteData.getFloat32(16, Endian.little);
      final gyroX = byteData.getFloat32(20, Endian.little);
      final gyroY = byteData.getFloat32(24, Endian.little);
      final gyroZ = byteData.getFloat32(28, Endian.little);

      return SensorReading(
        timestamp: timestamp,
        accX: accX,
        accY: accY,
        accZ: accZ,
        gyroX: gyroX,
        gyroY: gyroY,
        gyroZ: gyroZ,
      );
    } catch (e) {
      return null;
    }
  }

  /// 簡易フォーマット: [accX(4), accY(4), accZ(4)] のみ
  static SensorReading parseSimplePacket(List<int> data, double timestamp) {
    if (data.length < 12) {
      return SensorReading(
        timestamp: timestamp,
        accX: 0,
        accY: 0,
        accZ: 0,
        gyroX: 0,
        gyroY: 0,
        gyroZ: 0,
      );
    }

    final bytes = Uint8List.fromList(data);
    final byteData = ByteData.sublistView(bytes);

    return SensorReading(
      timestamp: timestamp,
      accX: byteData.getFloat32(0, Endian.little),
      accY: byteData.getFloat32(4, Endian.little),
      accZ: byteData.getFloat32(8, Endian.little),
      gyroX: 0,
      gyroY: 0,
      gyroZ: 0,
    );
  }
}
