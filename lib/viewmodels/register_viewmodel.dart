import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class RegisterViewmodel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;

  Future<UserProfile?> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
        errorMessage = 'Please fill in all fields';
        return null;
      }
      if (password != confirmPassword) {
        errorMessage = 'Passwords do not match';
        return null;
      }
      return await _authService.registerCustomer(
          name: name,
          email: email,
          phone: phone,
          password: password
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email already in use';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else {
        errorMessage = e.message ?? 'Registration failed';
      }
      return null;
    } catch (e) {
      errorMessage = 'Something went wrong';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<UserProfile?> registerRestaurant({
    required String restaurantName,
    required String businessRegistrationNo,
    required String ownerName,
    required String ownerEmail,
    required String ownerPhone,
    required String password,
    required String confirmPassword,
    required List<Map<String, String>> branches,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (restaurantName.isEmpty ||
          businessRegistrationNo.isEmpty ||
          ownerName.isEmpty ||
          ownerEmail.isEmpty ||
          ownerPhone.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty ||
          branches.isEmpty) {
        errorMessage = 'Please fill in all fields';
        return null;
      }

      if (password != confirmPassword) {
        errorMessage = 'Passwords do not match';
        return null;
      }

      for (final branch in branches) {
        if ((branch['branch_name'] ?? '').isEmpty || (branch['address'] ?? '').isEmpty) {
          errorMessage = 'Please fill in all branch details';
          return null;
        }
      }

      return await _authService.registerRestaurant(
        restaurantName: restaurantName,
        businessRegistrationNo: businessRegistrationNo,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        ownerPhone: ownerPhone,
        password: password,
        branches: branches,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email already in use';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else {
        errorMessage = e.message ?? 'Registration failed';
      }

      return null;
    } catch (e) {
      errorMessage = 'Something went wrong';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}