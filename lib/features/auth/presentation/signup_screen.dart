import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ar_makeup_app/app_services.dart';
import 'package:ar_makeup_app/features/auth/domain/app_user.dart';
import 'package:ar_makeup_app/features/auth/presentation/auth_messages.dart';
import 'package:ar_makeup_app/features/catalog/presentation/catalog_screen.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_document.dart';
import 'package:ar_makeup_app/features/legal/domain/legal_info.dart';
import 'package:ar_makeup_app/features/legal/presentation/legal_document_screen.dart';
import 'package:ar_makeup_app/shared/data/picked_files.dart';
import 'package:ar_makeup_app/l10n/app_localizations.dart'; // <-- 1. Importación del traductor
import 'package:ar_makeup_app/features/profile/presentation/profile_labels.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.legalInfo = const LegalInfo.fromEnvironment(), this.clock = DateTime.now});

  /// Edad mínima y datos de los textos legales (por `--dart-define`).
  final LegalInfo legalInfo;
  final DateTime Function() clock;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _selectedDate;
  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Aceptó la política de privacidad y los términos (obligatorio).
  bool _acceptedLegal = false;

  // Variables para la foto de perfil
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  String _selectedSkinType = 'Combined';
  String _selectedSkinTone = 'Light';
  final Set<String> _selectedPreferences = {};

  // Valores internos que se guardan en la base (no se traducen: se traducen al mostrarlos)
  final List<String> skinTypes = ['Combined', 'Oily', 'Dry', 'Sensitive'];
  final List<Map<String, dynamic>> skinTones = [
    {'name': 'Light', 'color': const Color(0xFFFCE5D8)},
    {'name': 'Medium', 'color': const Color(0xFFD29E7D)},
    {'name': 'Tan', 'color': const Color(0xFFA06540)},
    {'name': 'Deep', 'color': const Color(0xFF4A2F1D)},
  ];
  final List<String> preferences = ['Natural', 'Glamour', 'Minimalist', 'Bold', 'Skincare Focus'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // Foto elegida y nunca guardada (se fue sin registrarse): fuera de la caché.
    final picked = _imageFile;
    if (picked != null) unawaited(discardPickedFile(picked.path));
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Se achica de entrada; al guardarla se vuelve a codificar sin metadatos
    // (ProfilePhotoStore.save).
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1A1A1A))),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!; // Instancia del traductor para los errores

    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fillRequiredFields)));
      return;
    }
    if (!_acceptedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.signupMustAccept)));
      return;
    }
    final now = widget.clock();
    final minimumAge = widget.legalInfo.minimumAge;
    if (AgePolicy.check(birthDate: _selectedDate, now: now, minimumAge: minimumAge) == AgeCheck.underMinimum) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.signupUnderMinimumAge(minimumAge))));
      return;
    }
    final birthDate = _selectedDate;

    setState(() => _isLoading = true);
    try {
      final auth = AppServices.auth;
      final profile = UserProfile(
        name: _nameController.text.trim(),
        birthDate: birthDate,
        // Se calcula de la fecha: no se pide dos veces el mismo dato.
        age: birthDate == null ? 0 : AgePolicy.ageAt(birthDate, now),
        skinType: _selectedSkinType,
        skinTone: _selectedSkinTone,
        preferences: _selectedPreferences.toList(),
      );
      final failure = await auth.signUp(
        email: _emailController.text,
        password: _passwordController.text.trim(),
        profile: profile,
      );
      if (failure != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authFailureText(l10n, failure))));
        return;
      }
      final user = auth.currentUser;
      if (user == null) return;
      unawaited(AppServices.afterSignIn(user.id));

      // La foto se copia a la carpeta de la app. Si falla, la cuenta queda
      // creada igual sin foto, y se avisa.
      var photoFailed = false;
      final imageFile = _imageFile;
      if (imageFile != null) {
        try {
          final path = await AppServices.photos.save(user.id, imageFile.path);
          await auth.updateProfile(profile.copyWith(photoPath: path));
        } catch (e) {
          debugPrint('Foto de perfil no guardada (${e.runtimeType})');
          photoFailed = true;
        } finally {
          await discardPickedFile(imageFile.path);
        }
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CatalogScreen()), (route) => false);
        if (photoFailed) messenger.showSnackBar(SnackBar(content: Text(l10n.signupPhotoFailed)));
      }
    } catch (e) {
      // Error inesperado de la base. Sin el detalle en pantalla: puede traer
      // rutas internas o datos de la cuenta.
      debugPrint('Registro falló (${e.runtimeType})');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.registrationError)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // <-- 2. Instancia del traductor para la vista

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF1A1A1A))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(l10n.createProfile, style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
                  const SizedBox(height: 10),
                  Text(l10n.joinSubtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // WIDGET DE FOTO DE PERFIL
            Center(
              child: Semantics(
                button: true,
                label: l10n.profilePhotoA11y,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _avatarImage(),
                        child: _imageFile == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
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
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(l10n.profilePhotoNotice, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 22),

            _buildTextField(l10n.fullName, 'Jane Doe', _nameController),
            const SizedBox(height: 15),
            _buildTextField(l10n.email, 'jane@example.com', _emailController),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.dob,
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
            const SizedBox(height: 15),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l10n.password,
                labelStyle: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A1A1A))),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Tipo de Piel
            Text(l10n.skinType, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: skinTypes.map((type) {
                final isSelected = _selectedSkinType == type;
                return ChoiceChip(
                  label: Text(skinTypeLabel(l10n, type), style: GoogleFonts.inter(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade600, fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedSkinType = type),
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300)),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            // Tono de Piel
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
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: tone['color'], shape: BoxShape.circle, border: Border.all(color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent, width: 2)),
                      ),
                      const SizedBox(height: 8),
                      Text(skinToneLabel(l10n, tone['name'] as String), style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            // Gustos Personales
            Text(l10n.personalTastes, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: preferences.map((pref) {
                final isSelected = _selectedPreferences.contains(pref);
                return FilterChip(
                  label: Text(preferenceLabel(l10n, pref), style: GoogleFonts.inter(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade600, fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selected ? _selectedPreferences.add(pref) : _selectedPreferences.remove(pref);
                    });
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300)),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            Text(l10n.signupLocalNotice, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('accept-legal'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF1A1A1A),
              value: _acceptedLegal,
              onChanged: (value) => setState(() => _acceptedLegal = value ?? false),
              title: Text(l10n.signupAcceptLegal, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1A1A1A))),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _openLegal(LegalDocumentKind.privacy),
                  child: Text(l10n.privacyPolicy),
                ),
                TextButton(
                  onPressed: () => _openLegal(LegalDocumentKind.terms),
                  child: Text(l10n.termsOfService),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.createAccount, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// Decodificada al tamaño del círculo, no a la de la foto.
  ImageProvider? _avatarImage() {
    final picked = _imageFile;
    return picked == null ? null : ResizeImage(FileImage(picked), width: 300);
  }

  void _openLegal(LegalDocumentKind kind) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(kind: kind, info: widget.legalInfo)),
      );

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade300),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A1A1A))),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }
}