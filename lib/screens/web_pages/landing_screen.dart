import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      debugPrint("Could not launch $url");
    }
  }

  Future<void> _handleProceed(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_notification_prompt') ?? false;
    
    if (!context.mounted) return;

    if (!hasSeen) {
      context.go('/notification_permission', extra: '/login');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Nav Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo.png', width: 40, height: 40),
                        const SizedBox(width: 12),
                        const Text("ASCON Alumni", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A))),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1B5E3A),
                        side: const BorderSide(color: Colors.grey),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () => _handleProceed(context),
                      child: const Text("Proceed", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isDesktop = constraints.maxWidth > 800;
                            
                            Widget textContent = Column(
                              mainAxisSize: MainAxisSize.min, 
                              crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                              children: [
                                // ✅ FIX: Used Text.rich to make only "ASCON" green
                                Text.rich(
                                  const TextSpan(
                                    children: [
                                      TextSpan(text: "Your "),
                                      TextSpan(
                                        text: "ASCON\n", 
                                        style: TextStyle(color: Color(0xFF1B5E3A)) // Green color applied here
                                      ),
                                      TextSpan(text: "Network,\nAnywhere."),
                                    ],
                                  ),
                                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                                  style: TextStyle(fontSize: isDesktop ? 56 : 40, height: 1.1, fontWeight: FontWeight.w900, color: Colors.black87),
                                ),
                                const SizedBox(height: 20),
                                Text("Connect with fellow graduates, find opportunities, and stay updated with the latest from the Administrative Staff College of Nigeria.", 
                                  textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                                  style: const TextStyle(fontSize: 18, color: Colors.grey, height: 1.5)
                                ),
                                const SizedBox(height: 30),
                                Wrap(
                                  spacing: 16, runSpacing: 16,
                                  alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
                                  children: [
                                    _storeButton(Icons.android, "GET IT ON", "Google Play", () => _launchUrl("https://play.google.com/store/apps/details?id=com.ascon.app")),
                                    _storeButton(Icons.apple, "Download on the", "App Store", () => _launchUrl("https://apps.apple.com/app/idYOUR_APP_ID")),
                                  ],
                                )
                              ],
                            );

                            Widget imageContent = Container(
                              margin: EdgeInsets.only(top: isDesktop ? 0 : 40),
                              width: 250, height: 500,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: Colors.black87, width: 8),
                                image: const DecorationImage(image: AssetImage('assets/app-screenshot.png'), fit: BoxFit.cover),
                              ),
                            );

                            return isDesktop 
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.center, 
                                    children: [
                                      Expanded(child: textContent),
                                      const SizedBox(width: 60),
                                      imageContent
                                    ]
                                  )
                                : Column(
                                    children: [
                                      textContent, 
                                      imageContent
                                    ]
                                  );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/logo.png', width: 30, height: 30),
                                const SizedBox(width: 10),
                                Text("© ${DateTime.now().year} ASCON Alumni.", style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeButton(IconData icon, String subtitle, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, 
              children: [
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1)),
              ],
            )
          ],
        ),
      ),
    );
  }
}