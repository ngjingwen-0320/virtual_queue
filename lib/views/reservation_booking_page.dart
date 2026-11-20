import '../utils/phone_number_utils.dart';
import '../widgets/malaysian_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mockpay_checkout_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/reservation_model.dart';
import '../viewmodels/reservation_viewmodel.dart';

class ReservationBookingPage extends StatefulWidget {
  final String restaurantId;
  final String brandId;
  final String restaurantName;

  const ReservationBookingPage({
    super.key,
    required this.restaurantId,
    required this.brandId,
    required this.restaurantName,
  });

  @override
  State<ReservationBookingPage> createState() => _ReservationBookingPageState();
}

class _ReservationBookingPageState extends State<ReservationBookingPage> {
  final ReservationViewModel _reservationViewModel = ReservationViewModel();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  bool bookingForOthers = false;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int selectedPax = 1;

  static const int depositPerPax = 10;
  int get totalDeposit => selectedPax * depositPerPax;

  final customerNameController = TextEditingController();

  final customerPhoneController = TextEditingController();

  final guestNameController = TextEditingController();

  final guestPhoneController = TextEditingController();

  final remarksController = TextEditingController();

  bool isSubmitting = false;
  String? _pendingReservationId;

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    guestNameController.dispose();
    guestPhoneController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> submitReservation() async {
    if (isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!validateReservationForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please complete all required fields.',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFFFF1F2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      );
      return;
    }

    try {
      if (selectedDate == null) {
        throw Exception('Please select a date.');
      }

      if (selectedTime == null) {
        throw Exception('Please select a time.');
      }

      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please login first.');
      }

      final reservationDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      if (DateTime.now().isAfter(
        reservationDateTime.subtract(const Duration(hours: 24)),
      )) {
        throw Exception(
          'Reservation must be made at least 24 hours in advance.',
        );
      }

      setState(() {
        isSubmitting = true;
      });

      final reservation = ReservationModel(
        reservationId: '',

        customerId: user.uid,

        customerName: customerNameController.text.trim(),

        customerPhone: PhoneNumberUtils.normalize(customerPhoneController.text),

        brandId: widget.brandId,

        restaurantId: widget.restaurantId,

        restaurantName: widget.restaurantName,

        bookingType: bookingForOthers ? 'OTHER' : 'SELF',

        guestName: bookingForOthers ? guestNameController.text.trim() : '',

        guestPhone: bookingForOthers
            ? PhoneNumberUtils.normalize(guestPhoneController.text)
            : '',

        pax: selectedPax,

        reservationDateTime: reservationDateTime,

        specialRequest: remarksController.text.trim(),

        status: 'PENDING',

        createdAt: DateTime.now(),
      );

      _pendingReservationId ??= FirebaseFirestore.instance
          .collection('reservations')
          .doc()
          .id;
      final reservationId = await _reservationViewModel.createReservation(
        reservation,
        reservationId: _pendingReservationId,
      );
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MockPayCheckoutPage(
            reservationId: reservationId,
            restaurantName: widget.restaurantName,
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking saved. You can check or resume your deposit in My Reservations.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,

      firstDate: DateTime.now(),

      lastDate: DateTime.now().add(const Duration(days: 365)),

      initialDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Widget buildField(
    String label,
    String hint,
    TextEditingController controller, {
    bool isRequired = false,
  }) {
    if (controller == customerPhoneController ||
        controller == guestPhoneController) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            MalaysianPhoneField(controller: controller, insetShadow: false),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8F8),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              // onChanged: (value) {
              //   setState(() {});
              // },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool validateReservationForm() {
    if (customerNameController.text.trim().isEmpty) return false;
    if (PhoneNumberUtils.validate(customerPhoneController.text) != null) {
      return false;
    }

    if (bookingForOthers) {
      if (guestNameController.text.trim().isEmpty) return false;
      if (PhoneNumberUtils.validate(guestPhoneController.text) != null) {
        return false;
      }
    }

    if (selectedDate == null) return false;
    if (selectedTime == null) return false;

    // Remarks is optional
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFB),

      appBar: AppBar(
        title: const Text('Reservation'),
        backgroundColor: const Color(0xFF115E59),
        foregroundColor: Colors.white,
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                widget.restaurantName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF006670),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      color: Color(0xFF006670),
                      size: 22,
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking For Others',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reserve a table for someone else',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Switch(
                      value: bookingForOthers,
                      activeThumbColor: const Color(0xFF006670),
                      onChanged: (value) {
                        setState(() {
                          bookingForOthers = value;

                          if (!value) {
                            guestNameController.clear();
                            guestPhoneController.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              ...[
                buildField(
                  'Your Name',
                  'Enter your full name',
                  customerNameController,
                ),

                buildField(
                  'Your Phone',
                  '127347838',
                  customerPhoneController,
                ),
              ],

              if (bookingForOthers) ...[
                buildField(
                  'Guest Name',
                  'Enter guest name',
                  guestNameController,
                ),

                buildField(
                  'Guest Phone',
                  '127347838',
                  guestPhoneController,
                ),
              ],

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Number of Guests',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F8F8),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),

                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedPax,
                        isExpanded: true,

                        items: List.generate(
                          8,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(
                              '${index + 1} Guest${index == 0 ? '' : 's'}',
                            ),
                          ),
                        ),

                        onChanged: (value) {
                          setState(() {
                            selectedPax = value!;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),

              buildField('Remarks', 'Any special requests?', remarksController),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reservation Date',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const SizedBox(height: 10),

                  InkWell(
                    onTap: selectDate,
                    borderRadius: BorderRadius.circular(40),

                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F8F8),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 3,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Color(0xFF006670),
                          ),

                          const SizedBox(width: 12),

                          Text(
                            selectedDate == null
                                ? 'Select Date'
                                : selectedDate.toString().split(' ')[0],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reservation Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 10),

                    InkWell(
                      onTap: selectTime,
                      borderRadius: BorderRadius.circular(40),

                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),

                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F8F8),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 3,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Color(0xFF006670),
                            ),

                            const SizedBox(width: 12),

                            Text(
                              selectedTime == null
                                  ? 'Select Time'
                                  : selectedTime!.format(context),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9F8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB2DFDB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined, color: Color(0xFF006670)),
                        SizedBox(width: 10),
                        Text(
                          'Reservation Deposit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006670),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deposit per person'),
                        const Text('RM 10.00'),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Number of guests ($selectedPax)'),
                        Text('× $selectedPax'),
                      ],
                    ),

                    const Divider(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Deposit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RM ${totalDeposit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006670),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006670),
                  ),

                  onPressed: isSubmitting ? null : submitReservation,

                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Submit Reservation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
