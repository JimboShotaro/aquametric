/// AquaMetric Apple Watch - Sensor Manager
///
/// CoreMotion を使用した100Hzセンサーデータ収集
/// 
/// SwimBIT仕様: 100Hz サンプリングレート必須

import Foundation
import CoreMotion

// MARK: - Constants

enum SensorConstants {
    /// SwimBIT仕様の100Hz
    static let samplingRate: Double = 100.0
    static let updateInterval: TimeInterval = 1.0 / samplingRate
    
    /// バッファサイズ（5秒分）
    static let bufferSize: Int = 500
    
    /// 32 bytes per sample (timestamp + 6 floats + padding)
    static let bytesPerSample: Int = 32
}

// MARK: - Sensor Data Model

/// 1サンプルのセンサーデータ
struct SensorSample {
    let timestamp: UInt64        // ナノ秒
    let accelerometerX: Float
    let accelerometerY: Float
    let accelerometerZ: Float
    let gyroscopeX: Float
    let gyroscopeY: Float
    let gyroscopeZ: Float
    
    /// バイナリ形式に変換（32バイト）
    func toBytes() -> Data {
        var data = Data(capacity: SensorConstants.bytesPerSample)
        
        var ts = timestamp
        data.append(Data(bytes: &ts, count: 8))
        
        var ax = accelerometerX, ay = accelerometerY, az = accelerometerZ
        data.append(Data(bytes: &ax, count: 4))
        data.append(Data(bytes: &ay, count: 4))
        data.append(Data(bytes: &az, count: 4))
        
        var gx = gyroscopeX, gy = gyroscopeY, gz = gyroscopeZ
        data.append(Data(bytes: &gx, count: 4))
        data.append(Data(bytes: &gy, count: 4))
        data.append(Data(bytes: &gz, count: 4))
        
        // Padding to 32 bytes
        data.append(contentsOf: [UInt8](repeating: 0, count: 4))
        
        return data
    }
}

// MARK: - Ring Buffer

/// リングバッファ - メモリ効率的なセンサーデータ蓄積
class RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [T?](repeating: nil, count: capacity)
    }
    
    func write(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }
    
    func readAll() -> [T] {
        var result: [T] = []
        for i in 0..<count {
            let index = (readIndex + i) % capacity
            if let element = buffer[index] {
                result.append(element)
            }
        }
        return result
    }
    
    func clear() {
        writeIndex = 0
        readIndex = 0
        count = 0
        buffer = [T?](repeating: nil, count: capacity)
    }
}

// MARK: - Sensor Manager Protocol

protocol SensorManagerDelegate: AnyObject {
    func sensorManager(_ manager: SensorManager, didCollectBatch samples: [SensorSample])
    func sensorManager(_ manager: SensorManager, didEncounterError error: Error)
}

// MARK: - Sensor Manager

/// センサーデータ収集マネージャー
class SensorManager {
    
    // MARK: Properties
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var buffer: RingBuffer<SensorSample>
    private var isRecording = false
    private var sessionStartTime: UInt64 = 0
    
    weak var delegate: SensorManagerDelegate?
    
    // MARK: Initialization
    
    init() {
        buffer = RingBuffer(capacity: SensorConstants.bufferSize)
        queue.name = "com.aquametric.sensor"
        queue.maxConcurrentOperationCount = 1
    }
    
    // MARK: Recording Control
    
    /// センサー記録を開始
    func startRecording() -> Bool {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return false
        }
        
        guard !isRecording else {
            return true
        }
        
        // 100Hz設定
        motionManager.deviceMotionUpdateInterval = SensorConstants.updateInterval
        
        // 開始時刻を記録
        sessionStartTime = currentNanoseconds()
        
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    self?.delegate?.sensorManager(self!, didEncounterError: error)
                }
                return
            }
            
            self.processSensorData(motion)
        }
        
        isRecording = true
        print("Started recording at 100Hz")
        return true
    }
    
    /// センサー記録を停止
    func stopRecording() -> [SensorSample] {
        guard isRecording else { return [] }
        
        motionManager.stopDeviceMotionUpdates()
        isRecording = false
        
        // 残りのデータを返す
        let remainingSamples = buffer.readAll()
        buffer.clear()
        
        print("Stopped recording. Total samples in buffer: \(remainingSamples.count)")
        return remainingSamples
    }
    
    // MARK: Private Methods
    
    private func processSensorData(_ motion: CMDeviceMotion) {
        let sample = SensorSample(
            timestamp: currentNanoseconds(),
            accelerometerX: Float(motion.userAcceleration.x),
            accelerometerY: Float(motion.userAcceleration.y),
            accelerometerZ: Float(motion.userAcceleration.z),
            gyroscopeX: Float(motion.rotationRate.x),
            gyroscopeY: Float(motion.rotationRate.y),
            gyroscopeZ: Float(motion.rotationRate.z)
        )
        
        buffer.write(sample)
        
        // バッファが満杯になったらフラッシュ
        if buffer.count >= SensorConstants.bufferSize {
            let batch = buffer.readAll()
            buffer.clear()
            delegate?.sensorManager(self, didCollectBatch: batch)
        }
    }
    
    private func currentNanoseconds() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}

// MARK: - Storage Manager

/// ローカルストレージへのセンサーデータ保存
class StorageManager {
    
    private let fileManager = FileManager.default
    
    var sessionsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("sessions", isDirectory: true)
    }
    
    init() {
        // セッションディレクトリを作成
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }
    
    /// セッションデータをファイルに保存
    func saveSession(sessionId: String, samples: [SensorSample]) throws -> URL {
        let fileURL = sessionsDirectory.appendingPathComponent("\(sessionId).bin")
        
        var data = Data()
        for sample in samples {
            data.append(sample.toBytes())
        }
        
        try data.write(to: fileURL)
        print("Saved \(samples.count) samples to \(fileURL.lastPathComponent)")
        
        return fileURL
    }
    
    /// 未同期セッションの一覧を取得
    func getPendingSessions() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        return files.filter { $0.pathExtension == "bin" }
    }
    
    /// セッションファイルを削除（同期完了後）
    func deleteSession(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
}

// MARK: - Session Manager

/// 水泳セッションの管理
class SessionManager: SensorManagerDelegate {
    
    private let sensorManager = SensorManager()
    private let storageManager = StorageManager()
    
    private var currentSessionId: String?
    private var currentSessionSamples: [SensorSample] = []
    private var sessionStartTime: Date?
    
    var isSessionActive: Bool { currentSessionId != nil }
    
    init() {
        sensorManager.delegate = self
    }
    
    // MARK: Session Control
    
    /// セッション開始
    func startSession(poolLengthM: Int = 25) -> String {
        let sessionId = UUID().uuidString
        currentSessionId = sessionId
        currentSessionSamples = []
        sessionStartTime = Date()
        
        let started = sensorManager.startRecording()
        print("Session \(sessionId) started: \(started)")
        
        return sessionId
    }
    
    /// セッション終了
    func endSession() -> String? {
        guard let sessionId = currentSessionId else { return nil }
        
        // 残りのサンプルを取得
        let remainingSamples = sensorManager.stopRecording()
        currentSessionSamples.append(contentsOf: remainingSamples)
        
        // ファイルに保存
        do {
            _ = try storageManager.saveSession(
                sessionId: sessionId,
                samples: currentSessionSamples
            )
        } catch {
            print("Failed to save session: \(error)")
        }
        
        let endedSessionId = currentSessionId
        currentSessionId = nil
        currentSessionSamples = []
        sessionStartTime = nil
        
        return endedSessionId
    }
    
    /// 経過時間を取得
    var elapsedTime: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    /// 現在のサンプル数を取得
    var sampleCount: Int {
        return currentSessionSamples.count
    }
    
    // MARK: SensorManagerDelegate
    
    func sensorManager(_ manager: SensorManager, didCollectBatch samples: [SensorSample]) {
        currentSessionSamples.append(contentsOf: samples)
        
        // ログ出力（デバッグ用）
        print("Collected batch: \(samples.count) samples. Total: \(currentSessionSamples.count)")
    }
    
    func sensorManager(_ manager: SensorManager, didEncounterError error: Error) {
        print("Sensor error: \(error)")
    }
}
