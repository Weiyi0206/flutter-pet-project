import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';

class PetInteractionsScreen extends StatefulWidget {
  final PetModel petModel;
  final Map<String, dynamic> petData;
  final Function(Map<String, dynamic>) onPetDataUpdate;

  const PetInteractionsScreen({
    Key? key,
    required this.petModel,
    required this.petData,
    required this.onPetDataUpdate,
  }) : super(key: key);

  @override
  State<PetInteractionsScreen> createState() => _PetInteractionsScreenState();
}

class _PetInteractionsScreenState extends State<PetInteractionsScreen> {
  late Map<String, dynamic> _petData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _petData = widget.petData;
  }

  void _updatePetData(Map<String, dynamic> updates) {
    setState(() {
      _petData = {..._petData, ...updates};
    });
    widget.onPetDataUpdate(_petData);
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required String interactionType,
    required int energyCost,
  }) {
    final canInteract = _canInteract(interactionType);
    final hasEnergy = _petData['energy'] >= energyCost;
    final isEnabled = canInteract && hasEnergy && !_petData['isSleeping'];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(isEnabled ? 0.2 : 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isEnabled ? color : Colors.grey,
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: isEnabled ? color : Colors.grey),
            onPressed: isEnabled ? onPressed : null,
            iconSize: 30,
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.fredoka(
            fontSize: 12,
            color: isEnabled ? Colors.black87 : Colors.grey,
          ),
        ),
        if (!isEnabled) ...[
          const SizedBox(height: 2),
          Text(
            !canInteract ? 'Cooldown' : !hasEnergy ? 'Low Energy' : 'Sleeping',
            style: GoogleFonts.fredoka(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  bool _canInteract(String interactionType) {
    final lastInteraction = _petData['lastInteractionTimes'][interactionType];
    if (lastInteraction == null) return true;
    
    final now = DateTime.now();
    final minutesSinceLastInteraction = now.difference(lastInteraction).inMinutes;
    final cooldown = _getCooldown(interactionType);
    return minutesSinceLastInteraction >= cooldown;
  }

  int _getCooldown(String interactionType) {
    switch (interactionType) {
      case 'pet':
        return 15; // Reduced cooldown for petting - encourages more affection
      case 'feed':
        return 45; // More realistic feeding cooldown
      case 'play':
        return 30; // Slightly reduced play cooldown
      case 'groom':
        return 90; // Reduced grooming cooldown
      default:
        return 0;
    }
  }

  Widget _buildStatusBar(String label, int value, int maxValue, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.fredoka(fontSize: 12, color: Colors.black87),
                  ),
                  Text(
                    '$value/$maxValue',
                    style: GoogleFonts.fredoka(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: value / maxValue,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _performInteraction(String interactionType) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      switch (interactionType) {
        case 'pet':
          await widget.petModel.petPet();
          break;
        case 'feed':
          await widget.petModel.feedPet();
          break;
        case 'play':
          await widget.petModel.playWithPet();
          break;
        case 'groom':
          await widget.petModel.groomPet();
          break;
      }
      
      // Load updated pet data
      final updatedData = await widget.petModel.loadPetData();
      _updatePetData(updatedData);
      
      // Check for achievements
      await widget.petModel.checkForNewAchievements(updatedData);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pet Care',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.purple.shade50, Colors.blue.shade50],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Pet mood and status
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getMoodColor(_petData['mood']).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getMoodIcon(_petData['mood']),
                                      color: _getMoodColor(_petData['mood']),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Mood: ${_petData['mood']}',
                                      style: GoogleFonts.fredoka(
                                        fontSize: 14,
                                        color: _getMoodColor(_petData['mood']),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Level ${_petData['level']}',
                                style: GoogleFonts.fredoka(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatusBar(
                            'Energy',
                            _petData['energy'],
                            _petData['maxEnergy'],
                            Colors.blue,
                            Icons.bolt,
                          ),
                          const SizedBox(height: 8),
                          _buildStatusBar(
                            'Hunger',
                            _petData['hunger'],
                            100,
                            Colors.orange,
                            Icons.restaurant,
                          ),
                          const SizedBox(height: 8),
                          _buildStatusBar(
                            'Affection',
                            _petData['affection'],
                            100,
                            Colors.pink,
                            Icons.favorite,
                          ),
                          const SizedBox(height: 8),
                          _buildStatusBar(
                            'Hygiene',
                            _petData['hygiene'],
                            100,
                            Colors.green,
                            Icons.shower,
                          ),
                          const SizedBox(height: 8),
                          _buildStatusBar(
                            'Experience',
                            _petData['experience'],
                            100,
                            Colors.amber,
                            Icons.star,
                          ),
                        ],
                      ),
                    ),

                    // Interaction buttons
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        padding: const EdgeInsets.all(16),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildInteractionButton(
                            icon: Icons.pets,
                            label: 'Pet',
                            onPressed: () => _performInteraction('pet'),
                            color: Colors.pink,
                            interactionType: 'pet',
                            energyCost: 5, // Lower energy cost for petting
                          ),
                          _buildInteractionButton(
                            icon: Icons.restaurant,
                            label: 'Feed',
                            onPressed: () => _performInteraction('feed'),
                            color: Colors.orange,
                            interactionType: 'feed',
                            energyCost: 5, // Lower energy cost for feeding
                          ),
                          _buildInteractionButton(
                            icon: Icons.sports_esports,
                            label: 'Play',
                            onPressed: () => _performInteraction('play'),
                            color: Colors.blue,
                            interactionType: 'play',
                            energyCost: 20, // Playing takes energy
                          ),
                          _buildInteractionButton(
                            icon: Icons.cleaning_services,
                            label: 'Groom',
                            onPressed: () => _performInteraction('groom'),
                            color: Colors.green,
                            interactionType: 'groom',
                            energyCost: 10, // Grooming takes some energy
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Ecstatic':
        return Colors.amber;
      case 'Happy':
        return Colors.green;
      case 'Content':
        return Colors.blue;
      case 'Neutral':
        return Colors.grey;
      case 'Sad':
        return Colors.indigo;
      case 'Depressed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Ecstatic':
        return Icons.sentiment_very_satisfied;
      case 'Happy':
        return Icons.sentiment_satisfied;
      case 'Content':
        return Icons.sentiment_satisfied_alt;
      case 'Neutral':
        return Icons.sentiment_neutral;
      case 'Sad':
        return Icons.sentiment_dissatisfied;
      case 'Depressed':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }
}
 