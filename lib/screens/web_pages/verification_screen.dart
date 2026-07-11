import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VerificationScreen extends StatefulWidget {
  final String id;
  const VerificationScreen({super.key, required this.id});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String _status = 'loading'; // 'loading', 'valid', 'invalid'
  Map<String, dynamic>? _data;
  
  // Replace with your actual production URL or dotenv logic
  final String baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'https://ascon-st50.onrender.com');

  @override
  void initState() {
    super.initState();
    _verifyUser();
  }

  Future<void> _verifyUser() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/directory/verify/${widget.id}'));
      
      if (response.statusCode == 200) {
        setState(() {
          _data = json.decode(response.body);
          _status = 'valid';
        });
      } else {
        setState(() => _status = 'invalid');
      }
    } catch (e) {
      setState(() => _status = 'invalid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', width: 80, errorBuilder: (c, e, s) => const SizedBox(height: 80)),
                const SizedBox(height: 20),
                
                if (_status == 'loading') ...[
                  const CircularProgressIndicator(color: Color(0xFF1B5E3A)),
                  const SizedBox(height: 15),
                  const Text("Verifying Credentials...", style: TextStyle(color: Colors.grey)),
                ],

                if (_status == 'invalid') ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      border: Border.all(color: Colors.red[700]!, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("❌ INVALID ID", style: TextStyle(color: Colors.red[700], fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Text("The ID ${widget.id} could not be verified in our database.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text("Please contact the ASCON Secretariat.", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                ],

                if (_status == 'valid' && _data != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E3A).withOpacity(0.05),
                      border: Border.all(color: const Color(0xFF1B5E3A), width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("✅ VERIFIED ALUMNUS", style: TextStyle(color: Color(0xFF1B5E3A), fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1B5E3A), width: 5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: CircleAvatar(
                      radius: 65,
                      backgroundImage: (_data!['profilePicture'] != null && _data!['profilePicture'].toString().length > 10)
                          ? NetworkImage(_data!['profilePicture'])
                          : const NetworkImage('https://via.placeholder.com/150'),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  Text(_data!['fullName']?.toString().toUpperCase() ?? "UNKNOWN USER", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87), textAlign: TextAlign.center),
                  
                  Container(height: 2, width: 50, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 15)),
                  
                  _buildInfoRow("Programme", _data!['programmeTitle'] ?? "N/A"),
                  _buildInfoRow("Class Set", _data!['yearOfAttendance']?.toString() ?? "...."),
                  
                  const SizedBox(height: 12),
                  const Text("ALUMNI ID", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    child: Text(_data!['alumniId'] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                  
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_data!['status'] == 'Active') ? const Color(0xFF1B5E3A) : Colors.red[700],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text("${_data!['status']?.toString().toUpperCase() ?? 'ACTIVE'} MEMBER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  
                  const SizedBox(height: 30),
const Text(
  "Administrative Staff College of Nigeria (ASCON)", 
  textAlign: TextAlign.center, // ✅ ADDED THIS LINE
  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}