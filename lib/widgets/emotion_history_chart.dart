import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class EmotionHistoryChart extends StatelessWidget {
  final List<EmotionRecord> emotionHistory;
  final int daysToShow;

  const EmotionHistoryChart({
    Key? key,
    required this.emotionHistory,
    this.daysToShow = 7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort history by date
    final sortedHistory = List<EmotionRecord>.from(emotionHistory)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Get the data within date range
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - daysToShow);
    
    final filteredHistory = sortedHistory.where(
      (record) => record.date.isAfter(startDate) || record.date.isAtSameMomentAs(startDate)
    ).toList();
    
    // Get emotion scores for the chart
    final emotionScores = _processEmotionScores(filteredHistory, startDate, now);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Your Mood History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final date = startDate.add(Duration(days: value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        String emotion = '';
                        switch (value.toInt()) {
                          case 1:
                            emotion = 'Sad';
                            break;
                          case 2:
                            emotion = 'Anxious';
                            break;
                          case 3:
                            emotion = 'Neutral';
                            break;
                          case 4:
                            emotion = 'Calm';
                            break;
                          case 5:
                            emotion = 'Happy';
                            break;
                        }
                        return Text(
                          emotion,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                      reservedSize: 50,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d), width: 1),
                ),
                minX: 0,
                maxX: daysToShow.toDouble() - 1,
                minY: 1,
                maxY: 5,
                lineBarsData: [
                  LineChartBarData(
                    spots: emotionScores,
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: _getDotColor(spot.y.toInt()),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildLegend(),
        ),
      ],
    );
  }

  List<FlSpot> _processEmotionScores(
    List<EmotionRecord> history, 
    DateTime startDate, 
    DateTime endDate
  ) {
    // Create a map of days and their corresponding emotion scores
    final Map<int, double> dayScores = {};
    
    // Initialize with empty values
    for (int i = 0; i < daysToShow; i++) {
      dayScores[i] = 0; // Zero means no data for that day
    }
    
    // Fill in actual data
    for (final record in history) {
      final daysDifference = record.date.difference(startDate).inDays;
      if (daysDifference >= 0 && daysDifference < daysToShow) {
        // Convert emotion to score
        final score = _getEmotionScore(record.emotion);
        
        // If multiple entries for the same day, use the average
        if (dayScores[daysDifference]! > 0) {
          dayScores[daysDifference] = (dayScores[daysDifference]! + score) / 2;
        } else {
          dayScores[daysDifference] = score.toDouble();
        }
      }
    }
    
    // Convert to FlSpot list, only including days with data
    final spots = <FlSpot>[];
    dayScores.forEach((day, score) {
      if (score > 0) {
        spots.add(FlSpot(day.toDouble(), score));
      }
    });
    
    return spots;
  }
  
  int _getEmotionScore(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return 5;
      case 'calm':
        return 4;
      case 'neutral':
        return 3;
      case 'anxious':
        return 2;
      case 'sad':
      case 'angry':
        return 1;
      default:
        return 3; // Neutral as default
    }
  }
  
  Color _getDotColor(int score) {
    switch (score) {
      case 5:
        return Colors.yellow;
      case 4:
        return Colors.blue.shade300;
      case 3:
        return Colors.grey.shade400;
      case 2:
        return Colors.purple.shade300;
      case 1:
        return Colors.indigo.shade300;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _legendItem(Colors.yellow, 'Happy'),
        _legendItem(Colors.blue.shade300, 'Calm'),
        _legendItem(Colors.grey.shade400, 'Neutral'),
        _legendItem(Colors.purple.shade300, 'Anxious'),
        _legendItem(Colors.indigo.shade300, 'Sad'),
      ],
    );
  }
  
  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

class EmotionRecord {
  final DateTime date;
  final String emotion;
  
  EmotionRecord({
    required this.date,
    required this.emotion,
  });
} 