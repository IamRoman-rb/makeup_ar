import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart'; // <-- 1. Importación del traductor

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;

  File? _imageFile;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  String _selectedSkinType = 'Combined';
  String _selectedSkinTone = 'Light';
  Set<String> _selectedPreferences = {};

  // Los valores internos se mantienen en inglés para no romper tu base de datos
  final List<String> skinTypes = ['Combined', 'Oily', 'Dry', 'Sensitive'];
  final List<Map<String, dynamic>> skinTones = [
    {'name': 'Light', 'color': const Color(0xFFFCE5D8)},
    {'name': 'Medium', 'color': const Color(0xFFD29E7D)},
    {'name': 'Tan', 'color': const Color(0xFFA06540)},
    {'name': 'Deep', 'color': const Color(0xFF4A2F1D)},
  ];
  final List<String> preferences = ['Natural', 'Glamour', 'Minimalist', 'Bold', 'Skincare Focus'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['nombre'] ?? '';
          _ageController.text = (data['edad'] ?? '').toString();
          _currentImageUrl = data['foto_perfil'];

          if (data['fecha_nacimiento'] != null && data['fecha_nacimiento'].toString().isNotEmpty) {
            try {
              _selectedDate = DateFormat('yyyy-MM-dd').parse(data['fecha_nacimiento']);
            } catch (e) {
              debugPrint("Error parseando fecha");
            }
          }

          _selectedSkinType = data['tipo_piel'] ?? 'Combined';
          _selectedSkinTone = data['tono_piel'] ?? 'Light';

          if (data['gustos_personales'] != null) {
            _selectedPreferences = Set<String>.from(data['gustos_personales']);
          }
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1A1A1A))), child: child!);
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!; // Traductor para los mensajes de éxito/error

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? updatedImageUrl = _currentImageUrl;
        if (_imageFile != null) {
          final ref = FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}.jpg');
          await ref.putFile(_imageFile!);
          updatedImageUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'nombre': _nameController.text.trim(),
          'edad': int.tryParse(_ageController.text) ?? 0,
          'fecha_nacimiento': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
          'tipo_piel': _selectedSkinType,
          'tono_piel': _selectedSkinTone,
          'gustos_personales': _selectedPreferences.toList(),
          'foto_perfil': updatedImageUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileUpdated, style: GoogleFonts.inter())));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorSaving} $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFFFDF7F8), body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));

    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor para la vista

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(
        title: Text(l10n.editProfile, style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)), centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // WIDGET FOTO DE PERFIL
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                          ? NetworkImage(_currentImageUrl!) as ImageProvider
                          : null,
                      child: (_imageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFD4AF37), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // CAMPOS DE TEXTO TRADUCIDOS
            _buildTextField(l10n.fullName, 'Jane Doe', _nameController),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildTextField(l10n.age, '25', _ageController, isNumber: true)),
                const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.dob, // Fecha de Nacimiento traducida
                        labelStyle: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedDate == null ? 'mm/dd/yyyy' : DateFormat('MM/dd/yyyy').format(_selectedDate!), style: GoogleFonts.inter(color: _selectedDate == null ? Colors.grey.shade400 : const Color(0xFF1A1A1A))),
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Text(l10n.skinType, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: skinTypes.map((type) {
                final isSelected = _selectedSkinType == type;
                return ChoiceChip(
                  label: Text(type, style: GoogleFonts.inter(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade600, fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedSkinType = type),
                  backgroundColor: Colors.transparent, selectedColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300)),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            Text(l10n.skinTone, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: skinTones.map((tone) {
                final isSelected = _selectedSkinTone == tone['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedSkinTone = tone['name']),
                  child: Column(
                    children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: tone['color'], shape: BoxShape.circle, border: Border.all(color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent, width: 2))),
                      const SizedBox(height: 8),
                      Text(tone['name'], style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            Text(l10n.personalTastes, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: preferences.map((pref) {
                final isSelected = _selectedPreferences.contains(pref);
                return FilterChip(
                  label: Text(pref, style: GoogleFonts.inter(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade600, fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) { setState(() { selected ? _selectedPreferences.add(pref) : _selectedPreferences.remove(pref); }); },
                  backgroundColor: Colors.transparent, selectedColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300)),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(l10n.updateProfile, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  const Icon(Icons.check, color: Colors.white, size: 20)
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, labelStyle: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12),
        hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.grey.shade300),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A1A1A))),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }
}