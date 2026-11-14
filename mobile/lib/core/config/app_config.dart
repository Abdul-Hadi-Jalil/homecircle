import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseKey,
    this.allowLocalHttp = !kReleaseMode,
  });

  const AppConfig.fromEnvironment()
    : apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabaseKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      allowLocalHttp = !kReleaseMode;

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseKey;
  final bool allowLocalHttp;
  static const authCallback = 'com.homecircle.homecircle://auth-callback';

  bool get isValid {
    final api = Uri.tryParse(apiBaseUrl);
    final supabase = Uri.tryParse(supabaseUrl);
    if (api == null ||
        !api.hasAuthority ||
        supabase == null ||
        !supabase.hasAuthority) {
      return false;
    }
    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    final apiSafe =
        api.scheme == 'https' ||
        (allowLocalHttp &&
            api.scheme == 'http' &&
            localHosts.contains(api.host));
    final supabaseSafe =
        supabase.scheme == 'https' ||
        (allowLocalHttp &&
            supabase.scheme == 'http' &&
            localHosts.contains(supabase.host));
    if (!apiSafe ||
        !supabaseSafe ||
        api.userInfo.isNotEmpty ||
        supabase.userInfo.isNotEmpty ||
        api.hasQuery ||
        api.hasFragment ||
        supabase.hasQuery ||
        supabase.hasFragment ||
        (supabase.path.isNotEmpty && supabase.path != '/')) {
      return false;
    }
    if (supabaseKey.startsWith('sb_publishable_')) return true;
    // Inspect only to reject accidental server keys; this is not JWT verification.
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(supabaseKey.split('.')[1])),
        ),
      );
      return payload is Map && payload['role'] == 'anon';
    } on Object {
      return false;
    }
  }
}
