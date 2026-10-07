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

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  /// true = se muestra el motor nativo en lugar de CameraPreview.
  bool _useNativeEngine = false;

  /// Evita alternar de nuevo mientras se libera o se abre la cámara.
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
      if (!mounted || _useNativeEngine) return;
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
        await _initializeCamera();
      }
    } finally {
      _switching = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _cameraController;

    final Widget body;
    if (_useNativeEngine) {
      body = TestFilterView(
        noFilterLabel: l10n.testFilterNone,
        intensityLabel: l10n.testFilterIntensity,
        note: l10n.testFilterNote,
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
          IconButton(
            tooltip: l10n.testFilter,
            onPressed: _toggleNativeEngine,
            icon: Icon(
              _useNativeEngine ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: _useNativeEngine ? Colors.pink : Colors.white,
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: const SharedBottomNav(currentIndex: 2),
    );
  }
}
