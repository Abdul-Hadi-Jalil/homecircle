import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../models/shopping_item.dart';
import 'shopping_list_viewmodel.dart';

class ShoppingFormViewModel extends ChangeNotifier {
  ShoppingFormViewModel(
    this.shopping, {
    this.initial,
    Map<String, dynamic> prefill = const {},
  }) : originScope = shopping.scope,
       draftKey =
           initial?.id ??
           (prefill['linked_inventory_item_id'] == null
               ? 'new'
               : 'new.inventory.${prefill['linked_inventory_item_id']}') {
    final saved = shopping.draft(draftKey);
    restored = saved != null;
    fields = {
      'priority': 'normal',
      ...?initial?.data,
      ...prefill,
      if (initial != null) 'expected_revision': initial!.revision,
      ...?saved,
    };
  }
  final ShoppingListViewModel shopping;
  final ShoppingItem? initial;
  final String originScope;
  final String draftKey;
  late Map<String, dynamic> fields;
  late bool restored;
  bool busy = false, disposed = false;
  String? error;
  List<ShoppingItem> duplicates = [];
  bool get current => !disposed && shopping.current(originScope);
  void update(String key, dynamic value) {
    if (!current || busy) return;
    fields[key] = value;
    unawaited(shopping.saveDraft(draftKey, fields, originScope));
    notifyListeners();
  }

  Future<ShoppingItem?> submit({bool allowDuplicate = false}) async {
    if (!current || busy) return null;
    busy = true;
    error = null;
    duplicates = [];
    notifyListeners();
    try {
      if (initial == null &&
          fields['linked_inventory_item_id'] != null &&
          !allowDuplicate) {
        duplicates = await shopping.duplicates(
          fields['linked_inventory_item_id'] as String,
        );
        if (!current || duplicates.isNotEmpty) return null;
      }
      final body = {
        for (final key in [
          'title',
          'quantity',
          'unit',
          'priority',
          'description',
          'assigned_to',
          'linked_inventory_item_id',
        ])
          key: fields[key] is String && (fields[key] as String).trim().isEmpty
              ? null
              : fields[key],
        if (initial != null) 'expected_revision': fields['expected_revision'],
      };
      final result = await shopping.save(initial?.id, body, originScope);
      if (!current) return null;
      if (result != null) {
        await shopping.clearDraft(draftKey, originScope);
      } else {
        error = shopping.error;
      }
      return result;
    } catch (e) {
      if (current) error = e is AppException ? e.code : 'unknown';
      return null;
    } finally {
      if (current) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
