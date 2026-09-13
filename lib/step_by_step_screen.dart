import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'l10n/app_localizations.dart';

class StepByStepScreen extends StatefulWidget {
  const StepByStepScreen({super.key});

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final List<Map<String, String>> steps = [
      {
        'productName': l10n.tutStep1Title,
        'image': 'https://images.unsplash.com/photo-1599305090598-fe179d501227?q=80&w=800&auto=format&fit=crop',
        'description': l10n.tutStep1Desc,
      },
      {
        'productName': l10n.tutStep2Title,
        'image': 'https://images.unsplash.com/photo-1629198688000-71f23e745b6e?q=80&w=800&auto=format&fit=crop',
        'description': l10n.tutStep2Desc,
      },
      {
        'productName': l10n.tutStep3Title,
        'image': 'https://images.unsplash.com/photo-1617897903246-719242758050?q=80&w=800&auto=format&fit=crop',
        'description': l10n.tutStep3Desc,
      }
    ];

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
          l10n.stepByStepTitle,
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
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
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                // 💡 Envolvemos en SingleChildScrollView para evitar desbordamientos
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Imagen del producto
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            step['image']!,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Etiqueta del paso
                      Text(
                        '${l10n.stepLabel} ${index + 1}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Nombre del producto
                      Text(
                        step['productName']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Descripción del procedimiento
                      Text(
                        step['description']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 💡 Sección de Video Premium Integrada
                      const TutorialVideoSection(),

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
                      : () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(
                    l10n.backBtn,
                    style: GoogleFonts.inter(
                      color: _currentPage == 0 ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context); // Vuelve a la cámara al terminar
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _currentPage == steps.length - 1 ? l10n.finishBtn : l10n.nextStepBtn,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class TutorialVideoSection extends StatefulWidget {
  const TutorialVideoSection({super.key});

  @override
  State<TutorialVideoSection> createState() => _TutorialVideoSectionState();
}

class _TutorialVideoSectionState extends State<TutorialVideoSection> {
  final bool _isPremium = false;

  void _triggerPurchaseFlow() {
    // Aquí irá: await Purchases.purchasePackage(package);
    debugPrint("Iniciando pasarela de pago nativa...");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        image: _isPremium
            ? null
            : DecorationImage(
          image: const NetworkImage('https://picsum.photos/800/400?blur=10'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken
          ),
        ),
      ),
      child: _isPremium ? _buildVideoPlayer() : _buildPremiumPaywall(),
    );
  }

  Widget _buildVideoPlayer() {
    return const Center(
      child: Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37), size: 60),
    );
  }

  Widget _buildPremiumPaywall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, color: Color(0xFFD4AF37), size: 35),
        const SizedBox(height: 10),
        Text(
          'Tutorial Exclusivo',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Desbloquea los secretos de este look.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _triggerPurchaseFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Text(
            'Mejorar a Premium',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}