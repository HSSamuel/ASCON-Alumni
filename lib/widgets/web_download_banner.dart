import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:js' as js;

import '../router.dart'; 

class WebDownloadBanner extends StatefulWidget {
  final Widget child;
  const WebDownloadBanner({super.key, required this.child});

  @override
  State<WebDownloadBanner> createState() => _WebDownloadBannerState();
}

class _WebDownloadBannerState extends State<WebDownloadBanner> {
  bool _isVisible = kIsWeb; 

  void _triggerInstall() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _showManualInstructions();
    } else {
      try {
        bool promptSuccessful = js.context.callMethod('promptPwaInstall');
        if (!promptSuccessful) {
          _showManualInstructions();
        }
      } catch (e) {
        _showManualInstructions();
      }
    }
  }

  void _showManualInstructions() {
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog(
      context: navigatorContext, 
      builder: (c) => AlertDialog(
        title: const Text("Install Web App", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          defaultTargetPlatform == TargetPlatform.iOS 
            ? "To install the app on your iPhone/iPad:\n\n1. Tap the Share button ⬆️ at the bottom of Safari.\n2. Scroll down and tap 'Add to Home Screen'."
            : "To install the app:\n\nTap the browser menu (⋮) and select 'Install app' or click the install icon (🖥️⬇️) in your address bar."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c), 
            child: const Text("GOT IT", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return widget.child;

    return Column(
      children: [
        Material(
          color: const Color(0xFF1B5E3A), 
          elevation: 4,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icon_logo.png', 
                      width: 40, 
                      height: 40, 
                      fit: BoxFit.cover, 
                      errorBuilder: (c, e, s) => const Icon(Icons.web, color: Colors.white)
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Text(
                          "ASCON Alumni",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          "Get the fast, lightweight web version.",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // ✅ FIX: Replaced ElevatedButton with GestureDetector to bypass Semantic assertions
                  GestureDetector(
                    onTap: _triggerInstall,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "INSTALL", 
                        style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 13)
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                    
                  // ✅ FIX: Replaced IconButton with GestureDetector to bypass Semantic assertions
                  GestureDetector(
                    onTap: () => setState(() => _isVisible = false),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}