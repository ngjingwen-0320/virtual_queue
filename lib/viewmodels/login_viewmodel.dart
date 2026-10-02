import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier{
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  bool isEmailUnverified = false;

  String? pendingUid;
  String? pendingEmail;
  String? pendingPassword;

  bool get isAwaitingOtp => pendingUid != null && pendingEmail != null;

  Future<bool> requestOtp(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      errorMessage = 'Please enter both email and password';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    isEmailUnverified = false;
    notifyListeners();

    try {
      final authData = await _authService.sendLoginOtp(email, password);
      pendingUid = authData['uid'];
      pendingEmail = authData['email'];
      pendingPassword = password;
      return true;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-not-verified') {
        isEmailUnverified = true;
        errorMessage = e.message ?? 'Please verify your email address before logging in.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password.';
      } else if (e.code == 'email-send-failed') {
        errorMessage = e.message ?? 'Failed to send OTP email. Please try again.';
      } else {
        errorMessage = e.message ?? 'Authentication failed.';
      }
      return false;

    } catch (e) {
      errorMessage = 'Failed to generate OTP. Please try again.';
      return false;

    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Resends OTP using cached temporary credentials
  Future<bool> resendOtp() async {
    if (pendingEmail == null || pendingPassword == null) {
      errorMessage = 'Session expired. Please log in again.';
      notifyListeners();
      return false;
    }
    return await requestOtp(pendingEmail!, pendingPassword!);
  }

  /// Verifies entered OTP against Firestore document and logs user in
  Future<UserProfile?> verifyOtp(String enteredOtp) async {
    if (pendingUid == null || pendingEmail == null || pendingPassword == null) {
      errorMessage = 'Session expired. Please log in again.';
      notifyListeners();
      return null;
    }

    if (enteredOtp.trim().isEmpty) {
      errorMessage = 'Please enter the OTP code.';
      notifyListeners();
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.verifyOtpAndLogin(
        uid: pendingUid!,
        email: pendingEmail!,
        password: pendingPassword!,
        enteredOtp: enteredOtp,
      );

      if (profile == null) {
        errorMessage = 'User profile not found.';
        return null;
      }

      // Clear sensitive memory state upon success
      cancelOtpSession();
      return profile;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-attempts' || e.code == 'otp-not-found') {
        // Clear session on fatal OTP errors so user is forced to re-authenticate
        cancelOtpSession();
      }

      if (e.code == 'invalid-otp') {
        errorMessage = e.message ?? 'Incorrect OTP entered.';
      } else if (e.code == 'otp-expired') {
        errorMessage = 'OTP has expired. Please tap "Resend OTP".';
      } else if (e.code == 'too-many-attempts') {
        errorMessage = 'Maximum attempts reached. Please request a new code.';
      } else {
        errorMessage = e.message ?? 'OTP verification failed.';
      }
      return null;

    } catch (e) {
      errorMessage = 'An error occurred during verification.';
      return null;

    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Clears temporary credentials if user navigates away or cancels OTP modal
  void cancelOtpSession() {
    pendingUid = null;
    pendingEmail = null;
    pendingPassword = null;
    errorMessage = null;
    notifyListeners();
  }

  // Future<UserProfile?> login(String email, String password) async {
  //   isLoading = true;
  //   errorMessage = null;
  //   isEmailUnverified = false;
  //   notifyListeners();

  //   try {
  //     final profile = await _authService.login(email, password);

  //     if (profile == null) {
  //       errorMessage = 'Login failed or user profile not found';
  //       return null;
  //     }

  //     // Return user profile to LoginPage
  //     // LoginPage will check role and navigate
  //     return profile;

  //   } on FirebaseAuthException catch (e) {
  //     // Handle Firebase Auth specific errors
  //     // if (e.code == 'invalid-email') {
  //     //   errorMessage = 'Invalid email format';
  //     // } else if (e.code == 'user-not-found') {
  //     //   errorMessage = 'No user found with this email';
  //     // } else if (e.code == 'wrong-password') {
  //     //   errorMessage = 'Wrong password';
  //     // } else if (e.code == 'invalid-credential') {
  //     //   errorMessage = 'Invalid email or password';
  //     // } else {
  //     //   errorMessage = e.message ?? 'Login failed';
  //     // }
  //     if (e.code == 'email-not-verified') {
  //       isEmailUnverified = true;
  //       errorMessage = e.message ?? 'Please verify your email address before logging in.';
  //     } else if (e.code == 'invalid-email') {
  //       errorMessage = 'Invalid email format';
  //     } else if (e.code == 'user-not-found') {
  //       errorMessage = 'No user found with this email';
  //     } else if (e.code == 'wrong-password') {
  //       errorMessage = 'Wrong password';
  //     } else if (e.code == 'invalid-credential') {
  //       errorMessage = 'Invalid email or password';
  //     } else {
  //       errorMessage = e.message ?? 'Login failed';
  //     }

  //     return null;
  //   } catch (e) {
  //     // Handle other unexpected errors
  //     errorMessage = 'Something went wrong';
  //     return null;
  //   } finally {
  //     // Stop loading after login finished
  //     isLoading = false;
  //     notifyListeners();
  //   }
  // }

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