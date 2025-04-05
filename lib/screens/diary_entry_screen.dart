import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryEntryScreen extends StatefulWidget {
  final String? entryId;

  const DiaryEntryScreen({super.key, this.entryId});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  final DiaryService _diaryService = DiaryService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isEditMode = false;
  String _selectedMood = 'Happy';
  DiaryEntry? _existingEntry;

  final List<Map<String, dynamic>> _moodOptions = [
    {'emoji': '😊', 'label': 'Happy', 'color': Colors.yellow},
    {'emoji': '😌', 'label': 'Calm', 'color': Colors.blue.shade300},
    {'emoji': '😐', 'label': 'Neutral', 'color': Colors.grey.shade400},
    {'emoji': '😔', 'label': 'Sad', 'color': Colors.indigo.shade300},
    {'emoji': '😡', 'label': 'Angry', 'color': Colors.red.shade400},
    {'emoji': '😰', 'label': 'Anxious', 'color': Colors.purple.shade300},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _isEditMode = true;
      _loadEntry();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    setState(() {
      _isLoading = true;
    });

    final entry = await _diaryService.getDiaryEntry(widget.entryId!);

    if (mounted) {
      if (entry != null) {
        setState(() {
          _existingEntry = entry;
          _titleController.text = entry.title;
          _contentController.text = entry.content;
          _selectedMood = entry.mood;
          _isLoading = false;
        });
      } else {
        // Entry not found, go back
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some content'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = false;
    if (_isEditMode && _existingEntry != null) {
      // Update existing entry
      final updatedEntry = DiaryEntry(
        id: _existingEntry!.id,
        title: title,
        content: content,
        mood: _selectedMood,
        date: _existingEntry!.date,
        userId: _existingEntry!.userId,
      );
      success = await _diaryService.updateDiaryEntry(updatedEntry);
    } else {
      // Create new entry
      final newEntry = await _diaryService.addDiaryEntry(
        title,
        content,
        _selectedMood,
      );
      success = newEntry != null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save diary entry. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry() async {
    if (!_isEditMode || _existingEntry == null) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Entry', style: GoogleFonts.fredoka()),
            content: Text(
              'Are you sure you want to delete this diary entry? This action cannot be undone.',
              style: GoogleFonts.fredoka(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.fredoka()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  'Delete',
                  style: GoogleFonts.fredoka(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    final success = await _diaryService.deleteDiaryEntry(_existingEntry!.id);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete diary entry. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Diary Entry' : 'New Diary Entry',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF6A9BF5)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteEntry,
            ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF6A9BF5)),
            onPressed: _saveEntry,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling today?',
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          _moodOptions.map((mood) {
                            final isSelected = _selectedMood == mood['label'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMood = mood['label'] as String;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? (mood['color'] as Color)
                                              .withOpacity(0.3)
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? mood['color'] as Color
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      mood['emoji'] as String,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      mood['label'] as String,
                                      style: GoogleFonts.fredoka(
                                        fontSize: 14,
                                        color:
                                            isSelected
                                                ? Colors.black
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: GoogleFonts.fredoka(),
                        hintText: 'Enter a title for your diary entry',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6A9BF5),
                            width: 2,
                          ),
                        ),
                      ),
                      style: GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: 'Write about your day...',
                        labelStyle: GoogleFonts.fredoka(),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6A9BF5),
                            width: 2,
                          ),
                        ),
                      ),
                      style: GoogleFonts.fredoka(fontSize: 14),
                      maxLines: 15,
                      textInputAction: TextInputAction.newline,
                    ),
                  ],
                ),
              ),
    );
  }
}
