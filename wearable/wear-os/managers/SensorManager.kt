/**
 * AquaMetric WearOS - Sensor Manager
 * 
 * Android SensorManager を使用した100Hzセンサーデータ収集
 * SwimBIT仕様: 100Hz サンプリングレート必須
 */

package com.aquametric.wearable.managers

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.ConcurrentLinkedQueue

// ========================================
// Constants
// ========================================

object SensorConstants {
    /** SwimBIT仕様の100Hz */
    const val SAMPLING_RATE_HZ = 100
    
    /** マイクロ秒単位のサンプリング間隔 */
    const val SAMPLING_PERIOD_US = 1_000_000 / SAMPLING_RATE_HZ
    
    /** バッファサイズ（5秒分） */
    const val BUFFER_SIZE = 500
    
    /** 1サンプルあたりのバイト数 */
    const val BYTES_PER_SAMPLE = 32
}

// ========================================
// Data Models
// ========================================

/**
 * 1サンプルのセンサーデータ
 */
data class SensorSample(
    val timestamp: Long,        // ナノ秒
    val accelerometerX: Float,
    val accelerometerY: Float,
    val accelerometerZ: Float,
    val gyroscopeX: Float,
    val gyroscopeY: Float,
    val gyroscopeZ: Float
) {
    /**
     * バイナリ形式に変換（32バイト）
     */
    fun toBytes(): ByteArray {
        val buffer = ByteBuffer.allocate(SensorConstants.BYTES_PER_SAMPLE)
            .order(ByteOrder.LITTLE_ENDIAN)
        
        buffer.putLong(timestamp)
        buffer.putFloat(accelerometerX)
        buffer.putFloat(accelerometerY)
        buffer.putFloat(accelerometerZ)
        buffer.putFloat(gyroscopeX)
        buffer.putFloat(gyroscopeY)
        buffer.putFloat(gyroscopeZ)
        // 4バイトのパディング
        buffer.putInt(0)
        
        return buffer.array()
    }
}

/**
 * セッション情報
 */
data class SwimSession(
    val sessionId: String,
    val startTime: Long,
    var endTime: Long? = null,
    val poolLengthM: Int = 25,
    var sampleCount: Int = 0
)

// ========================================
// Ring Buffer
// ========================================

/**
 * スレッドセーフなリングバッファ
 */
class RingBuffer<T>(private val capacity: Int) {
    private val buffer = ConcurrentLinkedQueue<T>()
    
    val count: Int get() = buffer.size
    
    fun write(element: T) {
        if (buffer.size >= capacity) {
            buffer.poll()
        }
        buffer.offer(element)
    }
    
    fun readAll(): List<T> {
        val result = buffer.toList()
        buffer.clear()
        return result
    }
    
    fun clear() {
        buffer.clear()
    }
}

// ========================================
// Sensor Manager
// ========================================

/**
 * センサーデータ収集マネージャー
 */
class AquaMetricSensorManager(private val context: Context) : SensorEventListener {
    
    private val sensorManager: SensorManager = 
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    
    private val accelerometer: Sensor? = 
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    
    private val gyroscope: Sensor? = 
        sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    
    private val buffer = RingBuffer<SensorSample>(SensorConstants.BUFFER_SIZE)
    
    private var isRecording = false
    private var sessionStartTime: Long = 0
    
    // 一時的なセンサー値の保持
    private var lastAccel = floatArrayOf(0f, 0f, 0f)
    private var lastGyro = floatArrayOf(0f, 0f, 0f)
    private var lastAccelTime: Long = 0
    private var lastGyroTime: Long = 0
    
    // バッチ通知用のFlow
    private val _batchFlow = MutableSharedFlow<List<SensorSample>>()
    val batchFlow: SharedFlow<List<SensorSample>> = _batchFlow
    
    /**
     * センサー記録を開始
     */
    fun startRecording(): Boolean {
        if (accelerometer == null || gyroscope == null) {
            android.util.Log.e("SensorManager", "Required sensors not available")
            return false
        }
        
        if (isRecording) return true
        
        sessionStartTime = System.nanoTime()
        
        // 100Hz でセンサー登録
        sensorManager.registerListener(
            this,
            accelerometer,
            SensorConstants.SAMPLING_PERIOD_US
        )
        sensorManager.registerListener(
            this,
            gyroscope,
            SensorConstants.SAMPLING_PERIOD_US
        )
        
        isRecording = true
        android.util.Log.i("SensorManager", "Started recording at 100Hz")
        return true
    }
    
    /**
     * センサー記録を停止
     */
    fun stopRecording(): List<SensorSample> {
        if (!isRecording) return emptyList()
        
        sensorManager.unregisterListener(this)
        isRecording = false
        
        val remainingSamples = buffer.readAll()
        buffer.clear()
        
        android.util.Log.i("SensorManager", "Stopped recording. Samples: ${remainingSamples.size}")
        return remainingSamples
    }
    
    // ========================================
    // SensorEventListener
    // ========================================
    
    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                lastAccel = event.values.clone()
                lastAccelTime = event.timestamp
            }
            Sensor.TYPE_GYROSCOPE -> {
                lastGyro = event.values.clone()
                lastGyroTime = event.timestamp
            }
        }
        
        // 両方のセンサーデータが揃ったらサンプルを作成
        if (lastAccelTime > 0 && lastGyroTime > 0 &&
            kotlin.math.abs(lastAccelTime - lastGyroTime) < 5_000_000) { // 5ms以内
            
            val sample = SensorSample(
                timestamp = System.nanoTime(),
                accelerometerX = lastAccel[0],
                accelerometerY = lastAccel[1],
                accelerometerZ = lastAccel[2],
                gyroscopeX = lastGyro[0],
                gyroscopeY = lastGyro[1],
                gyroscopeZ = lastGyro[2]
            )
            
            buffer.write(sample)
            
            // バッファが満杯になったら通知
            if (buffer.count >= SensorConstants.BUFFER_SIZE) {
                val batch = buffer.readAll()
                // Coroutine scope で emit
                kotlinx.coroutines.runBlocking {
                    _batchFlow.emit(batch)
                }
            }
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 精度変更は記録のみ
        android.util.Log.d("SensorManager", "Accuracy changed: $sensor -> $accuracy")
    }
}

// ========================================
// Storage Manager
// ========================================

/**
 * ローカルストレージへのセンサーデータ保存
 */
class StorageManager(private val context: Context) {
    
    private val sessionsDir: File by lazy {
        File(context.filesDir, "sessions").also { it.mkdirs() }
    }
    
    /**
     * セッションデータをファイルに保存
     */
    fun saveSession(sessionId: String, samples: List<SensorSample>): File {
        val file = File(sessionsDir, "$sessionId.bin")
        
        file.outputStream().buffered().use { output ->
            samples.forEach { sample ->
                output.write(sample.toBytes())
            }
        }
        
        android.util.Log.i("StorageManager", "Saved ${samples.size} samples to ${file.name}")
        return file
    }
    
    /**
     * 未同期セッションの一覧を取得
     */
    fun getPendingSessions(): List<File> {
        return sessionsDir.listFiles()
            ?.filter { it.extension == "bin" }
            ?: emptyList()
    }
    
    /**
     * セッションファイルを削除（同期完了後）
     */
    fun deleteSession(sessionId: String): Boolean {
        val file = File(sessionsDir, "$sessionId.bin")
        return file.delete()
    }
}

// ========================================
// Session Manager
// ========================================

/**
 * 水泳セッションの管理
 */
class SessionManager(context: Context) {
    
    private val sensorManager = AquaMetricSensorManager(context)
    private val storageManager = StorageManager(context)
    
    private var currentSession: SwimSession? = null
    private val currentSessionSamples = mutableListOf<SensorSample>()
    
    val isSessionActive: Boolean get() = currentSession != null
    
    /**
     * セッション開始
     */
    fun startSession(poolLengthM: Int = 25): String {
        val sessionId = UUID.randomUUID().toString()
        currentSession = SwimSession(
            sessionId = sessionId,
            startTime = System.currentTimeMillis(),
            poolLengthM = poolLengthM
        )
        currentSessionSamples.clear()
        
        val started = sensorManager.startRecording()
        android.util.Log.i("SessionManager", "Session $sessionId started: $started")
        
        return sessionId
    }
    
    /**
     * セッション終了
     */
    fun endSession(): String? {
        val session = currentSession ?: return null
        
        // 残りのサンプルを取得
        val remainingSamples = sensorManager.stopRecording()
        currentSessionSamples.addAll(remainingSamples)
        
        // 終了時刻を記録
        session.endTime = System.currentTimeMillis()
        session.sampleCount = currentSessionSamples.size
        
        // ファイルに保存
        storageManager.saveSession(session.sessionId, currentSessionSamples)
        
        val endedSessionId = session.sessionId
        currentSession = null
        currentSessionSamples.clear()
        
        return endedSessionId
    }
    
    /**
     * 経過時間（秒）を取得
     */
    val elapsedTimeSeconds: Long
        get() {
            val session = currentSession ?: return 0
            return (System.currentTimeMillis() - session.startTime) / 1000
        }
    
    /**
     * 現在のサンプル数を取得
     */
    val sampleCount: Int
        get() = currentSessionSamples.size
}
