import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';

class StepByStepScreen extends StatefulWidget {
  final String lookId;

  const StepByStepScreen({super.key, required this.lookId});

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('looks').doc(widget.lookId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final lookName = data?['name'] as String? ?? l10n.stepByStepTitle;
        final rawSteps = data?['steps'];
        final steps = rawSteps is List
            ? rawSteps.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList()
            : <Map<String, dynamic>>[];

        return Scaffold(
          backgroundColor: const Color(0xFFFDF7F8),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lookName,
              style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: true,
          ),
          body: steps.isEmpty ? _buildEmptyState() : _buildSteps(steps),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Text(
          'Todavía no hay tutorial cargado para este look.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildSteps(List<Map<String, dynamic>> steps) {
    return Column(
      children: [
        // Indicador de pasos
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              steps.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? const Color(0xFFD4AF37) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),

        // Contenido deslizable
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final title = (step['title'] as String?) ?? '';
              final image = (step['image'] as String?) ?? '';
              final description = (step['description'] as String?) ?? '';

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (image.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            image,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 300,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),

                    Text(
                      '${AppLocalizations.of(context)!.stepLabel} ${index + 1}',
                      style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 12),
                    ),
                    const SizedBox(height: 10),

                    if (title.isNotEmpty) ...[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade700, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),

        // Botones de navegación inferior
        Padding(
          padding: const EdgeInsets.all(30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentPage == 0
                    ? null
                    : () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                child: Text(
                  AppLocalizations.of(context)!.backBtn,
                  style: GoogleFonts.inter(color: _currentPage == 0 ? Colors.grey.shade400 : Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_currentPage < steps.length - 1) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text(
                  _currentPage == steps.length - 1 ? AppLocalizations.of(context)!.finishBtn : AppLocalizations.of(context)!.nextStepBtn,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
