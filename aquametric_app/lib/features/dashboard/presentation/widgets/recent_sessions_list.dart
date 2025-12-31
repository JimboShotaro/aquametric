import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquametric_app/core/models/swim_session.dart';

class RecentSessionsList extends ConsumerWidget {
  const RecentSessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual data from provider
    final mockSessions = _generateMockSessions();

    if (mockSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.pool_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'セッションがありません',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ウェアラブルデバイスと同期して\n水泳データを記録しましょう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: mockSessions.take(3).map((session) {
        return _SessionCard(session: session);
      }).toList(),
    );
  }

  List<SwimSession> _generateMockSessions() {
    return [
      SwimSession(
        id: '1',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        poolLength: 25,
        totalDistance: 1500,
        totalDuration: const Duration(minutes: 45),
        avgSwolf: 42,
        status: 'completed',
        laps: [
          const SwimLap(
            lapNumber: 1,
            strokeType: StrokeType.freestyle,
            duration: Duration(seconds: 35),
            strokeCount: 18,
            swolf: 53,
            pacePerHundred: 140,
          ),
        ],
      ),
      SwimSession(
        id: '2',
        startTime: DateTime.now().subtract(const Duration(days: 3)),
        poolLength: 25,
        totalDistance: 2000,
        totalDuration: const Duration(hours: 1, minutes: 5),
        avgSwolf: 38,
        status: 'completed',
        laps: [],
      ),
      SwimSession(
        id: '3',
        startTime: DateTime.now().subtract(const Duration(days: 5)),
        poolLength: 50,
        totalDistance: 1000,
        totalDuration: const Duration(minutes: 30),
        avgSwolf: 45,
        status: 'completed',
        laps: [],
      ),
    ];
  }
}

class _SessionCard extends StatelessWidget {
  final SwimSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to session detail
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pool,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.totalDistance}m • ${session.poolLength}mプール',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDuration(session.totalDuration),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getSwolfColor(session.avgSwolf),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SWOLF ${session.avgSwolf}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '昨日';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours時間${minutes}分';
    }
    return '$minutes分';
  }

  Color _getSwolfColor(int swolf) {
    if (swolf < 35) return Colors.green;
    if (swolf < 45) return Colors.blue;
    if (swolf < 55) return Colors.orange;
    return Colors.red;
  }
}
