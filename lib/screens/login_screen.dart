import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isReader = true;
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _toggleUserType() {
    setState(() {
      _isReader = !_isReader;
      _identifierController.clear();
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.login(
      _isReader ? 'reader' : 'admin',
      _identifierController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      if (result['status'] == 'error') {
        _errorMessage = result['message'];
      } else {
        final userType = authProvider.userType;
        Navigator.pushReplacementNamed(
          context,
          userType == 'reader' ? '/reader_dashboard' : '/admin_dashboard',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeIn(
          duration: Duration(milliseconds: 1000),
          child: Container(
            padding: EdgeInsets.all(20),
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CampusLib',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('Reader', style: GoogleFonts.poppins(color: _isReader ? Colors.white : AppColors.primary)),
                      selected: _isReader,
                      selectedColor: AppColors.primary,
                      onSelected: (_) => _toggleUserType(),
                    ),
                    SizedBox(width: 10),
                    ChoiceChip(
                      label: Text('Admin', style: GoogleFonts.poppins(color: !_isReader ? Colors.white : AppColors.primary)),
                      selected: !_isReader,
                      selectedColor: AppColors.primary,
                      onSelected: (_) => _toggleUserType(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: _isReader ? 'Library Card Number' : 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(_isReader ? Icons.card_membership : Icons.email, color: AppColors.accent),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock, color: AppColors.accent),
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator(color: AppColors.accent)
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}