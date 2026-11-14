import '../models/household_hub.dart';
import 'scoped_hub_model.dart';

class DashboardViewModel extends ScopedHubModel {
  DashboardViewModel(super.repository, super.session);
  DashboardSnapshot? snapshot;
  @override
  void reset() {
    snapshot = null;
  }

  @override
  Future<void> load() async {
    if (!ready || loading) return;
    final captured = scope, number = ++request, u = user, h = home;
    loading = true;
    error = null;
    emit();
    try {
      final result = await repository.read(
        u,
        h,
        'dashboard',
        () => repository.service.dashboard(h),
        () => current(captured) && number == request,
        (data) {
          DashboardSnapshot(data, h);
        },
      );
      if (current(captured) && number == request) {
        snapshot = DashboardSnapshot(result.data, h);
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
