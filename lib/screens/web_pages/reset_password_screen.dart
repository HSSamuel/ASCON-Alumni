import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isSuccess = false;
  
  String? _errorMessage;

  final String baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'https://ascon-st50.onrender.com');

  Future<void> _handleSubmit() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _errorMessage = "Invalid or missing reset token.");
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords do not match!");
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': widget.token,
          'newPassword': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _isSuccess = true);
      } else {
        final data = json.decode(response.body);
        setState(() => _errorMessage = data['message'] ?? "Something went wrong.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Network error. Please try again.");
    } finally {
      setState(() => _isLoading = false);
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: _isSuccess ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logo.png', width: 80, errorBuilder: (c, e, s) => const SizedBox(height: 80)),
        const SizedBox(height: 20),
        const Text("Reset Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A))),
        const SizedBox(height: 8),
        const Text("Enter your new password below.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700], fontSize: 14), textAlign: TextAlign.center),
          ),

        if (widget.token == null || widget.token!.isEmpty)
          const Text("Error: Invalid Link.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        else ...[
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              hintText: "New Password",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: "Confirm Password",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E3A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Update Password", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF1B5E3A), size: 60),
        const SizedBox(height: 20),
        const Text("Success!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A))),
        const SizedBox(height: 10),
        const Text("Your password has been reset successfully.", style: TextStyle(color: Colors.grey)),
        
        Container(
          margin: const EdgeInsets.only(top: 30),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border.all(color: Colors.green[200]!),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Column(
            children: [
              Text("📱 Mobile App Users:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
              const SizedBox(height: 5),
              Text("Please return to the ASCON Alumni App to login with your new password.", textAlign: TextAlign.center, style: TextStyle(color: Colors.green[800], fontSize: 14)),
            ],
          ),
        ),
        
        const SizedBox(height: 25),
        const Divider(),
        const SizedBox(height: 15),
        TextButton(
          onPressed: () => context.go('/login'), 
          child: const Text("Login to Portal here", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}