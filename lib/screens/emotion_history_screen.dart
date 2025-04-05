import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/emotion_service.dart';

class EmotionHistoryScreen extends StatefulWidget {
  const EmotionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<EmotionHistoryScreen> createState() => _EmotionHistoryScreenState();
}

class _EmotionHistoryScreenState extends State<EmotionHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final EmotionService _emotionService = EmotionService();
  
  List<EmotionData> _emotionHistory = [];
  bool _isLoading = true;
  String _timeRange = 'Week'; // 'Week', 'Month', 'Year'

  @override
  void initState() {
    super.initState();
    _loadEmotionHistory();
  }

  Future<void> _loadEmotionHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get date range based on selected time range
      int daysToLoad;
      switch (_timeRange) {
        case 'Week':
          daysToLoad = 7;
          break;
        case 'Month':
          daysToLoad = 30;
          break;
        case 'Year':
          daysToLoad = 365;
          break;
        default:
          daysToLoad = 7;
      }

      // Load emotion data using EmotionService
      final emotions = await _emotionService.getEmotions(days: daysToLoad);
      
      // Convert to EmotionData objects
      final emotionData = emotions.map((data) {
        return EmotionData(
          date: DateTime.parse('${data['date']} ${data['time']}'),
          emotion: data['emotion'],
        );
      }).toList();

      setState(() {
        _emotionHistory = emotionData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading emotion history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emotion History', style: GoogleFonts.fredoka()),
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time range selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Week', label: Text('Week')),
                      ButtonSegment(value: 'Month', label: Text('Month')),
                      ButtonSegment(value: 'Year', label: Text('Year')),
                    ],
                    selected: {_timeRange},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _timeRange = selection.first;
                      });
                      _loadEmotionHistory();
                    },
                  ),
                ),
                
                // Emotion chart
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildEmotionChart(),
                  ),
                ),
                
                // Emotion history list
                Expanded(
                  flex: 3,
                  child: _buildEmotionHistoryList(),
                ),
              ],
            ),
    );
  }

  Widget _buildEmotionChart() {
    if (_emotionHistory.isEmpty) {
      return Center(
        child: Text(
          'No emotion data available for this period.',
          style: GoogleFonts.fredoka(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Group emotions by date (simplified chart visualization)
    final Map<String, int> emotionCounts = {
      'Happy': 0,
      'Calm': 0,
      'Neutral': 0,
      'Sad': 0,
      'Angry': 0,
      'Anxious': 0,
    };

    for (final entry in _emotionHistory) {
      emotionCounts[entry.emotion] = (emotionCounts[entry.emotion] ?? 0) + 1;
    }

    // Create chart data
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emotion Summary',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emotionCounts.entries.map((entry) {
                  // Skip emotions with zero count
                  if (entry.value == 0) return const SizedBox();
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getEmotionEmoji(entry.key),
                        style: const TextStyle(fontSize: 30),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value.toString(),
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getEmotionColor(entry.key),
                        ),
                      ),
                      Text(
                        entry.key,
                        style: GoogleFonts.fredoka(fontSize: 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionHistoryList() {
    if (_emotionHistory.isEmpty) {
      return Center(
        child: Text(
          'No emotion data recorded yet.',
          style: GoogleFonts.fredoka(color: Colors.grey.shade600),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _emotionHistory.length,
        itemBuilder: (context, index) {
          final item = _emotionHistory[index];
          final dateStr = DateFormat('MMM d, yyyy').format(item.date);
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getEmotionColor(item.emotion).withOpacity(0.2),
              child: Text(
                _getEmotionEmoji(item.emotion),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            title: Text(
              item.emotion,
              style: GoogleFonts.fredoka(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              dateStr,
              style: GoogleFonts.fredoka(fontSize: 12),
            ),
            trailing: _buildEmotionIndicator(item.emotion),
          );
        },
      ),
    );
  }

  Widget _buildEmotionIndicator(String emotion) {
    final score = _getEmotionScore(emotion);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < score ? Icons.star : Icons.star_border,
            color: index < score ? _getEmotionColor(emotion) : Colors.grey.shade300,
            size: 16,
          );
        }),
      ],
    );
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

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😔';
      case 'angry':
        return '😡';
      case 'anxious':
        return '😰';
      default:
        return '😐'; // Neutral
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.yellow;
      case 'calm':
        return Colors.blue.shade300;
      case 'neutral':
        return Colors.grey.shade400;
      case 'sad':
        return Colors.indigo.shade300;
      case 'angry':
        return Colors.red.shade400;
      case 'anxious':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade400; // Neutral
    }
  }
}

class EmotionData {
  final DateTime date;
  final String emotion;
  
  EmotionData({required this.date, required this.emotion});
} 