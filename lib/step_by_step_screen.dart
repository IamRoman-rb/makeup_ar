import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'camera_screen.dart';
import 'l10n/app_localizations.dart';
import 'vip/vip_paywall_screen.dart';

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
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('looks').doc(widget.lookId).snapshots(),
      builder: (context, lookSnapshot) {
        if (lookSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));
        }

        if (lookSnapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${lookSnapshot.error}')));
        }

        final data = lookSnapshot.data?.data() as Map<String, dynamic>?;
        final lookName = data?['name'] as String? ?? l10n.stepByStepTitle;
        final videoUrl = data?['video_url'] as String?;
        final rawSteps = data?['steps'];
        final steps = rawSteps is List
            ? rawSteps.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList()
            : <Map<String, dynamic>>[];

        return StreamBuilder<DocumentSnapshot>(
          stream: currentUser == null ? null : FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
          builder: (context, userSnapshot) {
            final isPremium = (userSnapshot.data?.data() as Map<String, dynamic>?)?['is_premium'] == true;

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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.camera_front_outlined, color: Color(0xFF1A1A1A)),
                    tooltip: l10n.mirror,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                  ),
                ],
              ),
              body: _buildContent(steps, videoUrl, isPremium),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyStepsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Text(
          'Todavía no hay pasos cargados para este look.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> steps, String? videoUrl, bool isPremium) {
    return Column(
      children: [
        // El video/paywall VIP siempre se muestra, tenga o no video este look.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: TutorialVideoSection(videoUrl: videoUrl, isPremium: isPremium),
        ),

        if (steps.isEmpty) Expanded(child: _buildEmptyStepsState()),

        if (steps.isNotEmpty) ...[
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
      ],
    );
  }
}

/// Sección de video VIP del tutorial. El botón para hacerse VIP se muestra
/// siempre que el usuario no sea VIP, tenga o no video cargado este look en
/// particular.
///
/// TODO: el botón "Hazte VIP" ya abre la pasarela de pago real
/// (VipPaywallScreen), pero esta necesita que se configure una cuenta de
/// RevenueCat con al menos un producto — ver lib/vip/revenue_cat_keys.dart.
class TutorialVideoSection extends StatefulWidget {
  final String? videoUrl;
  final bool isPremium;

  const TutorialVideoSection({super.key, required this.videoUrl, required this.isPremium});

  @override
  State<TutorialVideoSection> createState() => _TutorialVideoSectionState();
}

class _TutorialVideoSectionState extends State<TutorialVideoSection> {
  VideoPlayerController? _controller;

  bool get _hasVideo => widget.videoUrl != null && widget.videoUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.isPremium && _hasVideo) _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant TutorialVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium && _hasVideo && (!oldWidget.isPremium || oldWidget.videoUrl != widget.videoUrl)) {
      _controller?.dispose();
      _controller = null;
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
    _controller = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openVipPaywall() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VipPaywallScreen()));
    // El estado de is_premium se refresca solo: viene de un StreamBuilder
    // sobre el documento del usuario en el screen padre.
  }

  @override
  Widget build(BuildContext context) {
    final showVideoPlayer = widget.isPremium && _hasVideo;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        image: showVideoPlayer
            ? null
            : DecorationImage(
          image: const NetworkImage('https://picsum.photos/800/400?blur=10'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: showVideoPlayer
          ? _buildVideoPlayer()
          : widget.isPremium
              ? _buildNoVideoForThisLook()
              : _buildPremiumPaywall(),
    );
  }

  Widget _buildNoVideoForThisLook() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_off_outlined, color: Color(0xFFD4AF37), size: 35),
        const SizedBox(height: 10),
        Text('Sin video para este look', style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('Todavía no cargamos un video para este tutorial.', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }

    return GestureDetector(
      onTap: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)),
          ),
          if (!controller.value.isPlaying) const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37), size: 60),
        ],
      ),
    );
  }

  Widget _buildPremiumPaywall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, color: Color(0xFFD4AF37), size: 35),
        const SizedBox(height: 10),
        Text('Tutorial VIP', style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('Desbloquea los secretos de este look.', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _openVipPaywall,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: Text('Hazte VIP', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
