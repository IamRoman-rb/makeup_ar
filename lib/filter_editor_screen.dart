import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

const List<String> kFilterCategories = ['Lips', 'Eyes', 'Complexion'];

class FilterEditorScreen extends StatefulWidget {
  // 💡 Novedad: Si pasas un ID, edita. Si no pasas nada, crea uno nuevo.
  final String? lookId;

  const FilterEditorScreen({super.key, this.lookId});

  @override
  State<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends State<FilterEditorScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Nuevo Filtro");
  final TextEditingController _imageController = TextEditingController();
  String _category = kFilterCategories.first;

  // Estas claves tienen que coincidir con las que espera
  // MakeupRecipe.convertLegacy (lib/services/ai_makeup_recipe_service.dart)
  // y con lo que sabe dibujar RealisticMakeupPainter — si no, el switch no
  // hace nada visible aunque quede prendido y guardado.
  final Map<String, Map<String, double>> _makeupParams = {
    "lips": {"r": 0.80, "g": 0.52, "b": 0.54, "opacity": 0.45},
    "blush": {"r": 0.82, "g": 0.58, "b": 0.55, "opacity": 0.15},
    "eyeshadow": {"r": 0.45, "g": 0.33, "b": 0.30, "opacity": 0.18},
    "eyeliner": {"r": 0.14, "g": 0.11, "b": 0.11, "opacity": 0.42},
    "eyelashes": {"r": 0.15, "g": 0.11, "b": 0.11, "opacity": 0.70},
  };

  final Map<String, bool> _activeFeatures = {
    "lips": false,
    "blush": false,
    "eyeshadow": false,
    "eyeliner": false,
    "eyelashes": false,
  };

  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si recibimos un ID, cargamos los datos de Firebase al entrar
    if (widget.lookId != null) {
      _loadExistingFilter();
    }
  }

  // 📥 FUNCIÓN DE LECTURA: Trae los datos actuales del filtro
  Future<void> _loadExistingFilter() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? "Filtro sin nombre";
        _imageController.text = data['image'] ?? "";
        final category = data['category'] as String?;
        if (category != null && kFilterCategories.contains(category)) {
          _category = category;
        }

        if (data.containsKey('makeup_params')) {
          final params = data['makeup_params'] as Map<String, dynamic>;

          params.forEach((key, value) {
            if (_makeupParams.containsKey(key) && value is Map) {
              setState(() {
                _activeFeatures[key] = true; // Encendemos el switch
                _makeupParams[key]!['r'] = ((value['r'] ?? 0.0) as num).toDouble();
                _makeupParams[key]!['g'] = ((value['g'] ?? 0.0) as num).toDouble();
                _makeupParams[key]!['b'] = ((value['b'] ?? 0.0) as num).toDouble();
                _makeupParams[key]!['opacity'] = ((value['opacity'] ?? 1.0) as num).toDouble();
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando filtro: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ☁️ FUNCIÓN DE ESCRITURA: Crea o Actualiza
  Future<void> _saveFilterToFirebase() async {
    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> finalParams = {};
      _activeFeatures.forEach((key, isActive) {
        if (isActive) finalParams[key] = _makeupParams[key];
      });

      final filterData = {
        "name": _nameController.text.trim(),
        "category": _category,
        "makeup_params": finalParams,
        "updated_at": FieldValue.serverTimestamp(),
        if (_imageController.text.trim().isNotEmpty) "image": _imageController.text.trim(),
      };

      if (widget.lookId == null) {
        // CREAR NUEVO
        filterData["order"] = DateTime.now().millisecondsSinceEpoch;
        await FirebaseFirestore.instance.collection('looks').add(filterData);
      } else {
        // ACTUALIZAR EXISTENTE
        await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).update(filterData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Filtro guardado con éxito! 🚀'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error guardando filtro: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 🗑️ FUNCIÓN DE BORRADO
  Future<void> _deleteFilter() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('¿Eliminar filtro?', style: TextStyle(color: Colors.white)),
          content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
          ],
        )
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Filtro eliminado 🗑️'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Error eliminando: $e");
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: user == null ? null : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isAdmin = data?['is_admin'] == true;

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
            body: Center(
              child: Text(
                'Solo un administrador puede crear o editar filtros.',
                style: GoogleFonts.inter(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return _buildEditor(context);
      },
    );
  }

  Widget _buildEditor(BuildContext context) {
    final isEditing = widget.lookId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Filtro' : 'Nuevo Filtro', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSaving ? null : _deleteFilter,
              tooltip: 'Eliminar filtro',
            ),
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.pink))
              : IconButton(
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.pinkAccent),
            onPressed: _saveFilterToFirebase,
            tooltip: 'Guardar',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Nombre del Filtro',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Categoría',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: kFilterCategories
                .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'URL de imagen (opcional)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          _buildParamEditor("Labios", "lips"),
          _buildParamEditor("Rubor", "blush"),
          _buildParamEditor("Sombra de ojos", "eyeshadow"),
          _buildParamEditor("Delineador", "eyeliner"),
          _buildParamEditor("Pestañas (HD)", "eyelashes"),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildParamEditor(String title, String key) {
    final bool isActive = _activeFeatures[key]!;
    final params = _makeupParams[key]!;

    final Color previewColor = Color.fromRGBO(
      (params['r']! * 255).toInt(),
      (params['g']! * 255).toInt(),
      (params['b']! * 255).toInt(),
      params['opacity']!,
    );

    return Card(
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: isActive,
                      activeColor: Colors.pinkAccent,
                      onChanged: (val) => setState(() => _activeFeatures[key] = val),
                    ),
                    Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                ),
              ],
            ),
            if (isActive) ...[
              const Divider(color: Colors.white24),
              _buildSlider(key, 'r', 'Rojo (R)', Colors.redAccent),
              _buildSlider(key, 'g', 'Verde (G)', Colors.greenAccent),
              _buildSlider(key, 'b', 'Azul (B)', Colors.blueAccent),
              _buildSlider(key, 'opacity', 'Opacidad', Colors.white),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String categoryKey, String colorKey, String label, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Expanded(
            child: Slider(
              value: _makeupParams[categoryKey]![colorKey]!,
              min: 0.0,
              max: 1.0,
              activeColor: accentColor,
              inactiveColor: Colors.white10,
              onChanged: (val) {
                setState(() {
                  _makeupParams[categoryKey]![colorKey] = val;
                });
              },
            ),
          ),
          SizedBox(
              width: 45,
              child: Text(_makeupParams[categoryKey]![colorKey]!.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}