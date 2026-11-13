import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/repositories/auth_repository.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/dashboard/repositories/diagnostics_repository.dart';
import '../../features/dashboard/viewmodels/diagnostics_view_model.dart';
import '../../features/household/repositories/household_repository.dart';
import '../../features/household/services/household_api.dart';
import '../../features/household/services/realtime_scope.dart';
import '../../features/household/viewmodels/session_view_model.dart';
import '../../features/inventory/services/inventory_api.dart';
import '../../features/inventory/repositories/inventory_repository.dart';
import '../../features/inventory/viewmodels/inventory_view_model.dart';
import '../../features/tasks/services/task_api_service.dart';
import '../../features/tasks/repositories/task_repository.dart';
import '../../features/tasks/viewmodels/tasks_view_model.dart';
import '../network/api_client.dart';
import '../network/network_status.dart';
import '../storage/local_store.dart';
import '../storage/secure_auth_storage.dart';
import 'app_config.dart';

class AppRuntime {
  AppRuntime({
    required this.auth,
    required this.households,
    required this.session,
    required this.diagnostics,
    required this.network,
    required this.client,
    required this.store,
  });
  final AuthRepository auth;
  final HouseholdRepository households;
  final SessionViewModel session;
  final DiagnosticsViewModel diagnostics;
  final NetworkStatus network;
  final http.Client client;
  final LocalStore store;
  late final InventoryViewModel inventory = InventoryViewModel(
    InventoryRepository(InventoryApi(households.service.api), store),
    session,
  );
  late final TasksViewModel tasks = TasksViewModel(
    TaskRepository(TaskApiService(households.service.api), store),
    session,
    inventory,
  );

  static Future<AppRuntime> initialize(AppConfig config) async {
    final store = LocalStore(await SharedPreferences.getInstance());
    const vault = FlutterSecureStorage();
    final namespace = Uri.parse(config.supabaseUrl).host;
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(vault, namespace),
        pkceAsyncStorage: SecurePkceStorage(vault, namespace),
        detectSessionInUriPredicate: (uri) =>
            uri.scheme == 'com.homecircle.homecircle' &&
            uri.host == 'auth-callback',
      ),
    );
    final supabase = Supabase.instance.client;
    final authService = SupabaseAuthService(supabase);
    final auth = AuthRepository(authService);
    final network = NetworkStatus();
    final client = http.Client();
    final api = ApiClient(
      client: client,
      baseUrl: config.apiBaseUrl,
      accessToken: authService.accessToken,
      networkStatus: network,
    );
    final householdApi = HouseholdApi(api);
    final households = HouseholdRepository(householdApi);
    return AppRuntime(
      auth: auth,
      households: households,
      store: store,
      client: client,
      network: network,
      session: SessionViewModel(
        auth: auth,
        repository: households,
        store: store,
        realtime: RealtimeScope(supabase),
        loadProfile: households.profile,
      ),
      diagnostics: DiagnosticsViewModel(
        DiagnosticsRepository(api, householdApi),
      ),
    );
  }

  void dispose() {
    tasks.dispose();
    inventory.dispose();
    session.dispose();
    diagnostics.dispose();
    client.close();
    network.dispose();
  }
}
