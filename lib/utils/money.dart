// Peso amounts for the bucket list savings. Pure Dart, unit tested in
// test/money_test.dart.

/// ₱60,000 or ₱1,250.50 (cents only when there are some).
String formatPeso(num amount) {
  final negative = amount < 0;
  final cents = (amount.abs() * 100).round();
  final digits = (cents ~/ 100).toString();
  final fraction = cents % 100;

  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  final decimals =
      fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\u20B1$grouped$decimals';
}

/// Reads what someone typed: "60000", "60,000", "₱1250.5".
/// Returns null unless it is a positive amount with at most two decimals.
double? parsePeso(String text) {
  final cleaned = text.replaceAll(RegExp('[\u20B1,\\s]'), '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0 || value > 100000000) return null;
  return value;
}

/// The database sends money as a number, but be safe if it is text.
double? readAmount(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
