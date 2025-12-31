import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquametric_app/core/services/ble_service.dart';

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  bool _isScanning = false;
  bool _isSyncing = false;
  double _syncProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('デバイス同期'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            _buildDeviceSection(),
            const SizedBox(height: 24),
            _buildSyncSection(),
            const SizedBox(height: 24),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getStatusColor().withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusDescription(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ウェアラブルデバイス',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            if (_connectionState == BleConnectionState.connected) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.watch, color: Colors.blue),
                ),
                title: const Text('AquaMetric Watch'),
                subtitle: const Text('接続中'),
                trailing: TextButton(
                  onPressed: _disconnect,
                  child: const Text('切断'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'スキャン中...' : 'デバイスを検索'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    if (_connectionState != BleConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'データ同期',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            if (_isSyncing) ...[
              LinearProgressIndicator(value: _syncProgress),
              const SizedBox(height: 12),
              Text(
                '同期中... ${(_syncProgress * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('未同期のセッションデータがあります'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startSync,
                  icon: const Icon(Icons.sync),
                  label: const Text('今すぐ同期'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  '使い方',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(1, 'ウェアラブルデバイスのBluetoothをオンにする'),
            _buildInstructionStep(2, '「デバイスを検索」をタップ'),
            _buildInstructionStep(3, '表示されたデバイスを選択して接続'),
            _buildInstructionStep(4, '「今すぐ同期」でデータを転送'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return Icons.bluetooth_searching;
      case BleConnectionState.error:
        return Icons.bluetooth_disabled;
      default:
        return Icons.bluetooth;
    }
  }

  Color _getStatusColor() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return Colors.blue;
      case BleConnectionState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return '接続済み';
      case BleConnectionState.connecting:
        return '接続中...';
      case BleConnectionState.scanning:
        return 'スキャン中...';
      case BleConnectionState.error:
        return 'エラー';
      default:
        return '未接続';
    }
  }

  String _getStatusDescription() {
    switch (_connectionState) {
      case BleConnectionState.connected:
        return 'ウェアラブルデバイスと接続されています';
      case BleConnectionState.connecting:
        return 'デバイスに接続しています...';
      case BleConnectionState.scanning:
        return '周辺のデバイスを探しています...';
      case BleConnectionState.error:
        return 'Bluetoothの接続に問題があります';
      default:
        return 'デバイスを検索してください';
    }
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _connectionState = BleConnectionState.scanning;
    });

    // Simulate scanning
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isScanning = false;
        _connectionState = BleConnectionState.connected; // Simulated
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('デバイスに接続しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _disconnect() {
    setState(() {
      _connectionState = BleConnectionState.disconnected;
    });
  }

  void _startSync() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0;
    });

    // Simulate sync progress
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _syncProgress = i / 100;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('同期が完了しました！'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
