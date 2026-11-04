import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../household/services/household_api.dart';

class DiagnosticsRepository {
  DiagnosticsRepository(this.api, this.households);
  final ApiClient api;
  final HouseholdApi households;
  Future<void> checkHealth() async {
    final result = await api.get('/health', authenticated: false);
    if (result is! Map<String, dynamic> || result['status'] != 'ok') {
      throw const InvalidResponseException();
    }
  }

  Future<void> checkProfile() async {
    await households.me();
  }
}
