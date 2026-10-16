import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ar_makeup_app/features/catalog/presentation/catalog_labels.dart';
import 'package:ar_makeup_app/features/vip/data/premium_content.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart';

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
  final TextEditingController _nameController = TextEditingController();
  bool _defaultNameSet = false;
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  String _category = kFilterCategories.first;
  final List<_StepDraft> _steps = [];

  bool _isSaving = false;
  bool _isLoading = false;

  // Una vez: creado en build, cada setState (agregar un paso, cambiar la
  // categoría) se resuscribía y reemplazaba el formulario por un spinner.
  late final Stream<DocumentSnapshot>? _userStream = _userSnapshots();

  static Stream<DocumentSnapshot>? _userSnapshots() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? null : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  }

  @override
  void initState() {
    super.initState();
    if (widget.lookId != null) {
      _loadExistingLook();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nombre por defecto de un look nuevo, en el idioma de la app.
    if (!_defaultNameSet && widget.lookId == null) {
      _defaultNameSet = true;
      _nameController.text = AppLocalizations.of(context)!.filterEditorDefaultName;
    }
  }

  // 📥 Trae los datos actuales del look
  Future<void> _loadExistingLook() async {
    final lookId = widget.lookId;
    if (lookId == null) return;
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('looks').doc(lookId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? "Look sin nombre";
        _imageController.text = data['image'] ?? "";
        // El video vive en premium/content (AUDIT.md §5.2); los looks sin
        // migrar lo tienen en el documento y se mueve al guardar.
        _videoController.text = await PremiumContent.videoUrl(lookId) ?? (data['video_url'] as String? ?? "");
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addStep() => setState(() => _steps.add(_StepDraft()));

  void _removeStep(int index) => setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
      });

  // ☁️ Crea o actualiza
  Future<void> _saveLookToFirebase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    try {
      final steps = _steps.where((s) => !s.isEmpty).map((s) => s.toMap()).toList();

      final lookData = {
        "name": _nameController.text.trim(),
        "category": _category,
        "steps": steps,
        "updated_at": FieldValue.serverTimestamp(),
        if (_imageController.text.trim().isNotEmpty) "image": _imageController.text.trim(),
      };
      final videoUrl = _videoController.text.trim();

      // El look y su video en un batch: el video va a premium/content (solo
      // VIP y admins lo leen) y nunca al documento del look, que es público.
      final looks = FirebaseFirestore.instance.collection('looks');
      final batch = FirebaseFirestore.instance.batch();
      final existingId = widget.lookId;
      final lookRef = existingId == null ? looks.doc() : looks.doc(existingId);
      if (existingId == null) {
        lookData["order"] = DateTime.now().millisecondsSinceEpoch;
        batch.set(lookRef, lookData);
      } else {
        batch.update(lookRef, {...lookData, "video_url": FieldValue.delete()});
      }
      final premiumRef = PremiumContent.ref(lookRef.id);
      if (videoUrl.isNotEmpty) {
        batch.set(premiumRef, {"video_url": videoUrl});
      } else if (existingId != null) {
        batch.delete(premiumRef);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.filterEditorSaved), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error guardando look: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.filterEditorSaveError('$e'))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🗑️ Borrado
  Future<void> _deleteLook() async {
    final lookId = widget.lookId;
    if (lookId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(l10n.filterEditorDeleteTitle, style: const TextStyle(color: Colors.white)),
          content: Text(l10n.filterEditorDeleteBody, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.redAccent))),
          ],
        )
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final batch = FirebaseFirestore.instance.batch()
          ..delete(PremiumContent.ref(lookId))
          ..delete(FirebaseFirestore.instance.collection('looks').doc(lookId));
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.filterEditorDeleted), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Error eliminando: $e");
        // Antes quedaba _isSaving en true y el spinner tapaba el botón de guardar.
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorWithDetails('$e'))));
        }
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
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
                AppLocalizations.of(context)!.filterEditorAdminOnly,
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
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.lookId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(isEditing ? l10n.filterEditorEditTitle : l10n.filterEditorNewTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSaving ? null : _deleteLook,
              tooltip: l10n.filterEditorDeleteTooltip,
            ),
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.pink))
              : IconButton(
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.pinkAccent),
            onPressed: _saveLookToFirebase,
            tooltip: l10n.save,
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
            decoration: _fieldDecoration(l10n.filterEditorName),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _fieldDecoration(l10n.filterEditorCategory),
            items: kFilterCategories.map((category) => DropdownMenuItem(value: category, child: Text(lookCategoryLabel(l10n, category)))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(l10n.filterEditorCoverUrl),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _videoController,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(l10n.filterEditorVideoUrl),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.filterEditorSteps, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add, color: Colors.pinkAccent),
                label: Text(l10n.filterEditorAddStep, style: const TextStyle(color: Colors.pinkAccent)),
              ),
            ],
          ),
          if (_steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(l10n.filterEditorNoSteps, style: GoogleFonts.inter(color: Colors.white38)),
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.filterEditorStep(index + 1), style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeStep(index),
                  tooltip: l10n.filterEditorRemoveStep,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: step.title,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(l10n.filterEditorStepTitle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: step.image,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(l10n.filterEditorStepImage),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: step.description,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _fieldDecoration(l10n.filterEditorStepDescription),
            ),
          ],
        ),
      ),
    );
  }
}
