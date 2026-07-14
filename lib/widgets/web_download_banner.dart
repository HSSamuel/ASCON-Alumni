import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebDownloadBanner extends StatefulWidget {
  final Widget child;
  const WebDownloadBanner({super.key, required this.child});

  @override
  State<WebDownloadBanner> createState() => _WebDownloadBannerState();
}

class _WebDownloadBannerState extends State<WebDownloadBanner> {
  bool _isVisible = kIsWeb; 

  Future<void> _launchStore() async {
    final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.ascon.app');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return widget.child;

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    
    // ✅ Emphasize PWA Instruction tailored to the target platform
    String instructionText = "Install Web App: Click the install icon (🖥️⬇️) in your browser address bar.";
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      instructionText = "Install Web App: Tap Share ⬆️ then 'Add to Home Screen'.";
    } else if (isAndroid) {
      instructionText = "Install Web App: Tap browser menu (⋮) then 'Install app', or get the Mobile App.";
    }

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
                      errorBuilder: (c, e, s) => const Icon(Icons.android, color: Colors.white)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ASCON Alumni Web App",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          instructionText,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Keep Google Play for Android as an alternative to the PWA
                  if (isAndroid)
                    ElevatedButton(
                      onPressed: _launchStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B5E3A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text("APP", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _isVisible = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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