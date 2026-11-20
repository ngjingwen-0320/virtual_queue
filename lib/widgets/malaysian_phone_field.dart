import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import '../utils/phone_number_utils.dart';

class MalaysianPhoneInputFormatter extends TextInputFormatter {
  const MalaysianPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final national = PhoneNumberUtils.nationalInput(newValue.text);
    if (national == null) return oldValue;
    final caret =
        (newValue.selection.extentOffset +
                national.length -
                newValue.text.length)
            .clamp(0, national.length)
            .toInt();
    return TextEditingValue(
      text: national,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

class _InsetPhoneBorder extends OutlineInputBorder {
  final bool insetShadow;
  const _InsetPhoneBorder({
    this.insetShadow = true,
    super.borderSide = BorderSide.none,
    super.borderRadius = const BorderRadius.all(Radius.circular(40)),
    super.gapPadding = 4,
  });

  @override
  _InsetPhoneBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => _InsetPhoneBorder(
    insetShadow: insetShadow,
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  @override
  _InsetPhoneBorder scale(double t) => _InsetPhoneBorder(
    insetShadow: insetShadow,
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
    gapPadding: gapPadding * t,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    if (!insetShadow) {
      final shape = borderRadius.toRRect(rect);
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(20)),
          Path()..addRRect(shape),
        ),
      );
      canvas.drawRRect(shape.shift(const Offset(2, 2)), shadow);
      canvas.restore();
      super.paint(canvas, rect, gapStart: gapStart, gapExtent: gapExtent,
        gapPercentage: gapPercentage, textDirection: textDirection);
      return;
    }
    final painter = inset.BoxDecoration(
      color: const Color(0xFFF2F8F8),
      borderRadius: borderRadius,
      boxShadow: [
        inset.BoxShadow(
          color: Colors.black.withValues(alpha: insetShadow ? 0.25 : 0.08),
          blurRadius: insetShadow ? 2 : 3,
          offset: const Offset(2, 2),
          inset: insetShadow,
        ),
      ],
    ).createBoxPainter();
    painter.paint(
      canvas,
      rect.topLeft,
      ImageConfiguration(size: rect.size, textDirection: textDirection),
    );
    painter.dispose();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

class MalaysianPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool insetShadow;
  final double borderRadius;
  final ValueChanged<String>? onChanged;
  const MalaysianPhoneField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.insetShadow = true,
    this.borderRadius = 40,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    onChanged: onChanged,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.telephoneNumberNational],
    inputFormatters: const [MalaysianPhoneInputFormatter()],
    validator: PhoneNumberUtils.validate,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    cursorColor: const Color(0xFF006670),
    style: const TextStyle(color: Color(0xFF134E4A), fontSize: 16),
    decoration: InputDecoration(
      hintText: PhoneNumberUtils.exampleNationalNumber,
      hintStyle: TextStyle(color: Colors.grey),
      prefixIcon: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PhoneNumberUtils.countryCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006670),
              ),
            ),
          ],
        ),
      ),
      filled: !insetShadow,
      fillColor: const Color(0xFFF2F8F8),
      contentPadding: EdgeInsets.symmetric(
        horizontal: insetShadow ? 16 : 20, vertical: insetShadow ? 16 : 18),
      errorMaxLines: 2,
      errorBorder: _InsetPhoneBorder(
        insetShadow: insetShadow,
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: _InsetPhoneBorder(
        insetShadow: insetShadow,
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      border: _InsetPhoneBorder(
        insetShadow: insetShadow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      enabledBorder: _InsetPhoneBorder(
        insetShadow: insetShadow,
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: _InsetPhoneBorder(
        insetShadow: insetShadow,
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
