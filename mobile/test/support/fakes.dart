import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homecircle/core/config/app_runtime.dart';
import 'package:homecircle/core/network/api_client.dart';
import 'package:homecircle/core/network/network_status.dart';
import 'package:homecircle/core/storage/local_store.dart';
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/auth/repositories/auth_repository.dart';
import 'package:homecircle/features/auth/services/auth_service.dart';
import 'package:homecircle/features/dashboard/repositories/diagnostics_repository.dart';
import 'package:homecircle/features/dashboard/viewmodels/diagnostics_view_model.dart';
import 'package:homecircle/features/household/repositories/household_repository.dart';
import 'package:homecircle/features/household/services/household_api.dart';
import 'package:homecircle/features/household/services/realtime_scope.dart';
import 'package:homecircle/features/household/viewmodels/session_view_model.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.identity});
  AuthIdentity? identity;
  final events = StreamController<AuthIdentity?>.broadcast(sync: true);
  bool fail = false;
  @override
  Stream<AuthIdentity?> get changes => events.stream;
  @override
  Future<AuthIdentity?> restore() async => identity;
  @override
  Future<String?> accessToken() async => identity == null ? null : 'test-token';
  @override
  Future<void> login(String email, String password) async {
    if (fail) throw Exception('test failure');
    identity = AuthIdentity(id: 'user-a', email: email);
    events.add(identity);
  }

  @override
  Future<void> logout() async {
    identity = null;
    events.add(null);
  }

  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String password) async {}
  @override
  Future<void> resendVerification(String email) async {}
}

Map<String, dynamic> membership(String id) => {
  'id': id,
  'name': 'Home $id',
  'role': 'admin',
  'description': null,
};

http.Response householdResponse(
  http.Request request,
  List<Map<String, dynamic>> memberships,
) {
  final isList = request.url.path == '/api/v1/households';
  final household = memberships
      .where((item) => item['id'] == request.url.pathSegments.last)
      .firstOrNull;
  return http.Response(
    jsonEncode(isList ? memberships : household),
    isList || household != null ? 200 : 404,
    headers: {'content-type': 'application/json'},
  );
}

class TestRuntime {
  TestRuntime(this.auth, this.runtime);
  final FakeAuthService auth;
  final AppRuntime runtime;
  Future<void> dispose() async {
    runtime.dispose();
    await auth.events.close();
  }
}

Future<TestRuntime> createTestRuntime({
  AuthIdentity? identity,
  List<Map<String, dynamic>> memberships = const [],
  Future<http.Response> Function(http.Request)? respond,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final store = LocalStore(await SharedPreferences.getInstance());
  final authService = FakeAuthService(identity: identity);
  final auth = AuthRepository(authService);
  final network = NetworkStatus();
  final client = MockClient(
    respond ?? (request) async => householdResponse(request, memberships),
  );
  final api = ApiClient(
    client: client,
    baseUrl: 'https://api.example.test',
    accessToken: authService.accessToken,
    networkStatus: network,
  );
  final service = HouseholdApi(api);
  final repository = HouseholdRepository(service);
  final runtime = AppRuntime(
    auth: auth,
    households: repository,
    store: store,
    network: network,
    client: client,
    session: SessionViewModel(
      auth: auth,
      repository: repository,
      store: store,
      realtime: RealtimeScope(null),
    ),
    diagnostics: DiagnosticsViewModel(DiagnosticsRepository(api, service)),
  );
  return TestRuntime(authService, runtime);
}
