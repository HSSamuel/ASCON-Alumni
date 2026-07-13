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
  // Only show the banner if the app is running on the web
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

    // ✅ Detect if the user is on an Apple device (where custom install buttons are blocked)
    final isAppleDevice = defaultTargetPlatform == TargetPlatform.iOS || 
                          defaultTargetPlatform == TargetPlatform.macOS;

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
                          "ASCON Connect",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        // ✅ Dynamically show PWA instructions for iOS, and App info for Android
                        Text(
                          isAppleDevice 
                              ? "Install web app: Tap Share ⬆️ then 'Add to Home Screen'."
                              : "Get the official mobile app for full call features.",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // ✅ Only show the Google Play "GET" button if NOT on an Apple device
                  if (!isAppleDevice)
                    ElevatedButton(
                      onPressed: _launchStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B5E3A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text("GET", style: TextStyle(fontWeight: FontWeight.bold)),
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
        // The rest of your app renders below the banner
        Expanded(child: widget.child),
      ],
    );
  }
}