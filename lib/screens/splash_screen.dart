// lib/screens/splash_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/auth_service.dart';
import '../router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAppStatus();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _animationController.forward();
  }

  // ✅ Helper method to compare version strings (e.g., "1.0.5" vs "2.0.0")
  bool _isVersionOutdated(String currentVersion, String minRequired) {
    List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
    List<int> requiredParts = minRequired.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      int curr = currentParts.length > i ? currentParts[i] : 0;
      int req = requiredParts.length > i ? requiredParts[i] : 0;
      
      if (curr < req) return true; // Current is older
      if (curr > req) return false; // Current is newer
    }
    return false; // Versions are identical
  }

  Future<void> _checkAppStatus() async {
    // Ensure the animation has time to play
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // ==========================================
    // 1. CHECK APP VERSION FIRST
    // ==========================================
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/app-version');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final minRequired = data['data']['minRequiredVersion'];
          final playStoreUrl = data['data']['playStoreUrl'];

          if (_isVersionOutdated(currentVersion, minRequired)) {
            if (!mounted) return;
            context.go('/update', extra: playStoreUrl);
            return; // 🛑 Halt further execution, trap them on the update screen
          }
        }
      }
    } catch (e) {
      // If the network drops or the server is momentarily unreachable, 
      // we gracefully fail open and let them into the app so they aren't locked out offline.
      debugPrint("Version check failed or bypassed: $e");
    }

    if (!mounted) return;

    // ==========================================
    // 2. PROCEED TO STANDARD AUTH CHECKS
    // ==========================================
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;
    final authService = AuthService();
    final bool isLoggedIn = await authService.isSessionValid();

    if (!mounted) return;

    final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    final bool isStillOnSplash = currentPath == '/';

    if (!isStillOnSplash) return; 

    if (isLoggedIn) {
      context.go('/home');
    } else if (!hasSeenPrompt) {
      context.go('/notification_permission', extra: '/login');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/splash_logo_with_text.png', 
                      width: 250, 
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.school,
                          size: 100,
                          color: primaryColor,
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor), 
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}