import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier{
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;

  Future<UserProfile?> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.login(email, password);

      if (profile == null) {
        errorMessage = 'Login failed or user profile not found';
        return null;
      }

      // Return user profile to LoginPage
      // LoginPage will check role and navigate
      return profile;

    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth specific errors
      if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password';
      } else {
        errorMessage = e.message ?? 'Login failed';
      }

      return null;
    } catch (e) {
      // Handle other unexpected errors
      errorMessage = 'Something went wrong';
      return null;
    } finally {
      // Stop loading after login finished
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    if (email.trim().isEmpty) {
      errorMessage = 'Please enter your email first';
      notifyListeners();
      return false;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      errorMessage = 'Failed to send password reset email';
      notifyListeners();
      return false;
    }
  }
}