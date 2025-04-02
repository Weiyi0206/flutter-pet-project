import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HappinessMeter extends StatelessWidget {
  final int happiness;
  final String status;

  const HappinessMeter({
    Key? key,
    required this.happiness,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Status: $status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(),
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: happiness / 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor().withOpacity(0.7),
                        _getStatusColor(),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ).animate().custom(
                    duration: 500.ms,
                    builder: (context, value, child) => FractionallySizedBox(
                      widthFactor: value * happiness / 100,
                      child: child,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$happiness%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'Happy':
        return Colors.green;
      case 'Sad':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
} 