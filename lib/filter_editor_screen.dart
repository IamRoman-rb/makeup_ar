import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

const List<String> kFilterCategories = ['Lips', 'Eyes', 'Complexion'];

/// Un paso del tutorial, con sus propios controllers para editarlo en el
/// formulario.
class _StepDraft {
  final TextEditingController title;
  final TextEditingController image;
  final TextEditingController description;

  _StepDraft({String title = '', String image = '', String description = ''})
      : title = TextEditingController(text: title),
        image = TextEditingController(text: image),
        description = TextEditingController(text: description);

  Map<String, String> toMap() => {
        'title': title.text.trim(),
        'image': image.text.trim(),
        'description': description.text.trim(),
      };

  bool get isEmpty => title.text.trim().isEmpty && description.text.trim().isEmpty && image.text.trim().isEmpty;

  void dispose() {
    title.dispose();
    image.dispose();
    description.dispose();
  }
}

class FilterEditorScreen extends StatefulWidget {
  // 💡 Novedad: Si pasas un ID, edita. Si no pasas nada, crea uno nuevo.
  final String? lookId;

  const FilterEditorScreen({super.key, this.lookId});

  @override
  State<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends State<FilterEditorScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Nuevo Look");
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  String _category = kFilterCategories.first;
  final List<_StepDraft> _steps = [];

  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lookId != null) {
      _loadExistingLook();
    }
  }

  // 📥 Trae los datos actuales del look
  Future<void> _loadExistingLook() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? "Look sin nombre";
        _imageController.text = data['image'] ?? "";
        _videoController.text = data['video_url'] ?? "";
        final category = data['category'] as String?;
        if (category != null && kFilterCategories.contains(category)) {
          _category = category;
        }

        final rawSteps = data['steps'];
        if (rawSteps is List) {
          for (final step in rawSteps) {
            if (step is Map) {
              _steps.add(_StepDraft(
                title: (step['title'] ?? '').toString(),
                image: (step['image'] ?? '').toString(),
                description: (step['description'] ?? '').toString(),
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error cargando look: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addStep() => setState(() => _steps.add(_StepDraft()));

  void _removeStep(int index) => setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
      });

  // ☁️ Crea o actualiza
  Future<void> _saveLookToFirebase() async {
    setState(() => _isSaving = true);

    try {
      final steps = _steps.where((s) => !s.isEmpty).map((s) => s.toMap()).toList();

      final lookData = {
        "name": _nameController.text.trim(),
        "category": _category,
        "steps": steps,
        "updated_at": FieldValue.serverTimestamp(),
        if (_imageController.text.trim().isNotEmpty) "image": _imageController.text.trim(),
        if (_videoController.text.trim().isNotEmpty) "video_url": _videoController.text.trim(),
      };

      if (widget.lookId == null) {
        lookData["order"] = DateTime.now().millisecondsSinceEpoch;
        await FirebaseFirestore.instance.collection('looks').add(lookData);
      } else {
        await FirebaseFirestore.instance.collection('looks').doc(widget.lookId).update(lookData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Look guardado con éxito! 🚀'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error guardando look: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 🗑️ Borrado
  Future<void> _deleteLook() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('¿Eliminar look?', style: TextStyle(color: Colors.white)),
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
            const SnackBar(content: Text('Look eliminado 🗑️'), backgroundColor: Colors.red),
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
    _videoController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
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
                'Solo un administrador puede crear o editar looks.',
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
        title: Text(isEditing ? 'Editar Look' : 'Nuevo Look', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSaving ? null : _deleteLook,
              tooltip: 'Eliminar look',
            ),
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.pink))
              : IconButton(
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.pinkAccent),
            onPressed: _saveLookToFirebase,
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
            decoration: _fieldDecoration('Nombre del Look'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _fieldDecoration('Categoría'),
            items: kFilterCategories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('URL de imagen de portada (opcional)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _videoController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('URL del video del tutorial (opcional, requiere Premium)'),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pasos del tutorial', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add, color: Colors.pinkAccent),
                label: const Text('Agregar paso', style: TextStyle(color: Colors.pinkAccent)),
              ),
            ],
          ),
          if (_steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Todavía no agregaste ningún paso.', style: GoogleFonts.inter(color: Colors.white38)),
            ),
          for (int i = 0; i < _steps.length; i++) _buildStepCard(i),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildStepCard(int index) {
    final step = _steps[index];

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
                Text('Paso ${index + 1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeStep(index),
                  tooltip: 'Eliminar paso',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: step.title,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: step.image,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('URL de imagen (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: step.description,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _fieldDecoration('Descripción / instrucción'),
            ),
          ],
        ),
      ),
    );
  }
}
