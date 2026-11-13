import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import 'network_status.dart';

class ApiClient {
  ApiClient({
    required this.client,
    required String baseUrl,
    required this.accessToken,
    required this.networkStatus,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client client;
  final String baseUrl;
  final Future<String?> Function() accessToken;
  final NetworkStatus networkStatus;
  final Duration timeout;

  Future<Object?> get(String path, {bool authenticated = true}) =>
      _request('GET', path, authenticated: authenticated);
  Future<Object?> post(String path, {Object? body}) =>
      _request('POST', path, body: body);
  Future<Object?> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);
  Future<Object?> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);
  Future<Object?> delete(String path) => _request('DELETE', path);

  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://')) {
      throw ArgumentError.value(path, 'path', 'Expected a relative API path');
    }
    try {
      final token = authenticated ? await accessToken() : null;
      if (authenticated && token == null) throw const UnauthorizedException();
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
      networkStatus.record(reachable: true);
      if ({400, 409, 413, 422, 429}.contains(response.statusCode)) {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          final code = (error['error'] as Map<String, dynamic>?)?['code'];
          if (code is String) throw AppException(code);
        } on FormatException {
          throw const InvalidResponseException();
        } on TypeError {
          throw const InvalidResponseException();
        }
      }
      switch (response.statusCode) {
        case 401:
          throw const UnauthorizedException();
        case 403:
          throw const ForbiddenException();
        case 404:
          throw const NotFoundException();
        case 400 || 409 || 413 || 422:
          throw const ValidationException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ServerException();
      }
      if (response.statusCode == 204) return null;
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim();
      if (contentType != 'application/json') {
        throw const InvalidResponseException();
      }
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
          throw const InvalidResponseException();
        }
        return decoded;
      } on FormatException {
        throw const InvalidResponseException();
      }
    } on TimeoutException {
      networkStatus.record(reachable: false);
      throw const NetworkException();
    } on SocketException {
      networkStatus.record(reachable: false);
      throw const NetworkException();
    } on http.ClientException {
      networkStatus.record(reachable: false);
      throw const NetworkException();
    }
  }
}
