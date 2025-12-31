import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock data - TODO: Replace with actual data from provider
  final Map<DateTime, int> _activityData = {};

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  void _generateMockData() {
    final now = DateTime.now();
    // Generate some mock activity data for the past month
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      // Random activity level 0-4
      if (i % 2 == 0 || i % 3 == 0) {
        _activityData[normalizedDate] = (i % 5);
      }
    }
  }

  int _getActivityLevel(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _activityData[normalizedDate] ?? 0;
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 0:
        return Colors.grey[200]!;
      case 1:
        return const Color(0xFFBBF7D0);
      case 2:
        return const Color(0xFF86EFAC);
      case 3:
        return const Color(0xFF4ADE80);
      case 4:
        return const Color(0xFF16A34A);
      default:
        return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 30)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _showDayDetails(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Color(0xFF0077B6),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF00B4D8),
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final level = _getActivityLevel(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getColorForLevel(level),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: level > 2 ? Colors.white : Colors.black87,
                          fontWeight: level > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('少ない', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        for (int i = 0; i <= 4; i++) ...[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _getColorForLevel(i),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const Text('多い', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showDayDetails(DateTime day) {
    final level = _getActivityLevel(day);
    if (level > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${day.month}/${day.day}: レベル$level のトレーニング',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
