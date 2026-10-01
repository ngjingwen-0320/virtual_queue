// views/user_profile_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../viewmodels/user_profile_viewmodel.dart';
import 'saved_restaurants_page.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final UserProfileViewModel _viewModel = UserProfileViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_updateUiState);
    _viewModel.fetchRealUserData(); 
  }

  @override
  void dispose() {
    _viewModel.removeListener(_updateUiState);
    super.dispose();
  }

  void _updateUiState() {
    if (mounted) setState(() {});
  }

  Future<void> _handleLogoutClick() async {
    final bool confirm = await _showLogoutConfirmationDialog() ?? false;
    if (!confirm) return;

    final bool success = await _viewModel.logoutUser();
    if (success && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<bool?> _showSaveConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Save Changes', 
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, color: Color(0xFF134E4A)),
        ),
        content: const Text(
          'Are you sure you want to update your profile with these new details?', 
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF48626E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF48626E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Save', 
              style: TextStyle(color: Color(0xFF115E59), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24, left: 24, right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Clear system soft keyboard heights
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Update Password',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF134E4A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF48626E)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Current Password
                const Text('Current Password', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF48626E))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter current account password',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                  ),
                  validator: (v) => v!.isEmpty ? 'Please enter your current password to proceed' : null,
                ),
                const SizedBox(height: 20),

                // New Password
                const Text('New Password', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF48626E))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Minimum 8 characters',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                  ),
                  validator: (v) => v!.length < 8 ? 'Password must be at least 8 characters long' : null,
                ),
                const SizedBox(height: 20),

                // Confirm New Password
                const Text('Confirm New Password', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF48626E))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Retype your new password exactly',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                  ),
                  validator: (v) => v != newPasswordController.text ? 'The matching confirmation password does not match' : null,
                ),
                const SizedBox(height: 32),

                // Save Call Action Button 
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF115E59),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        // 1. Run the network action background task first *before* throwing away the bottom sheet view
                        final String? errorMsg = await _viewModel.changePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text.trim(),
                        );

                        // 2. Dismiss modal bottom layout framework panel safely
                        if (context.mounted) Navigator.pop(context);

                        // 3. Prevent crashing if state was destroyed mid-network request transition
                        if (!mounted) return;

                        if (errorMsg == null) {
                          // 🟢 PASSWORD CHANGED SUCCESSFULLY
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Password successfully changed!', 
                                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              backgroundColor: Color(0xFF115E59),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } else {
                          // 🔴 PASSWORD CHANGE FAILED NOTICE
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      // 'Password change failed: $errorMsg', 
                                      'Password change failed. Please try again.',
                                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Update Password', 
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🛠️ OPENS THE EDIT BOTTOM SHEET FORM (Keeps your core UI completely pristine)
  void _showEditProfileBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _viewModel.userDisplayName);
    // final phoneController = TextEditingController(text: _viewModel.userPhone);

    final phoneController = TextEditingController(text: _viewModel.userPhone.replaceFirst('+60', ''));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Keeps text fields clear of keyboard overlay
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Personal Details',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF48626E)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Name Field Input
                const Text(
                  'Full Name',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF48626E)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF006670), width: 1.5)),
                  ),
                  validator: (value) => value!.trim().isEmpty ? 'Name cannot be blank' : null,
                ),
                const SizedBox(height: 20),

                // Phone Field Input
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', 
                    fontSize: 13, 
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF48626E),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // 🚫 Blocks any spaces, symbols, or alphabetic inputs
                    LengthLimitingTextInputFormatter(10),   // 🛑 Restricts the input field strictly to a maximum of 10 digits
                  ],
                  decoration: InputDecoration(
                    // hintText: '123456789', // Example hint text for 9 or 10 digits
                    // 🇲🇾 FIXED PREFIX LABEL: Lock (+60) at the front of the input field
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+60',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF48626E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E9EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF006670), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF115E59),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        
                        // 🎯 PLACE THE PHONE VALIDATION HERE (Gatekeeper)
                        if (phoneController.text.length < 9) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Phone number must be at least 9 digits long.', 
                                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          return; // 🛑 Stop execution right here
                        }

                        // 1. Ask for confirmation before updating Firestore
                        final bool confirmSave = await _showSaveConfirmationDialog() ?? false;
                        if (!confirmSave) return; // Exit if they hit Cancel

                        // 2. Close bottom drawer view form if confirmed
                        if (context.mounted) Navigator.pop(context); 
                        
                        // 🇲🇾 Attach the +60 country code prefix right here to the payload
                        final Map<String, dynamic> clearPayload = {
                          'name': nameController.text.trim(),
                          'phone': '+60${phoneController.text.trim()}', // 🚀 Saved safely as "+60123456789"
                        };

                        // 3. Process backend write task
                        final bool saved = await _viewModel.updateCustomerProfile(clearPayload);
                        
                        // 4. Alert user with a success alert message 
                        if (saved && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Profile changes successfully saved!', 
                                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              backgroundColor: Color(0xFF115E59),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showLogoutConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your session and sign out?', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF48626E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6FAFB),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF006670))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.menu_rounded, color: Color.fromARGB(0, 17, 94, 89), size: 24),
                onPressed: () {},
              ),
              const Text(
                'VQ',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF134E4A),
                  letterSpacing: -0.6,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E9EA),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x1A006670), width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              )
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar Structure
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E9EA),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF115E59), width: 3),
                    ),
                    child: const Icon(Icons.person, size: 54, color: Color(0xFF115E59)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 👥 Real Firestore Data Fields
            Text(
              _viewModel.userDisplayName, 
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF171C1D)),
            ),
            Text(
              _viewModel.userJoinedDate, 
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF48626E)),
            ),
            const SizedBox(height: 32),

            // Account Settings Bento Group
            Container(
              clipBehavior: Clip.antiAlias, 
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: const Color(0x1ABD8C9CB)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Color(0xFF006670)),
                    title: const Text('Email Address', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF48626E))),
                    subtitle: Text(_viewModel.userEmail, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF171C1D))),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0x0C006670)),
                  
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Color(0xFF006670)),
                    title: const Text('Phone Number', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF48626E))),
                    subtitle: Text(
                      _viewModel.userPhone.isEmpty ? 'Not Provided' : _viewModel.userPhone, 
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF171C1D)),
                    ),
                  ),
                  // 📐 Re-added 'indent: 56' here to keep alignment clean and perfectly uniform
                  const Divider(height: 1, indent: 56, color: Color(0x0C006670)),

                  // ⭐ Outstanding Edit Block
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F7F7), // Gentle brand background tint
                    ),
                    child: ListTile(
                      onTap: _showEditProfileBottomSheet,
                      leading: const Icon(Icons.mode_edit_outline_outlined, color: Color(0xFF115E59)),
                      title: const Text(
                        'Edit Personal Profile', 
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF115E59)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF115E59), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: const Color(0x1ABD8C9CB)), // Mirrors details card frame border perfectly
              ),
              child: ListTile(
                onTap: _showChangePasswordBottomSheet,
                leading: const Icon(Icons.lock_reset_outlined, color: Color(0xFF115E59)),
                title: const Text(
                  'Change Password', 
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF171C1D)),
                ),
                trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF115E59), size: 20),
              ),
            ),
            const SizedBox(height: 32),

            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: const Color(0x1ABD8C9CB)), 
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // ⬇️ Ensure NO 'const' is here either
                      builder: (context) => SavedRestaurantsPage(),
                    ),
                  );
                },
                leading: const Icon(Icons.bookmark_rounded, color: Color(0xFF115E59)),
                title: const Text(
                  'Saved Restaurants', 
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF171C1D)),
                ),
                trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF115E59), size: 20),
              ),
            ),

            const SizedBox(height: 40),

            // 🛑 LOGOUT BUTTON BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleLogoutClick,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F2), 
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFFFECDD3), width: 1.5),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}