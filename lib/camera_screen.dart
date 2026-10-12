import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'features/ar/presentation/test_filter_view.dart';
import 'l10n/app_localizations.dart';
import 'shared_bottom_nav.dart';

/// Espejo: cámara frontal en vivo. Con el botón de la barra se alterna al
/// filtro de prueba del motor AR nativo (`TestFilterView`).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  /// true = se muestra el motor nativo en lugar de CameraPreview.
  bool _useNativeEngine = false;

  /// Evita alternar de nuevo mientras se libera o se abre la cámara.
  bool _switching = false;

  /// false mientras la app no está en primer plano: no se usa la cámara.
  bool _inForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  /// Como pide la documentación del plugin camera: la cámara se libera al
  /// pasar a segundo plano y se vuelve a abrir al regresar. Sin esto, al salir
  /// con "atrás" la cámara seguía mandando frames a un FlutterEngine ya
  /// desacoplado y la app crasheaba ("FlutterJNI is not attached to native").
  /// En modo motor, desmontar TestFilterView detiene el motor nativo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (!_inForeground) return;
      _inForeground = false;
      final controller = _cameraController;
      _cameraController = null;
      setState(() => _isCameraInitialized = false);
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_inForeground) return;
      setState(() => _inForeground = true);
      if (!_useNativeEngine) _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
      _cameraController = controller;
      await controller.initialize();
      // Si mientras se abría se pasó al motor, a segundo plano o se cerró la
      // pantalla, este controller ya no corresponde.
      if (!mounted || _useNativeEngine || !_inForeground || _cameraController != controller) {
        if (_cameraController == controller) _cameraController = null;
        await controller.dispose();
        return;
      }
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  /// La cámara la puede usar un solo dueño a la vez: antes de montar el motor
  /// se libera CameraController, y al volver se abre de nuevo (el motor se
  /// detiene en el dispose de TestFilterView).
  Future<void> _toggleNativeEngine() async {
    if (_switching) return;
    _switching = true;
    try {
      if (!_useNativeEngine) {
        final controller = _cameraController;
        _cameraController = null;
        setState(() => _isCameraInitialized = false);
        await controller?.dispose();
        if (!mounted) return;
        setState(() => _useNativeEngine = true);
      } else {
        setState(() => _useNativeEngine = false);
        if (_inForeground) await _initializeCamera();
      }
    } finally {
      _switching = false;
    }
  }

  /// El motor no puede dibujar en este equipo (o es el respaldo,
  /// AR_RENDERER=painter): se vuelve al espejo normal con un aviso.
  void _onEngineUnavailable(String message) {
    if (!mounted || !_useNativeEngine) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    unawaited(_toggleNativeEngine());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _cameraController;

    final Widget body;
    if (_useNativeEngine && _inForeground) {
      body = TestFilterView(
        labels: TestFilterLabels(
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
        ),
        onUnavailable: () => _onEngineUnavailable(l10n.testFilterUnavailable),
      );
    } else if (_isCameraInitialized && controller != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: CameraPreview(controller),
          ),
        ],
      );
    } else {
      body = const Center(child: CircularProgressIndicator(color: Colors.pink));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(l10n.mirror, style: const TextStyle(color: Colors.white)),
        actions: [
          // Con texto: solo el ícono pasaba desapercibido en el teléfono.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _toggleNativeEngine,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _useNativeEngine ? Colors.pink : Colors.white12,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(l10n.testFilter),
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: const SharedBottomNav(currentIndex: 2),
    );
  }
}
