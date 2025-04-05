import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/practice_tip.dart';

class TipDetailScreen extends StatelessWidget {
  final PracticeTip tip;

  const TipDetailScreen({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          tip.title,
          style: GoogleFonts.fredoka(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6A9BF5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF6A9BF5),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tip.imageUrl.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    tip.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            color: const Color(0xFF6A9BF5),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              tip.description,
              style: GoogleFonts.fredoka(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (tip.place.isNotEmpty) ...[
              _buildInfoSection('Place', tip.place),
              const SizedBox(height: 16),
            ],
            _buildInfoSection('Benefit', tip.benefit),
            const SizedBox(height: 16),
            if (tip.steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Steps:',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6A9BF5),
                ),
              ),
              const SizedBox(height: 12),
              ...tip.steps.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6A9BF5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: GoogleFonts.fredoka(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            if (tip.articleUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri uri = Uri.parse(tip.articleUrl);
                    try {
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank',
                      )) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open article: ${tip.articleUrl}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A9BF5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.article_outlined),
                  label: Text('Read Article', style: GoogleFonts.fredoka()),
                ),
              ),
            ],
            if (tip.videoUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri uri = Uri.parse(tip.videoUrl);
                    try {
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank',
                      )) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not launch: ${tip.videoUrl}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A9BF5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text('Watch Tutorial', style: GoogleFonts.fredoka()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6A9BF5),
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.fredoka(fontSize: 16)),
        ],
      ),
    );
  }
}
