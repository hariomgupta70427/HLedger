/// Validators and sanitizers for user input.
class InputValidator {
  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount required';
    final n = double.tryParse(value.trim());
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Must be greater than 0';
    if (n > 10000000) return 'Amount too large';
    return null;
  }

  static String? validateText(String? value, {int maxLength = 200}) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (value.length > maxLength) return 'Too long (max $maxLength chars)';
    if (value.contains(RegExp(r'<[^>]*>'))) return 'Invalid characters';
    return null;
  }

  /// Sanitize user input before sending to AI — strip injection attempts and limit length.
  static String sanitizeForAI(String input) {
    if (input.length > 500) {
      input = input.substring(0, 500);
    }
    for (final phrase in [
      'ignore previous instructions',
      'ignore above',
      'system prompt',
      'forget everything',
      'you are now',
      'act as',
      'jailbreak',
    ]) {
      input = input.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }
    return input.trim();
  }
}
