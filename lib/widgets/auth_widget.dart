import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/signup_screen.dart';  // ✅ CHANGE: Import SignupScreen
import '../screens/profile/profile_screen.dart';

class AuthIconWidget extends StatelessWidget {
  const AuthIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return GestureDetector(
      onTap: () {
        if (authProvider.isLoggedIn) {
          // User is logged in - go to profile
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        } else {
          // ✅ CHANGE: User not logged in - go to SignupScreen (not LoginScreen)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignupScreen()),
          );
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF5E0006).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          authProvider.isLoggedIn ? Icons.person : Icons.person_outline,
          color: const Color(0xFF5E0006),
          size: 20,
        ),
      ),
    );
  }
}