import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../analysis/analysis_engine.dart';

/// SQLiteデータベースヘルパー
/// セッション・ラップ・センサーデータのローカル保存
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// データベース名
  static const String _databaseName = 'aquametric.db';
  static const int _databaseVersion = 1;

  /// テーブル名
  static const String tableSession = 'sessions';
  static const String tableLap = 'laps';
  static const String tableSensorData = 'sensor_data';

  /// データベース取得
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// データベース初期化
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// テーブル作成
  Future<void> _onCreate(Database db, int version) async {
    // セッションテーブル
    await db.execute('''
      CREATE TABLE $tableSession (
        id TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        pool_length INTEGER NOT NULL DEFAULT 25,
        total_laps INTEGER DEFAULT 0,
        total_distance INTEGER DEFAULT 0,
        total_duration_seconds INTEGER DEFAULT 0,
        average_swolf REAL DEFAULT 0,
        average_pace REAL DEFAULT 0,
        average_stroke_rate REAL DEFAULT 0,
        estimated_calories REAL DEFAULT 0,
        device_name TEXT,
        notes TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // ラップテーブル
    await db.execute('''
      CREATE TABLE $tableLap (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        lap_number INTEGER NOT NULL,
        stroke_type TEXT NOT NULL,
        confidence REAL DEFAULT 0,
        duration_seconds REAL NOT NULL,
        stroke_count INTEGER DEFAULT 0,
        swolf INTEGER DEFAULT 0,
        pace_per_100m REAL DEFAULT 0,
        stroke_rate REAL DEFAULT 0,
        start_index INTEGER,
        end_index INTEGER,
        FOREIGN KEY (session_id) REFERENCES $tableSession(id)
      )
    ''');

    // センサーデータテーブル（大量データ用に最適化）
    await db.execute('''
      CREATE TABLE $tableSensorData (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        timestamp REAL NOT NULL,
        acc_x REAL NOT NULL,
        acc_y REAL NOT NULL,
        acc_z REAL NOT NULL,
        gyro_x REAL DEFAULT 0,
        gyro_y REAL DEFAULT 0,
        gyro_z REAL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES $tableSession(id)
      )
    ''');

    // インデックス作成
    await db.execute(
        'CREATE INDEX idx_lap_session ON $tableLap(session_id)');
    await db.execute(
        'CREATE INDEX idx_sensor_session ON $tableSensorData(session_id)');
    await db.execute(
        'CREATE INDEX idx_session_date ON $tableSession(started_at)');
  }

  /// マイグレーション
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 将来のバージョンアップ用
  }

  // ==================== セッション操作 ====================

  /// セッションを作成
  Future<String> createSession({
    required String id,
    required DateTime startedAt,
    int poolLength = 25,
    String? deviceName,
  }) async {
    final db = await database;
    await db.insert(tableSession, {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'pool_length': poolLength,
      'device_name': deviceName,
    });
    return id;
  }

  /// セッション解析結果を更新
  Future<void> updateSessionWithResult(AnalysisResult result) async {
    final db = await database;

    // セッション更新
    await db.update(
      tableSession,
      {
        'total_laps': result.totalLaps,
        'total_distance': result.totalDistance,
        'total_duration_seconds': result.totalDuration.inSeconds,
        'average_swolf': result.averageSwolf,
        'average_pace': result.averagePace,
        'average_stroke_rate': result.averageStrokeRate,
        'estimated_calories': result.estimatedCalories,
      },
      where: 'id = ?',
      whereArgs: [result.sessionId],
    );

    // ラップデータを保存
    for (final lap in result.laps) {
      await db.insert(tableLap, {
        'session_id': result.sessionId,
        'lap_number': lap.lapNumber,
        'stroke_type': lap.strokeType.english,
        'confidence': lap.confidence,
        'duration_seconds': lap.durationSeconds,
        'stroke_count': lap.strokeCount,
        'swolf': lap.swolf,
        'pace_per_100m': lap.pacePerHundred,
        'stroke_rate': lap.strokeRate,
        'start_index': lap.startIndex,
        'end_index': lap.endIndex,
      });
    }
  }

  /// セッション終了
  Future<void> endSession(String sessionId) async {
    final db = await database;
    await db.update(
      tableSession,
      {'ended_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// セッション取得
  Future<Map<String, dynamic>?> getSession(String id) async {
    final db = await database;
    final results = await db.query(
      tableSession,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 全セッション取得（新しい順）
  Future<List<Map<String, dynamic>>> getAllSessions({
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableSession,
      orderBy: 'started_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 期間内のセッション取得
  Future<List<Map<String, dynamic>>> getSessionsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    return await db.query(
      tableSession,
      where: 'started_at >= ? AND started_at <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'started_at DESC',
    );
  }

  // ==================== ラップ操作 ====================

  /// セッションのラップ取得
  Future<List<Map<String, dynamic>>> getLapsForSession(String sessionId) async {
    final db = await database;
    return await db.query(
      tableLap,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'lap_number ASC',
    );
  }

  // ==================== センサーデータ操作 ====================

  /// センサーデータをバッチ保存
  Future<void> saveSensorDataBatch({
    required String sessionId,
    required List<SensorReading> readings,
  }) async {
    final db = await database;
    final batch = db.batch();

    for (final reading in readings) {
      batch.insert(tableSensorData, {
        'session_id': sessionId,
        'timestamp': reading.timestamp,
        'acc_x': reading.accX,
        'acc_y': reading.accY,
        'acc_z': reading.accZ,
        'gyro_x': reading.gyroX,
        'gyro_y': reading.gyroY,
        'gyro_z': reading.gyroZ,
      });
    }

    await batch.commit(noResult: true);
  }

  /// セッションのセンサーデータ取得
  Future<List<SensorReading>> getSensorDataForSession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      tableSensorData,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return results.map((row) => SensorReading(
      timestamp: (row['timestamp'] as num).toDouble(),
      accX: (row['acc_x'] as num).toDouble(),
      accY: (row['acc_y'] as num).toDouble(),
      accZ: (row['acc_z'] as num).toDouble(),
      gyroX: (row['gyro_x'] as num?)?.toDouble() ?? 0.0,
      gyroY: (row['gyro_y'] as num?)?.toDouble() ?? 0.0,
      gyroZ: (row['gyro_z'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  // ==================== 統計情報 ====================

  /// 全体統計を取得
  Future<Map<String, dynamic>> getOverallStats() async {
    final db = await database;

    final totalSessions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableSession'),
    ) ?? 0;

    final totalDistance = Sqflite.firstIntValue(
      await db.rawQuery('SELECT SUM(total_distance) FROM $tableSession'),
    ) ?? 0;

    final totalDuration = Sqflite.firstIntValue(
      await db.rawQuery('SELECT SUM(total_duration_seconds) FROM $tableSession'),
    ) ?? 0;

    final totalCalories = (await db.rawQuery(
      'SELECT SUM(estimated_calories) as total FROM $tableSession',
    )).first['total'] as double? ?? 0.0;

    return {
      'total_sessions': totalSessions,
      'total_distance': totalDistance,
      'total_duration_seconds': totalDuration,
      'total_calories': totalCalories,
    };
  }

  /// セッション削除
  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(tableSensorData, where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete(tableLap, where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete(tableSession, where: 'id = ?', whereArgs: [sessionId]);
  }

  /// データベースをクローズ
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
