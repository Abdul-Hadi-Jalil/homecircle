import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:homecircle/core/errors/app_exception.dart';
import 'package:homecircle/core/network/api_client.dart';
import 'package:homecircle/core/network/network_status.dart';

void main() {
  late NetworkStatus network;
  setUp(() => network = NetworkStatus());
  tearDown(() => network.dispose());
  ApiClient api(
    http.Client client, {
    Duration timeout = const Duration(seconds: 1),
  }) => ApiClient(
    client: client,
    baseUrl: 'https://api.example.test/',
    accessToken: () async => 'test-token',
    networkStatus: network,
    timeout: timeout,
  );

  test('success decodes JSON and sends the current bearer token', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.example.test/api/v1/me');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(
        '{"id":"verified"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    expect(await api(client).get('/api/v1/me'), {'id': 'verified'});
    expect(network.offline, false);
    client.close();
  });

  test('unauthorized is typed and is not retried', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 401);
    });
    await expectLater(
      api(client).get('/api/v1/me'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(requests, 1);
    expect(network.offline, false);
    client.close();
  });

  test('network failure marks offline and does not queue writes', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      throw http.ClientException('unreachable');
    });
    await expectLater(
      api(client).post('/api/v1/households', body: {'name': 'Home'}),
      throwsA(isA<NetworkException>()),
    );
    expect(network.offline, true);
    expect(requests, 1);
    client.close();
  });

  test('POST PATCH PUT DELETE use JSON and 204 is accepted', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      if (request.method != 'DELETE') {
        expect(jsonDecode(request.body), {'name': 'Home'});
        expect(request.headers['content-type'], 'application/json');
      }
      return http.Response('', 204);
    });
    final subject = api(client);
    await subject.post('/items', body: {'name': 'Home'});
    await subject.patch('/items/1', body: {'name': 'Home'});
    await subject.put('/items/1', body: {'name': 'Home'});
    expect(await subject.delete('/items/1'), null);
    expect(methods, ['POST', 'PATCH', 'PUT', 'DELETE']);
    client.close();
  });

  test('rejects invalid JSON, content types and redirects', () async {
    for (final response in [
      http.Response(
        'not json',
        200,
        headers: {'content-type': 'application/json'},
      ),
      http.Response('{}', 200, headers: {'content-type': 'text/html'}),
      http.Response('{}', 302),
    ]) {
      final client = MockClient((request) async => response);
      await expectLater(api(client).get('/data'), throwsA(isA<AppException>()));
      client.close();
    }
  });

  test('timeout covers the response and marks offline', () async {
    final completion = Completer<http.Response>();
    final client = MockClient((request) => completion.future);
    await expectLater(
      api(client, timeout: const Duration(milliseconds: 5)).get('/data'),
      throwsA(isA<NetworkException>()),
    );
    expect(network.offline, true);
    completion.complete(http.Response('{}', 200));
    client.close();
  });

  test('public health sends no bearer and refuses absolute paths', () async {
    final client = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response(
        '{"status":"ok"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await api(client).get('/health', authenticated: false);
    await expectLater(
      api(client).get('https://attacker.test'),
      throwsArgumentError,
    );
    client.close();
  });
}
