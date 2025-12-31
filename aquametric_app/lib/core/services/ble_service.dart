import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class SensorDataPacket {
  final DateTime timestamp;
  final double accX;
  final double accY;
  final double accZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  const SensorDataPacket({
    required this.timestamp,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });
}

class BleService {
  // AquaMetric custom service UUIDs
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String sensorDataCharUuid = '12345678-1234-1234-1234-123456789abd';
  static const String controlCharUuid = '12345678-1234-1234-1234-123456789abe';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _controlChar;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _sensorDataController = StreamController<List<SensorDataPacket>>.broadcast();
  Stream<List<SensorDataPacket>> get sensorDataStream => _sensorDataController.stream;

  final List<int> _dataBuffer = [];

  BleService() {
    _init();
  }

  Future<void> _init() async {
    // Check Bluetooth state
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        _connectionStateController.add(BleConnectionState.disconnected);
      }
    });
  }

  /// Scan for AquaMetric wearable devices
  Future<List<ScanResult>> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async {
    _connectionStateController.add(BleConnectionState.scanning);
    
    final results = <ScanResult>[];
    
    try {
      await FlutterBluePlus.startScan(timeout: timeout);

      FlutterBluePlus.scanResults.listen((scanResults) {
        results.clear();
        // Filter for AquaMetric devices
        results.addAll(scanResults.where((r) => 
          r.device.platformName.contains('AquaMetric') ||
          r.advertisementData.advName.contains('AquaMetric')
        ));
      });

      await Future.delayed(timeout);
      await FlutterBluePlus.stopScan();
      
      _connectionStateController.add(BleConnectionState.disconnected);
      return results;
    } catch (e) {
      _connectionStateController.add(BleConnectionState.error);
      rethrow;
    }
  }

  /// Connect to a specific device
  Future<void> connect(BluetoothDevice device) async {
    _connectionStateController.add(BleConnectionState.connecting);
    
    try {
      await device.connect();
      _connectedDevice = device;

      // Discover services (subscribeToServicesChanged defaults to false)
      final services = await device.discoverServices(subscribeToServicesChanged: false);
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == sensorDataCharUuid.toLowerCase()) {
              // Subscribe to notifications
              await char.setNotifyValue(true);
              char.onValueReceived.listen(_handleSensorData);
            } else if (char.uuid.toString().toLowerCase() == controlCharUuid.toLowerCase()) {
              _controlChar = char;
            }
          }
        }
      }

      _connectionStateController.add(BleConnectionState.connected);
    } catch (e) {
      _connectionStateController.add(BleConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _controlChar = null;
      _connectionStateController.add(BleConnectionState.disconnected);
    }
  }

  /// Request data sync from wearable
  Future<void> requestDataSync() async {
    if (_controlChar != null) {
      // Send sync command (0x01 = request data)
      await _controlChar!.write([0x01]);
    }
  }

  /// Handle incoming sensor data packets
  void _handleSensorData(List<int> data) {
    _dataBuffer.addAll(data);
    
    // Parse complete packets (32 bytes each: 8 timestamp + 6*4 floats)
    const packetSize = 32;
    
    while (_dataBuffer.length >= packetSize) {
      final packetBytes = _dataBuffer.sublist(0, packetSize);
      _dataBuffer.removeRange(0, packetSize);
      
      final packet = _parsePacket(Uint8List.fromList(packetBytes));
      if (packet != null) {
        _sensorDataController.add([packet]);
      }
    }
  }

  SensorDataPacket? _parsePacket(Uint8List bytes) {
    if (bytes.length < 32) return null;
    
    final byteData = ByteData.sublistView(bytes);
    
    try {
      final timestampMs = byteData.getInt64(0, Endian.little);
      final accX = byteData.getFloat32(8, Endian.little);
      final accY = byteData.getFloat32(12, Endian.little);
      final accZ = byteData.getFloat32(16, Endian.little);
      final gyroX = byteData.getFloat32(20, Endian.little);
      final gyroY = byteData.getFloat32(24, Endian.little);
      final gyroZ = byteData.getFloat32(28, Endian.little);

      return SensorDataPacket(
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
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

  /// Get all buffered data as bytes for upload
  Uint8List getBufferedDataAsBytes() {
    return Uint8List.fromList(_dataBuffer);
  }

  void dispose() {
    _connectionStateController.close();
    _sensorDataController.close();
  }
}
