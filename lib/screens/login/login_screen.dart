import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/screens/home/home_screen.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  // Check if user is already logged in

  // Handle login process
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final usersString = prefs.getString('users') ?? '[]';
      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
        json.decode(usersString),
      );

      // Find user with matching username and password
      final user = users.firstWhere(
        (u) =>
            u['username'] == _usernameController.text &&
            u['password'] == _passwordController.text,
        orElse: () => {},
      );

      if (user.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ناوی بەکارھێنەر یان وشەی نھێنی نادروستە'),
            ),
          );
        }
        return;
      }

      // Save user data locally
      final userData = {
        'username': user['username'],
        'role': user['role'] ?? 'user',
        'loginTime': DateTime.now().toIso8601String(),
      };

      await prefs.setString('userData', json.encode(userData));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(currentUser: userData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('چوونەژوورەوە سەرکەوتوو نەبوو: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        SizedBox(
          width: 200,
          height: 200,
          child: Image.asset("assets/images/logo.png"),
        ),

        const SizedBox(height: 8),
        Text(
          'بەخێربێیتەوە! تکایە بچۆ ژوورەوە بۆ بەردەوامبوون.',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.inter(fontSize: 17, color: kTextSecondaryColor),
        ),
        const SizedBox(height: 40),

        // Form Card
        Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUsernameField(),
                  const SizedBox(height: 20),
                  _buildPasswordField(),
                  const SizedBox(height: 30),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      keyboardType: TextInputType.text,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: InputDecoration(
        labelText: 'ناوی بەکارھێنەر',
        prefixIcon: const Icon(
          Icons.person_outline,
          color: kTextSecondaryColor,
        ),
        filled: true,
        fillColor: kBackgroundColor.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
      ),
      validator: (val) =>
          val == null || val.isEmpty ? 'تکایە ناوی بەکارھێنەر داخڵ بکە' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscureText,
      style: GoogleFonts.inter(color: kTextColor),
      decoration: InputDecoration(
        labelText: 'وشەی نھێنی',
        prefixIcon: const Icon(Icons.lock_outline, color: kTextSecondaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: kTextSecondaryColor,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        filled: true,
        fillColor: kBackgroundColor.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
      ),
      validator: (val) => val == null || val.length < 6
          ? 'وشەی نھێنی دەبێت لانیکەم ٦ پیت بێت'
          : null,
    );
  }
  // updateUsername("shram", "shram123");

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: kPrimaryColor.withOpacity(0.4),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : Text(
              'چوونەژوورەوە',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
