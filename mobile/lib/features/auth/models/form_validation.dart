abstract final class FormValidation {
  static bool email(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool password(String value) => value.length >= 8;
  static bool confirmation(String value, String password) => value == password;
}
