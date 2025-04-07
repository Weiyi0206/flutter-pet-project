import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';

class PetProgressionScreen extends StatefulWidget {
  final PetModel petModel;
  final Map<String, dynamic> petData;
  final Function(Map<String, dynamic>) onPetDataUpdate;

  const PetProgressionScreen({
    Key? key,
    required this.petModel,
    required this.petData,
    required this.onPetDataUpdate,
  }) : super(key: key);

  @override
  State<PetProgressionScreen> createState() => _PetProgressionScreenState();
}

class _PetProgressionScreenState extends State<PetProgressionScreen> {
  late Map<String, dynamic> _petData;

  @override
  void initState() {
    super.initState();
    _petData = widget.petData;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.fredoka(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrickList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learned Tricks',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _petData['learnedTricks'].map<Widget>((trick) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      trick,
                      style: GoogleFonts.fredoka(fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements',
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _petData['achievements']?.length ?? 0,
            itemBuilder: (context, index) {
              final achievement = _petData['achievements'][index];
              return ListTile(
                leading: Icon(
                  achievement['icon'],
                  color: achievement['color'],
                ),
                title: Text(
                  achievement['title'],
                  style: GoogleFonts.fredoka(),
                ),
                subtitle: Text(
                  achievement['date'],
                  style: GoogleFonts.fredoka(fontSize: 12),
                ),
                trailing: Text(
                  '+${achievement['points']}',
                  style: GoogleFonts.fredoka(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pet Progression',
          style: GoogleFonts.fredoka(),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade50, Colors.blue.shade50],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildStatCard(
                      'Level',
                      '${_petData['level']}',
                      Icons.star,
                      Colors.amber,
                    ),
                    _buildStatCard(
                      'Experience',
                      '${_petData['experience']}/100',
                      Icons.auto_awesome,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Energy',
                      '${_petData['energy']}/${_petData['maxEnergy']}',
                      Icons.energy_savings_leaf,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Tricks',
                      '${_petData['learnedTricks'].length}/5',
                      Icons.pets,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tricks List
                _buildTrickList(),
                const SizedBox(height: 16),
                // Achievements List
                _buildAchievementList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 