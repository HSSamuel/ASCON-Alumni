// lib/screens/update_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateScreen extends StatelessWidget {
  final String playStoreUrl;

  const UpdateScreen({super.key, required this.playStoreUrl});

  Future<void> _launchStore() async {
    final Uri url = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // PopScope prevents the Android back button from dismissing this screen
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Alert Icon / Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 80,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Text Content
                Text(
                  "Update Required",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  "We've added new features and fixed some bugs to improve your experience. Please update the ASCON Alumni app to continue.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    height: 1.5,
                    color: subTextColor,
                  ),
                ),
                
                const Spacer(),
                
                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _launchStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "UPDATE NOW",
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}