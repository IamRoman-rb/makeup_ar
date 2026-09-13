import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Trae/genera la receta de maquillaje (el JSON de colores/opacidades por
/// feature) que después cualquiera de los dos [ArMakeupEngine] aplica,
/// dibujándolo con CustomPainter o mandándolo a DeepAR vía changeParameter.
class AiMakeupRecipeService {
  const AiMakeupRecipeService();

  Future<Map<String, dynamic>> fetchRecipeForLook(String? lookId) async {
    if (lookId == null) return MakeupRecipe.defaultRecipe();

    try {
      final doc = await FirebaseFirestore.instance.collection('looks').doc(lookId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['makeup_recipe'] is Map) {
          return Map<String, dynamic>.from(data['makeup_recipe']);
        } else if (data['makeup_params'] is Map) {
          return MakeupRecipe.convertLegacy(Map<String, dynamic>.from(data['makeup_params']));
        }
      }
    } catch (e) {
      debugPrint('Error cargando receta: $e');
    }
    return MakeupRecipe.defaultRecipe();
  }

  /// Genera una receta a partir de un prompt de texto libre vía Groq
  /// (Llama 3). Devuelve `null` si la generación falla.
  Future<Map<String, dynamic>?> generateFromPrompt(String promptText) async {
    if (promptText.isEmpty) return null;

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

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          // TODO: falta la API key de Groq (empieza con gsk_...) — sin ella
          // esta llamada devuelve 401. No hardcodearla acá: pasarla vía
          // --dart-define o remote config.
          'Authorization': 'Bearer',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192',
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant designed to output JSON.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error de servidor: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final responseText = data['choices'][0]['message']['content'] as String;
      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error de IA: $e');
      return null;
    }
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
