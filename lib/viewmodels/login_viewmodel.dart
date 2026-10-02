import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier{
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  bool isEmailUnverified = false;

  Future<UserProfile?> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    isEmailUnverified = false;
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
      // if (e.code == 'invalid-email') {
      //   errorMessage = 'Invalid email format';
      // } else if (e.code == 'user-not-found') {
      //   errorMessage = 'No user found with this email';
      // } else if (e.code == 'wrong-password') {
      //   errorMessage = 'Wrong password';
      // } else if (e.code == 'invalid-credential') {
      //   errorMessage = 'Invalid email or password';
      // } else {
      //   errorMessage = e.message ?? 'Login failed';
      // }
      if (e.code == 'email-not-verified') {
        isEmailUnverified = true;
        errorMessage = e.message ?? 'Please verify your email address before logging in.';
      } else if (e.code == 'invalid-email') {
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

  /// Resends the verification email using credentials provided
  // Future<bool> resendVerificationEmail(String email, String password) async {
  //   if (email.trim().isEmpty || password.trim().isEmpty) {
  //     errorMessage = 'Please enter your email and password';
  //     notifyListeners();
  //     return false;
  //   }

  //   try {
  //     // Temporarily sign in to get the user object and trigger email resend
  //     final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
  //       email: email.trim(),
  //       password: password.trim(),
  //     );
      
  //     await result.user?.sendEmailVerification();
  //     await FirebaseAuth.instance.signOut(); // Ensure user is signed out afterwards
  //     return true;
  //   } catch (e) {
  //     errorMessage = 'Failed to resend verification email.';
  //     notifyListeners();
  //     return false;
  //   }
  // }

  Future<bool> resendVerificationEmail(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      errorMessage = 'Please enter both email and password to resend.';
      notifyListeners();
      return false;
    }

    try {
      await _authService.resendVerificationEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        errorMessage = 'Please wait a few moments before requesting another email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Incorrect password. Please verify your credentials.';
      } else {
        errorMessage = e.message ?? 'Failed to resend verification email.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
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