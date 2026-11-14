import '../../../core/errors/app_exception.dart';
import '../../dashboard/viewmodels/scoped_hub_model.dart';

class ActivityViewModel extends ScopedHubModel {
  ActivityViewModel(super.repository, super.session);
  List<Map<String, dynamic>> items = [];
  String category = 'all';
  DateTime? start, end;
  String? cursor;
  bool more = false;
  @override
  void reset() {
    items = [];
    category = 'all';
    start = end = null;
    cursor = null;
    more = false;
  }

  Future<void> filter(String value) async {
    request++;
    loading = false;
    category = value;
    items = [];
    cursor = null;
    more = false;
    await load();
  }

  Future<void> dateRange(DateTime? from, DateTime? to) async {
    request++;
    loading = false;
    start = from;
    end = to;
    items = [];
    cursor = null;
    await load();
  }

  @override
  Future<void> load() => page();
  Future<void> page({bool next = false}) async {
    if (!ready || loading || (next && !more)) return;
    final captured = scope, number = ++request, u = user, h = home;
    final filters = <String, String>{
      'page_size': '30',
      if (category != 'all') 'category': category,
      if (start != null) 'start': start!.toUtc().toIso8601String(),
      if (end != null) 'end': end!.toUtc().toIso8601String(),
    };
    final key = 'activity.${Uri(queryParameters: filters).query}';
    if (next && cursor != null) filters['cursor'] = cursor!;
    loading = true;
    error = null;
    emit();
    void validate(Map<String, dynamic> data) {
      for (final row in data['items'] as List) {
        if (row['household_id'] != h) throw const InvalidResponseException();
      }
    }

    try {
      final result = await repository.read(
        u,
        h,
        next ? '$key.$cursor' : key,
        () => repository.service.activity(h, filters),
        () => current(captured) && number == request,
        validate,
      );
      if (current(captured) && number == request) {
        final values = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        final combined = {
          for (final row in [
            ...(next ? items : <Map<String, dynamic>>[]),
            ...values,
          ])
            row['id']: row,
        };
        items = combined.values.toList();
        cursor = result.data['cursor'] as String?;
        more = result.data['has_more'] == true;
        adopt(result);
      }
    } catch (e) {
      if (current(captured) && number == request) failed(e);
    } finally {
      if (current(captured) && number == request) {
        loading = false;
        emit();
      }
    }
  }
}
