import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:ar_makeup_app/features/ar/presentation/camera_screen.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/features/studio/domain/studio_look.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:ar_makeup_app/features/vip/data/premium_content.dart';
import 'package:ar_makeup_app/features/vip/presentation/vip_paywall_screen.dart';

class StepByStepScreen extends StatefulWidget {
  final String lookId;

  const StepByStepScreen({super.key, required this.lookId});

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Los streams se crean una vez: creados en build, cada setState (por ejemplo
  // el swipe de paso) se resuscribía, pasaba por "waiting" y reemplazaba la
  // pantalla por un spinner, destruyendo el reproductor de video.
  late final Stream<DocumentSnapshot> _lookStream =
      FirebaseFirestore.instance.collection('looks').doc(widget.lookId).snapshots();
  late final Stream<DocumentSnapshot>? _userStream = _userSnapshots();

  /// Para pausar el video antes de abrir la cámara AR.
  final GlobalKey<_TutorialVideoSectionState> _videoKey = GlobalKey();

  static Stream<DocumentSnapshot>? _userSnapshots() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? null : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<DocumentSnapshot>(
      stream: _lookStream,
      builder: (context, lookSnapshot) {
        if (lookSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));
        }

        if (lookSnapshot.hasError) {
          return Scaffold(body: Center(child: Text(l10n.errorWithDetails('${lookSnapshot.error}'))));
        }

        final data = lookSnapshot.data?.data() as Map<String, dynamic>?;
        final lookName = data?['name'] as String? ?? l10n.stepByStepTitle;
        // Solo looks sin migrar: el video nuevo vive en premium/content.
        final legacyVideoUrl = data?['video_url'] as String?;
        final recipe = data == null ? null : lookRecipe(data);
        final rawSteps = data?['steps'];
        final steps = rawSteps is List
            ? rawSteps.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList()
            : <Map<String, dynamic>>[];

        return StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, userSnapshot) {
            final isPremium = isPremiumUser(userSnapshot.data?.data() as Map<String, dynamic>?);

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
                  // Con receta del Studio: el espejo abre con este look puesto.
                  IconButton(
                    icon: Icon(recipe == null ? Icons.camera_front_outlined : Icons.auto_awesome, color: const Color(0xFF1A1A1A)),
                    tooltip: recipe == null ? l10n.mirror : l10n.tryOnAr,
                    onPressed: () {
                      // El video no compite con la cámara y el motor AR.
                      _videoKey.currentState?.pause();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (camera) => CameraScreen(
                          initialLook: recipe == null
                              ? null
                              : TestFilterOption(id: 'look-${widget.lookId}', label: recipe.name, recipe: recipe),
                          // Ya venimos del tutorial: "Ver tutorial" vuelve atrás.
                          onOpenTutorial: recipe == null ? null : () => Navigator.of(camera).pop(),
                        ),
                      ));
                    },
                  ),
                ],
              ),
              body: _buildContent(steps, legacyVideoUrl, isPremium),
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
          AppLocalizations.of(context)!.stepsEmpty,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> steps, String? legacyVideoUrl, bool isPremium) {
    return Column(
      children: [
        // El video/paywall VIP siempre se muestra, tenga o no video este look.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: TutorialVideoSection(
            key: _videoKey,
            lookId: widget.lookId,
            legacyVideoUrl: legacyVideoUrl,
            isPremium: isPremium,
          ),
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
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
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
/// El botón "Hazte VIP" abre la pasarela de pago real (VipPaywallScreen), que
/// necesita una cuenta de RevenueCat con al menos un producto y sus keys por
/// --dart-define-from-file=env/revenuecat.json (lib/features/vip/data/revenue_cat_config.dart).
///
/// La URL se pide solo si el usuario es VIP: vive en looks/{id}/premium/content,
/// que las reglas dejan leer solo a VIP vigentes y admins (PremiumContent).
class TutorialVideoSection extends StatefulWidget {
  final String lookId;

  /// video_url del documento del look: solo en looks sin migrar.
  final String? legacyVideoUrl;
  final bool isPremium;

  const TutorialVideoSection({
    super.key,
    required this.lookId,
    required this.legacyVideoUrl,
    required this.isPremium,
  });

  @override
  State<TutorialVideoSection> createState() => _TutorialVideoSectionState();
}

class _TutorialVideoSectionState extends State<TutorialVideoSection> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _videoUrl;
  bool _resolving = false;
  // Descarta respuestas viejas si cambia el look o el estado VIP en el medio.
  int _request = 0;

  bool get _hasVideo => _videoUrl != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isPremium) _resolveVideo();
  }

  /// En segundo plano el video se pausa (no sigue con audio y decodificador).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  /// Pausa si está reproduciendo (al abrir la cámara AR, al salir de la app).
  void pause() {
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) unawaited(controller.pause());
  }

  /// Redibuja con los cambios del reproductor (fin del video: vuelve el play).
  void _onVideoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TutorialVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.lookId != widget.lookId || oldWidget.legacyVideoUrl != widget.legacyVideoUrl;
    if (widget.isPremium && (!oldWidget.isPremium || changed)) {
      _resolveVideo();
    } else if (!widget.isPremium && oldWidget.isPremium) {
      _request++;
      _disposeVideo();
    }
  }

  Future<void> _resolveVideo() async {
    final request = ++_request;
    _disposeVideo();
    setState(() => _resolving = true);
    String? premiumUrl;
    try {
      premiumUrl = await PremiumContent.videoUrl(widget.lookId);
    } catch (e) {
      // videoUrl ya atrapa los errores de Firestore; esto cubre el resto.
      debugPrint('Video del tutorial: $e');
    } finally {
      // Si este pedido sigue vigente, nunca queda el spinner trabado.
      if (mounted && request == _request) setState(() => _resolving = false);
    }
    if (!mounted || request != _request) return;
    final legacy = widget.legacyVideoUrl;
    final url = premiumUrl ?? (legacy != null && legacy.isNotEmpty ? legacy : null);
    setState(() => _videoUrl = url);
    if (url != null) _initializeVideo(url);
  }

  void _disposeVideo() {
    final controller = _controller;
    controller?.removeListener(_onVideoChanged);
    controller?.dispose();
    _controller = null;
    _videoUrl = null;
    _resolving = false;
  }

  void _initializeVideo(String url) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted || _controller != controller) return;
      controller.addListener(_onVideoChanged);
      setState(() {});
    }).catchError((Object e) {
      // Red o códec: "sin video" en lugar de un spinner eterno.
      debugPrint('Video del tutorial no se pudo abrir: $e');
      if (!mounted || _controller != controller) return;
      setState(_disposeVideo);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onVideoChanged);
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
    final showVideoPlayer = widget.isPremium && (_hasVideo || _resolving);

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        // Sin imagen de red de terceros (antes picsum.photos en cada apertura).
        gradient: showVideoPlayer
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2418), Color(0xFF1A1A1A), Color(0xFF3A2E14)],
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
        Text(AppLocalizations.of(context)!.tutorialNoVideoTitle, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(AppLocalizations.of(context)!.tutorialNoVideoBody, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }

    return GestureDetector(
      // El listener del controller redibuja cuando cambia el estado.
      onTap: () => controller.value.isPlaying ? controller.pause() : controller.play(),
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
        Text(AppLocalizations.of(context)!.tutorialVipTitle, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(AppLocalizations.of(context)!.tutorialVipBody, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _openVipPaywall,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: Text(AppLocalizations.of(context)!.becomeVip, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
