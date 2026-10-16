import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:ar_makeup_app/features/ar/domain/i_makeup_renderer.dart';
import 'package:ar_makeup_app/features/ar/presentation/test_filter_view.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';
import 'package:ar_makeup_app/shared/widgets/shared_bottom_nav.dart';

/// Espejo: cámara frontal en vivo con el motor AR nativo (`TestFilterView`).
///
/// - Sin [initialLook] (barra de abajo): solo la cámara, sin maquillaje,
///   tracker ni modelos (`mirrorOnly`).
/// - Con [initialLook] (un look del catálogo o de "Mis looks"): ese look
///   puesto, sin los demás filtros; solo intensidad y comparar.
///
/// Si el motor no puede dibujar en este equipo (o `AR_RENDERER=painter`), queda
/// el espejo de respaldo con `CameraController`, sin maquillaje.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.initialLook, this.onOpenTutorial, this.renderer});

  final TestFilterOption? initialLook;

  /// Botón "Ver tutorial" en la barra (null = sin botón). Es un callback para
  /// que la feature `ar` no dependa del catálogo; quien lo pasa decide si
  /// reemplaza esta pantalla (la cámara se cierra antes del video) o vuelve.
  final VoidCallback? onOpenTutorial;

  /// Inyectable para tests; por defecto, el de `AR_RENDERER`.
  final IMakeupRenderer? renderer;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  /// El motor no está disponible: espejo de respaldo con el plugin `camera`.
  bool _fallbackMirror = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  /// false mientras la app no está en primer plano: no se usa la cámara.
  bool _inForeground = true;

  /// Solo el look elegido. La lista se crea una vez: si fuera nueva en cada
  /// build, TestFilterView reconstruiría sus opciones y reenviaría la receta.
  late final List<TestFilterOption>? _lookOptions = switch (widget.initialLook) {
    final look? => [look],
    null => null,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Fuera de primer plano no se monta nada: TestFilterView se desmonta (el
  /// motor se detiene en su dispose) y el CameraController de respaldo se
  /// libera, como pide la documentación del plugin camera. Sin esto la cámara
  /// seguía mandando frames a un FlutterEngine ya desacoplado ("FlutterJNI is
  /// not attached to native").
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (!_inForeground) return;
      final controller = _cameraController;
      _cameraController = null;
      setState(() {
        _inForeground = false;
        _isCameraInitialized = false;
      });
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_inForeground) return;
      setState(() => _inForeground = true);
      if (_fallbackMirror) _initializeFallbackCamera();
    }
  }

  Future<void> _initializeFallbackCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
      _cameraController = controller;
      await controller.initialize();
      // Si mientras se abría se pasó a segundo plano o se cerró la pantalla,
      // este controller ya no corresponde.
      if (!mounted || !_inForeground || _cameraController != controller) {
        if (_cameraController == controller) _cameraController = null;
        await controller.dispose();
        return;
      }
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  /// El motor no puede dibujar en este equipo (o es el respaldo,
  /// AR_RENDERER=painter): espejo de respaldo con el plugin camera. El aviso
  /// solo se muestra si se había pedido un look.
  void _onEngineUnavailable(String message) {
    if (!mounted || _fallbackMirror) return;
    if (widget.initialLook != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _fallbackMirror = true);
    if (_inForeground) unawaited(_initializeFallbackCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  TestFilterLabels _labels(AppLocalizations l10n) => TestFilterLabels(
        noFilter: l10n.testFilterNone,
        intensity: l10n.testFilterIntensity,
        note: l10n.testFilterNote,
        showPoints: l10n.testFilterShowPoints,
        compare: l10n.testFilterCompare,
        matte: l10n.testFilterFinishMatte,
        satin: l10n.testFilterFinishSatin,
        gloss: l10n.testFilterFinishGloss,
        shimmer: l10n.testFilterFinishShimmer,
        zoneAll: l10n.testFilterZoneAll,
        zoneLips: l10n.testFilterZoneLips,
        zoneEyes: l10n.testFilterZoneEyes,
        zoneCheeks: l10n.testFilterZoneCheeks,
        zoneSkin: l10n.testFilterZoneSkin,
        unavailable: l10n.testFilterUnavailable,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _cameraController;
    final look = widget.initialLook;
    final lookOptions = _lookOptions;
    final onOpenTutorial = widget.onOpenTutorial;

    final Widget body;
    if (!_inForeground) {
      body = const SizedBox.expand();
    } else if (!_fallbackMirror) {
      body = TestFilterView(
        renderer: widget.renderer,
        mirrorOnly: lookOptions == null,
        options: lookOptions,
        initialOptionId: look?.id,
        controls: TestFilterControls.intensity,
        labels: _labels(l10n),
        onUnavailable: () => _onEngineUnavailable(l10n.testFilterUnavailable),
      );
    } else if (_isCameraInitialized && controller != null) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: CameraPreview(controller),
      );
    } else {
      body = const Center(child: CircularProgressIndicator(color: Colors.pink));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(look?.label ?? l10n.mirror, style: const TextStyle(color: Colors.white)),
        actions: [
          if (onOpenTutorial != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const ValueKey('camera-open-tutorial'),
                onPressed: onOpenTutorial,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.pink,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(l10n.viewTutorial),
              ),
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: const SharedBottomNav(currentIndex: 2),
    );
  }
}
