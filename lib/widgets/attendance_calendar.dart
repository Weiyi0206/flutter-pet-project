import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> markedDatesWithMoods;
  final Function(DateTime)? onDaySelected;
  final DateTime? selectedDate;

  const AttendanceCalendar({
    super.key,
    required this.markedDatesWithMoods,
    this.onDaySelected,
    this.selectedDate,
  });

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _resetToCurrentMonth() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: 8),
        _buildWeekdayHeader(context),
        _buildCalendarGrid(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            tooltip: 'Previous Month',
          ),
          GestureDetector(
            onTap: _resetToCurrentMonth,
            child: Text(
              DateFormat('MMMM yyyy').format(_currentMonth),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            tooltip: 'Next Month',
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children:
          weekdays.map((day) {
            return SizedBox(
              width: 30,
              child: Text(
                day,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
    );
  }

  // Helper method to find mood for a specific date
  String? _getMoodEmojiForDate(DateTime date) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    for (var markedDate in widget.markedDatesWithMoods) {
      final markedDateTime = markedDate['date'] as DateTime;
      if (DateFormat('yyyy-MM-dd').format(markedDateTime) == formattedDate) {
        return markedDate['moodEmoji'] as String?;
      }
    }
    return null;
  }

  // Check if date is marked
  bool _isDateMarked(DateTime date) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    for (var markedDate in widget.markedDatesWithMoods) {
      final markedDateTime = markedDate['date'] as DateTime;
      if (DateFormat('yyyy-MM-dd').format(markedDateTime) == formattedDate) {
        return true;
      }
    }
    return false;
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );

    // Get the correct day of week (0 = Sunday, 6 = Saturday)
    final firstWeekdayOfMonth = firstDayOfMonth.weekday % 7;

    // Create day cells
    final days = List<Widget>.generate(firstWeekdayOfMonth + daysInMonth, (
      index,
    ) {
      if (index < firstWeekdayOfMonth) {
        // Empty cells for days before the 1st of the month
        return const SizedBox(width: 36, height: 36);
      }

      final day = index - firstWeekdayOfMonth + 1;
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isMarked = _isDateMarked(date);
      final moodEmoji = _getMoodEmojiForDate(date);

      final isSelected =
          widget.selectedDate != null &&
          widget.selectedDate!.year == date.year &&
          widget.selectedDate!.month == date.month &&
          widget.selectedDate!.day == date.day;

      final now = DateTime.now();
      final isCurrentDay =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      final isFutureDate = date.isAfter(now);

      return GestureDetector(
        onTap:
            isFutureDate
                ? null
                : () {
                  if (widget.onDaySelected != null) {
                    widget.onDaySelected!(date);
                  }
                },
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? theme.colorScheme.primary
                    : isMarked
                    ? theme.colorScheme.tertiary.withOpacity(0.3)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border:
                isCurrentDay
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
          ),
          child:
              isMarked
                  ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Date number stays at the top
                      Positioned(
                        top: 2,
                        child: Text(
                          day.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isCurrentDay ? FontWeight.bold : null,
                            fontSize: 10, // Smaller to make room for the emoji
                          ),
                        ),
                      ),
                      // Show mood emoji below the date
                      if (moodEmoji != null)
                        Positioned(
                          bottom: 2,
                          child: Text(
                            moodEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  )
                  : Center(
                    child: Text(
                      day.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            isSelected
                                ? Colors.white
                                : isFutureDate
                                ? Colors.grey
                                : null,
                        fontWeight: isCurrentDay ? FontWeight.bold : null,
                      ),
                    ),
                  ),
        ),
      );
    });

    // Ensure we have complete rows of 7 days
    final int totalCells = days.length;
    final int remainder = totalCells % 7;
    if (remainder > 0) {
      // Add empty cells for the remaining days to complete the grid
      final int emptyEnd = 7 - remainder;
      for (int i = 0; i < emptyEnd; i++) {
        days.add(const SizedBox(width: 36, height: 36));
      }
    }

    // Arrange in rows of 7 days
    final rows = <Widget>[];
    for (var i = 0; i < days.length; i += 7) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < 7 && i + j < days.length; j++) {
        rowChildren.add(days[i + j]);
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: rowChildren,
        ),
      );
    }

    return Column(children: rows);
  }
}
