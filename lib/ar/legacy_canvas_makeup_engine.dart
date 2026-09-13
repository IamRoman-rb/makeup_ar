import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'ar_makeup_engine.dart';

/// Motor AR original: cámara + malla de 468 puntos de ML Kit + un
/// [CustomPainter] propio que dibuja el maquillaje como paths/gradientes 2D.
/// Se mantiene como fallback mientras no exista el efecto DeepAR (ver
/// `assets/ar_effects/README.md`) o para dispositivos sin soporte DeepAR.
class LegacyCanvasMakeupEngine extends ArMakeupEngine {
  CameraController? _cameraController;
  final FaceMeshDetector _faceMeshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isEffectOn = true;
  Map<String, dynamic> _recipe = const {};
  FaceMesh? _detectedMesh;
  Size? _imageSize;
  int _sensorOrientation = 0;

  @override
  bool get isReady => _isCameraInitialized;

  @override
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      notifyListeners();

      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final meshes = await _faceMeshDetector.processImage(inputImage);

      _detectedMesh = meshes.isNotEmpty ? meshes.first : null;
      // ML Kit devuelve los puntos en el espacio del buffer crudo del sensor
      // (sin rotar) — guardamos ese mismo tamaño sin invertir ejes, y la
      // rotación real se aplica punto por punto en el painter.
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      _sensorOrientation = camera.sensorOrientation;
      notifyListeners();
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Future<void> applyRecipe(Map<String, dynamic> recipe) async {
    _recipe = recipe;
    notifyListeners();
  }

  @override
  Future<void> setEffectEnabled(bool enabled) async {
    _isEffectOn = enabled;
    notifyListeners();
  }

  @override
  Widget buildPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.pink));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        if (_isEffectOn && _detectedMesh != null && _recipe.isNotEmpty)
          CustomPaint(
            painter: RealisticMakeupPainter(
              mesh: _detectedMesh!,
              imageSize: _imageSize!,
              sensorOrientation: _sensorOrientation,
              recipe: _recipe,
              // La vista de cámara no está espejada (vista tipo videollamada),
              // así que el maquillaje tampoco debe espejarse o queda desalineado.
              mirrorHorizontal: false,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceMeshDetector.close();
    super.dispose();
  }
}

// ============================================================================
// REALISTIC MAKEUP PAINTER (Adaptado a ML Kit Oficial)
// ============================================================================

class RealisticMakeupPainter extends CustomPainter {
  final FaceMesh mesh;
  /// Tamaño del buffer crudo de la cámara (sin rotar), tal como lo entrega
  /// ML Kit junto con los puntos de la malla.
  final Size imageSize;
  /// `CameraDescription.sensorOrientation` — cuántos grados hay que rotar
  /// el buffer crudo para que quede "parado" como en la pantalla.
  final int sensorOrientation;
  final Map<String, dynamic> recipe;
  final bool mirrorHorizontal;

  late double _scale;
  late double _offsetX;
  late double _offsetY;

  RealisticMakeupPainter({
    required this.mesh,
    required this.imageSize,
    required this.recipe,
    this.sensorOrientation = 0,
    this.mirrorHorizontal = true,
  });

  /// Tamaño del buffer una vez rotado a orientación "de pantalla".
  Size get _rotatedImageSize {
    final degrees = sensorOrientation % 360;
    return (degrees == 90 || degrees == 270) ? Size(imageSize.height, imageSize.width) : imageSize;
  }

  /// ML Kit devuelve los puntos en el espacio crudo del sensor: hay que
  /// rotarlos nosotros mismos para que coincidan con lo que se ve en
  /// pantalla (que la propia `CameraPreview` sí rota internamente).
  Offset _rotateRaw(double x, double y) {
    switch (sensorOrientation % 360) {
      case 90:
        return Offset(imageSize.height - y, x);
      case 180:
        return Offset(imageSize.width - x, imageSize.height - y);
      case 270:
        return Offset(y, imageSize.width - x);
      default:
        return Offset(x, y);
    }
  }

  Offset p(int index, Size size) {
    if (index < 0 || index >= mesh.points.length) return Offset.zero;
    final point = mesh.points[index];
    final rotated = _rotateRaw(point.x, point.y);
    final double mappedX = (rotated.dx * _scale) + _offsetX;
    final double mappedY = (rotated.dy * _scale) + _offsetY;
    return Offset(mirrorHorizontal ? size.width - mappedX : mappedX, mappedY);
  }

  Color parseColor(dynamic value, {Color fallback = Colors.pink}) {
    if (value is Color) return value;
    if (value is String) {
      try {
        var hex = value.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    return fallback;
  }

  double number(dynamic value, double fallback) => value is num ? value.toDouble() : fallback;

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.points.length < 468) return;

    final rotatedSize = _rotatedImageSize;
    _scale = math.max(size.width / rotatedSize.width, size.height / rotatedSize.height);
    final double scaledWidth = rotatedSize.width * _scale;
    final double scaledHeight = rotatedSize.height * _scale;
    _offsetX = (size.width - scaledWidth) / 2;
    _offsetY = (size.height - scaledHeight) / 2;

    _drawSkin(canvas, size);
    _drawBlush(canvas, size);
    _drawEyeshadow(canvas, size);
    _drawEyeliner(canvas, size);
    _drawLips(canvas, size);
    _drawEyelashes(canvas, size);
  }

  void _drawSkin(Canvas canvas, Size size) {
    final skin = recipe['skin'];
    if (skin is! Map) return;

    final foundation = skin['foundation'];
    if (foundation is Map && foundation['enabled'] == true) {
      final coverage = number(foundation['coverage'], 0.10);
      if (coverage > 0) {
        final forehead = p(10, size);
        final chin = p(152, size);
        final left = p(234, size);
        final right = p(454, size);

        final center = Offset((left.dx + right.dx) / 2, (forehead.dy + chin.dy) / 2);
        final faceWidth = left.distanceTo(right);
        final radius = math.max(faceWidth, forehead.distanceTo(chin)) * 0.65;

        final paint = Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFFE7DC).withOpacity(coverage * 0.035), const Color(0xFFFFE7DC).withOpacity(coverage * 0.015), Colors.transparent],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, paint);
      }
    }

    final glow = skin['glow'];
    if (glow is Map && glow['enabled'] == true) {
      final faceWidth = p(234, size).distanceTo(p(454, size));
      final intensity = number(glow['intensity'], 0.08);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(intensity * 0.035), Colors.transparent],
        ).createShader(Rect.fromCircle(center: p(10, size), radius: faceWidth * 0.42));
      canvas.drawCircle(p(10, size), faceWidth * 0.42, glowPaint);
    }
  }

  void _drawBlush(Canvas canvas, Size size) {
    final blush = recipe['blush'];
    if (blush is! Map || blush['enabled'] != true) return;

    final color = parseColor(blush['color'], fallback: const Color(0xFFD87982));
    final opacity = number(blush['opacity'], 0.20);
    final blur = p(159, size).distanceTo(p(386, size)) * 0.24 * (0.55 + number(blush['softness'], 0.95) * 0.45);

    void drawSpot(Offset center) {
      final paint = Paint()..shader = RadialGradient(
        colors: [color.withOpacity(opacity * 0.28), color.withOpacity(opacity * 0.16), color.withOpacity(opacity * 0.035), Colors.transparent],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: blur * 2));
      canvas.drawCircle(center, blur * 2, paint);
    }

    drawSpot(p(205, size));
    drawSpot(p(425, size));
  }

  void _drawEyeshadow(Canvas canvas, Size size) {
    final eyes = recipe['eyes'];
    if (eyes is! Map) return;
    final shadow = eyes['eyeshadow'];
    if (shadow is! Map || shadow['enabled'] != true) return;

    final color = parseColor(shadow['color'], fallback: const Color(0xFF72554C));
    final opacity = number(shadow['opacity'], 0.18);
    final softness = number(shadow['softness'], 0.90);

    void drawSide(bool left) {
      final upper = left ? const [33, 246, 161, 160, 159, 158, 157, 173] : const [263, 466, 388, 387, 386, 385, 384, 398];
      final lower = left ? const [133, 155, 154, 153, 145] : const [362, 384, 385, 386, 263];

      final path = Path()..moveTo(p(upper.first, size).dx, p(upper.first, size).dy);
      for (final index in upper.skip(1)) { path.lineTo(p(index, size).dx, p(index, size).dy); }
      for (final index in lower.reversed) { path.lineTo(p(index, size).dx, p(index, size).dy); }
      path.close();

      final eyeWidth = p(left ? 33 : 263, size).distanceTo(p(left ? 133 : 362, size));
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(opacity * 0.28)..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, eyeWidth * (0.035 + softness * 0.04)));
    }
    drawSide(true);
    drawSide(false);
  }

  void _drawEyeliner(Canvas canvas, Size size) {
    final eyes = recipe['eyes'];
    if (eyes is! Map) return;
    final eyeliner = eyes['eyeliner'];
    if (eyeliner is! Map || eyeliner['enabled'] != true) return;

    final color = parseColor(eyeliner['color'], fallback: const Color(0xFF241B1B));
    final opacity = number(eyeliner['opacity'], 0.42);
    final thickness = number(eyeliner['thickness'], 0.014);

    void drawSide(bool left) {
      final indices = left ? const [33, 246, 161, 160, 159, 158, 157, 173] : const [263, 466, 388, 387, 386, 385, 384, 398];
      final eyeWidth = p(left ? 33 : 263, size).distanceTo(p(left ? 133 : 362, size));

      final path = Path()..moveTo(p(indices.first, size).dx, p(indices.first, size).dy);
      for (int i = 1; i < indices.length; i++) {
        final current = p(indices[i], size);
        final previous = p(indices[i - 1], size);
        path.quadraticBezierTo((previous.dx + current.dx) / 2, (previous.dy + current.dy) / 2, current.dx, current.dy);
      }

      canvas.drawPath(path, Paint()..color = color.withOpacity(opacity * 0.72)..style = PaintingStyle.stroke
        ..strokeWidth = (eyeWidth * thickness).clamp(0.65, 3.2)..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    drawSide(true);
    drawSide(false);
  }

  void _drawLips(Canvas canvas, Size size) {
    final lips = recipe['lips'];
    if (lips is! Map || lips['enabled'] != true) return;

    final color = parseColor(lips['color'], fallback: const Color(0xFFA95062));
    final opacity = number(lips['opacity'], 0.38);
    final lipWidth = p(61, size).distanceTo(p(291, size));

    final upper = const [61, 185, 40, 39, 37, 0, 267, 269, 270, 291];
    final lower = const [291, 321, 314, 17, 84, 181, 91, 146, 61];

    final path = Path()..moveTo(p(upper.first, size).dx, p(upper.first, size).dy);
    for (final index in upper.skip(1)) path.lineTo(p(index, size).dx, p(index, size).dy);
    for (final index in lower.skip(1)) path.lineTo(p(index, size).dx, p(index, size).dy);
    path.close();

    canvas.drawPath(path, Paint()..color = color.withOpacity(opacity * 0.62)..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.8, lipWidth * number(lips['softness'], 0.72) * 0.008)));
  }

  void _drawEyelashes(Canvas canvas, Size size) {
    final eyes = recipe['eyes'];
    if (eyes is! Map) return;
    final lashes = eyes['eyelashes'];
    if (lashes is! Map || lashes['enabled'] != true) return;

    final length = number(lashes['length'], 0.18);
    final density = number(lashes['density'], 0.65);
    final curl = number(lashes['curl'], 0.60);

    void drawSide(bool left) {
      final indices = left ? const [33, 246, 161, 160, 159, 158, 157, 173] : const [263, 466, 388, 387, 386, 385, 384, 398];
      final eyeCenter = left ? p(468, size) : p(473, size);
      final eyeWidth = p(left ? 33 : 263, size).distanceTo(p(left ? 133 : 362, size));

      final paint = Paint()..color = const Color(0xFF171313).withOpacity(0.60 * density)..style = PaintingStyle.stroke..strokeWidth = 0.65..strokeCap = StrokeCap.round;

      for (int i = 0; i < math.max(3, (indices.length * density).round()); i++) {
        final start = p(indices[i], size);
        final distance = math.sqrt(math.pow(start.dx - eyeCenter.dx, 2) + math.pow(start.dy - eyeCenter.dy, 2));
        if (distance < 0.001) continue;

        final finalLength = eyeWidth * length * (0.65 + math.sin((i / math.max(1, indices.length - 1)) * math.pi) * 0.50) * (0.88 + math.sin(i * 4.2) * 0.10);
        final curve = eyeWidth * curl * 0.045;

        canvas.drawPath(Path()..moveTo(start.dx, start.dy)..quadraticBezierTo(
            start.dx + ((start.dx - eyeCenter.dx) / distance) * finalLength * 0.55,
            start.dy + ((start.dy - eyeCenter.dy) / distance) * finalLength * 0.35 - curve * 0.65,
            start.dx + ((start.dx - eyeCenter.dx) / distance) * finalLength,
            start.dy + ((start.dy - eyeCenter.dy) / distance) * finalLength - curve), paint);
      }
    }
    drawSide(true);
    drawSide(false);
  }

  @override
  bool shouldRepaint(covariant RealisticMakeupPainter oldDelegate) => true;
}

extension OffsetDistance on Offset {
  double distanceTo(Offset other) => math.sqrt(math.pow(dx - other.dx, 2) + math.pow(dy - other.dy, 2));
}
