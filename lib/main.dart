import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_database/constans/colors.dart';
import 'package:solar_database/screens/login/login_screen.dart';
import 'package:solar_database/screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Create default admin user if no users exist
    final usersString = prefs.getString('users');
    if (usersString == null || usersString == '[]') {
      final defaultUsers = [
        {
          'username': 'admin',
          'password': 'admin123',
          'role': 'admin',
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];
      await prefs.setString('users', json.encode(defaultUsers));
    }

    final userDataString = prefs.getString('userData');

    if (userDataString != null) {
      _currentUser = Map<String, dynamic>.from(json.decode(userDataString));
    } else {
      // fallback: just username string saved
      final username = prefs.getString('username');
      if (username != null) {
        _currentUser = {'username': username};
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Solar Database',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        // ... your existing theme code ...
      ),
      home: _currentUser != null
          ? HomeScreen(currentUser: _currentUser!)
          : const LoginScreen(),
    );
  }
}
