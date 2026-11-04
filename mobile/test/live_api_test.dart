import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homecircle/core/errors/app_exception.dart';
import 'package:homecircle/core/network/api_client.dart';
import 'package:homecircle/core/network/network_status.dart';
import 'package:http/http.dart' as http;

// Use Dart's socket client instead of the widget-test HTTP stub.
class _LiveHttpOverrides extends HttpOverrides {}

void main() {
  const baseUrl = String.fromEnvironment('LIVE_API_BASE_URL');
  final skip = baseUrl.isEmpty
      ? 'Set LIVE_API_BASE_URL for read-only live checks'
      : null;

  test('Flutter API client reaches the running health endpoint', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final client = http.Client();
      final network = NetworkStatus();
      try {
        final api = ApiClient(
          client: client,
          baseUrl: baseUrl,
          accessToken: () async => null,
          networkStatus: network,
        );
        expect(await api.get('/health', authenticated: false), {
          'status': 'ok',
        });
        expect(network.offline, false);
      } finally {
        client.close();
        network.dispose();
      }
    }, _LiveHttpOverrides());
  }, skip: skip);

  test(
    'Flutter API client maps a real invalid-token response to unauthorized',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = http.Client();
        final network = NetworkStatus();
        try {
          final api = ApiClient(
            client: client,
            baseUrl: baseUrl,
            accessToken: () async => 'invalid-test-token',
            networkStatus: network,
          );
          await expectLater(
            api.get('/api/v1/me'),
            throwsA(isA<UnauthorizedException>()),
          );
          expect(network.offline, false);
        } finally {
          client.close();
          network.dispose();
        }
      }, _LiveHttpOverrides());
    },
    skip: skip,
  );
}
