import '../../../core/storage/local_store.dart';
import '../../tasks/repositories/task_repository.dart';
import '../../tasks/services/task_api_service.dart';
import '../services/shopping_api_service.dart';

// Reuse the established guarded cache behavior with a distinct storage namespace.
class ShoppingRepository extends TaskRepository {
  ShoppingRepository(this.shopping, LocalStore store)
    : super(TaskApiService(shopping.api), store, namespace: 'shopping');
  final ShoppingApiService shopping;
}
