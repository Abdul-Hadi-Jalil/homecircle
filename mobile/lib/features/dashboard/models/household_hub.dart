import '../../../core/errors/app_exception.dart';

class DashboardSnapshot {
  DashboardSnapshot(this.data, String home) {
    if ((data['household'] as Map)['id'] != home) {
      throw const InvalidResponseException();
    }
    for (final key in [
      'needs_attention',
      'upcoming_tasks',
      'recent_activity',
    ]) {
      for (final row in data[key] as List) {
        if (row['household_id'] != home) throw const InvalidResponseException();
      }
    }
    summary;
  }
  final Map<String, dynamic> data;
  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(data['summary'] as Map);
  int count(String key) => summary[key] as int;
  List<Map<String, dynamic>> rows(String key) =>
      (data[key] as List).cast<Map<String, dynamic>>();
  bool get empty => data['has_records'] == false;
}

class HubDestination {
  const HubDestination(this.route, {this.id});
  final String route;
  final String? id;
}
