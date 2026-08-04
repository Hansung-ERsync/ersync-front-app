import 'package:flutter/services.dart';

class KoreanMobilePhoneFormatter extends TextInputFormatter {
  const KoreanMobilePhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final String limited = digits.length > 11
        ? digits.substring(0, 11)
        : digits;
    final String formatted = _format(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-'
        '${digits.substring(7)}';
  }
}
