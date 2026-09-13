import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'step_by_step_screen.dart';
import 'l10n/app_localizations.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'filter_editor_screen.dart';
import 'package:http/http.dart' as http;

class CameraScreen extends StatefulWidget {
  final String? filterPath;
  final String? lookId;

  const CameraScreen({super.key, this.filterPath, this.lookId});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late FaceMeshDetector _faceMeshDetector; // 🚀 Usamos el oficial de Google

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isGeneratingAI = false;
  bool _isEffectOn = true;

  Map<String, dynamic> _makeupRecipe = {};

  FaceMesh? _detectedMesh;
  Size? _imageSize;

  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFaceMesh();
    _fetchMakeupParams();
    _initializeCamera();
  }

  void _initializeFaceMesh() {
    // 🧠 Motor oficial de 468 puntos (A prueba de fallos)
    _faceMeshDetector = FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);

      _cameraController = CameraController(
        frontCamera, ResolutionPreset.high, enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

      _cameraController!.startImageStream((CameraImage image) {
        _processCameraImage(image);
      });
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) allBytes.putUint8List(plane.bytes);
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(size: imageSize, rotation: imageRotation, format: inputImageFormat, bytesPerRow: image.planes[0].bytesPerRow),
      );

      // 🚀 Detectamos la malla de 468 puntos
      final meshes = await _faceMeshDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _detectedMesh = meshes.isNotEmpty ? meshes.first : null;
          _imageSize = (camera.sensorOrientation == 90 || camera.sensorOrientation == 270)
              ? Size(image.height.toDouble(), image.width.toDouble())
              : Size(image.width.toDouble(), image.height.toDouble());
        });
      }
    } finally {
      _isProcessing = false;
    }
  }
// 🧠 IA GENERATIVA: Groq (Llama 3) -> Filtro AR (¡GRATIS Y ULTRA RÁPIDO!)
  Future<void> _generateMakeupFromPrompt(String promptText) async {
    if (promptText.isEmpty) return;
    setState(() => _isGeneratingAI = true);

    try {
      // ⚠️ Pega tu clave de Groq aquí (Empieza con gsk_...)


      final prompt = '''
        Eres un estilista experto en Realidad Aumentada. El usuario pide: "$promptText".
        Devuelve ÚNICAMENTE un JSON válido con esta estructura (usa HEX para colores y valores 0.0 a 1.0).
        Solo activa ('enabled': true) lo que el usuario pida explícitamente.
        {
          "blush": {"enabled": true, "color": "#FF5733", "opacity": 0.3, "softness": 0.9},
          "lips": {"enabled": true, "color": "#900C3F", "opacity": 0.5, "softness": 0.7, "finish": "gloss"},
          "eyes": {
            "eyeshadow": {"enabled": true, "color": "#000000", "opacity": 0.4, "softness": 0.8},
            "eyeliner": {"enabled": true, "color": "#000000", "opacity": 0.8, "thickness": 0.015},
            "eyelashes": {"enabled": true, "length": 0.2, "density": 0.8, "curl": 0.7}
          }
        }
      ''';

      // 🚀 Llamamos a la API de Groq (Compatible con el código de OpenAI)
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'), // <-- URL de Groq
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192', // <-- Modelo Llama 3 super rápido
          'response_format': { "type": "json_object" },
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant designed to output JSON.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final responseText = data['choices'][0]['message']['content'];

        String cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> generatedData = jsonDecode(cleanJson);

        setState(() => _makeupRecipe = generatedData);
        debugPrint("✅ Groq/Llama3 generó el filtro con éxito");
      } else {
        throw Exception('Error de servidor: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("❌ Error de IA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar con IA. Intenta otro prompt.')),
        );
      }
    } finally {
      setState(() => _isGeneratingAI = false);
      _promptController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _fetchMakeupParams() async {
    if (widget.lookId == null) {
      setState(() => _makeupRecipe = MakeupRecipe.defaultRecipe());
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['makeup_recipe'] is Map) {
          setState(() => _makeupRecipe = Map<String, dynamic>.from(data['makeup_recipe']));
        } else if (data['makeup_params'] is Map) {
          setState(() => _makeupRecipe = MakeupRecipe.convertLegacy(Map<String, dynamic>.from(data['makeup_params'])));
        }
      }
    } catch (e) {
      setState(() => _makeupRecipe = MakeupRecipe.defaultRecipe());
    }
  }

  void _toggleEffect() => setState(() => _isEffectOn = !_isEffectOn);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceMeshDetector.close();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 📸 CÁMARA Y PINCEL
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  if (_isEffectOn && _detectedMesh != null && _makeupRecipe.isNotEmpty)
                    CustomPaint(
                      painter: RealisticMakeupPainter(
                        mesh: _detectedMesh!,
                        imageSize: _imageSize!,
                        recipe: _makeupRecipe,
                        mirrorHorizontal: true,
                      ),
                    ),
                ],
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.pink)),

          // BOTONES SUPERIORES
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Navigator.canPop(context)
                    ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
                    : const SizedBox(),
              ),
            ),
          ),

          // BOTONES LATERALES
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 90), // Elevado para dar espacio a la IA
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTutorialButton(l10n),
                    const SizedBox(height: 15),
                    _buildEffectButton(l10n),
                  ],
                ),
              ),
            ),
          ),

          // 🤖 CAJA DE TEXTO PARA LA IA
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _promptController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Ej: "Labios rojos y rubor rosa"',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      _isGeneratingAI
                          ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.purpleAccent))
                          : IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                        onPressed: () => _generateMakeupFromPrompt(_promptController.text),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepByStepScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF1A1A1A), size: 16),
            const SizedBox(width: 8),
            Text(l10n.tutorial, style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _toggleEffect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: _isEffectOn ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isEffectOn ? Colors.transparent : Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isEffectOn ? Icons.auto_awesome : Icons.auto_awesome_outlined, color: _isEffectOn ? const Color(0xFFD4AF37) : Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_isEffectOn ? l10n.effectOn : l10n.effectOff, style: GoogleFonts.inter(color: _isEffectOn ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MAKEUP RECIPE COMPATIBILITY
// ============================================================================

class MakeupRecipe {
  static Map<String, dynamic> defaultRecipe() {
    return {
      'skin': {'foundation': {'enabled': false}, 'glow': {'enabled': false}},
      'blush': {'enabled': false},
      'eyes': {'eyeshadow': {'enabled': false}, 'eyeliner': {'enabled': false}, 'eyelashes': {'enabled': false}},
      'lips': {'enabled': false},
    };
  }

  static Map<String, dynamic> convertLegacy(Map<String, dynamic> old) {
    Map<String, dynamic> convertColor(dynamic value) {
      if (value is! Map) return {};
      final r = ((value['r'] ?? 0.8) as num).toDouble();
      final g = ((value['g'] ?? 0.2) as num).toDouble();
      final b = ((value['b'] ?? 0.3) as num).toDouble();
      final hex = '#${(r * 255).round().toRadixString(16).padLeft(2, '0')}${(g * 255).round().toRadixString(16).padLeft(2, '0')}${(b * 255).round().toRadixString(16).padLeft(2, '0')}';
      return {'color': hex, 'opacity': ((value['opacity'] ?? 0.5) as num).toDouble()};
    }

    return {
      'blush': {'enabled': old.containsKey('blush'), ...convertColor(old['blush']), 'softness': 0.95},
      'lips': {'enabled': old.containsKey('lips'), ...convertColor(old['lips']), 'softness': 0.75, 'finish': 'satin'},
      'eyes': {
        'eyeshadow': {'enabled': old.containsKey('eyeshadow'), ...convertColor(old['eyeshadow']), 'softness': 0.90},
        'eyeliner': {'enabled': old.containsKey('eyeliner'), ...convertColor(old['eyeliner'])},
        'eyelashes': {'enabled': old.containsKey('eyelashes'), 'length': 0.18, 'density': 0.65, 'curl': 0.60},
      },
    };
  }
}

// ============================================================================
// REALISTIC MAKEUP PAINTER (Adaptado a ML Kit Oficial)
// ============================================================================

class RealisticMakeupPainter extends CustomPainter {
  final FaceMesh mesh;
  final Size imageSize;
  final Map<String, dynamic> recipe;
  final bool mirrorHorizontal;

  late double _scale;
  late double _offsetX;
  late double _offsetY;

  RealisticMakeupPainter({required this.mesh, required this.imageSize, required this.recipe, this.mirrorHorizontal = true});

  Offset p(int index, Size size) {
    if (index < 0 || index >= mesh.points.length) return Offset.zero;
    final point = mesh.points[index];
    // Adaptación a coordenadas absolutas de ML Kit
    final double mappedX = (point.x * _scale) + _offsetX;
    final double mappedY = (point.y * _scale) + _offsetY;
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

    _scale = math.max(size.width / imageSize.width, size.height / imageSize.height);
    final double scaledWidth = imageSize.width * _scale;
    final double scaledHeight = imageSize.height * _scale;
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