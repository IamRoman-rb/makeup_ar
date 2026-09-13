import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CatalogScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error al iniciar sesión', style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Text(
                'GLAMOUR',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37), // Dorado
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 50),
              Text(
                'Welcome Back',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please enter your details to sign in.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email or Username',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A1A1A))),
                ),
              ),
              const SizedBox(height: 20),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A1A1A))),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 30),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('LOG IN', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.inter(color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}