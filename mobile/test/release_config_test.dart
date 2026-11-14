import 'package:flutter_test/flutter_test.dart';
import 'package:homecircle/core/config/app_config.dart';

void main() {
  bool valid(String api, String auth, {bool local = false}) => AppConfig(
    apiBaseUrl: api,
    supabaseUrl: auth,
    supabaseKey: 'sb_publishable_test',
    allowLocalHttp: local,
  ).isValid;

  test('release configuration requires HTTPS and clean origins', () {
    expect(
      valid('https://api.example.test/v1/', 'https://auth.example.test/'),
      true,
    );
    for (final api in [
      'http://10.0.2.2:8000',
      'https://api.example.test?key=value',
      'https://api.example.test#fragment',
      'https://user:password@api.example.test',
    ]) {
      expect(valid(api, 'https://auth.example.test'), false);
    }
    for (final auth in [
      'https://auth.example.test/path',
      'https://auth.example.test?key=value',
      'https://auth.example.test#fragment',
      'http://localhost:54321',
    ]) {
      expect(valid('https://api.example.test', auth), false);
    }
    expect(
      valid('http://10.0.2.2:8000', 'http://localhost:54321', local: true),
      true,
    );
  });
}
