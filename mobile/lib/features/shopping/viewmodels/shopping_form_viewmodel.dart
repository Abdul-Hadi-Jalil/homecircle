import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../models/shopping_item.dart';
import 'shopping_list_viewmodel.dart';
import '../../chat/models/chat_task_source.dart';
import '../../chat/repositories/chat_cache.dart';

class ShoppingFormViewModel extends ChangeNotifier {
  ShoppingFormViewModel(
    this.shopping, {
    this.initial,
    Map<String, dynamic> prefill = const {},
    this.chatSource,
    this.chatCache,
    Map<String, dynamic>? secureDraft,
  }) : originScope = shopping.scope,
       draftKey =
           (chatSource != null
               ? 'shopping.${chatSource.messageId}'
               : initial?.id) ??
           (prefill['linked_inventory_item_id'] == null
               ? 'new'
               : 'new.inventory.${prefill['linked_inventory_item_id']}') {
    final saved = chatSource == null ? shopping.draft(draftKey) : secureDraft;
    restored = saved != null && saved.isNotEmpty;
    fields = {
      'priority': 'normal',
      ...?initial?.data,
      ...prefill,
      if (chatSource != null) ...{
        'title': chatSource!.suggestedTitle,
        'description': chatSource!.body,
        ...chatSource!.fields,
      },
      if (initial != null) 'expected_revision': initial!.revision,
      ...?saved,
    };
  }
  final ShoppingListViewModel shopping;
  final ShoppingItem? initial;
  final String originScope;
  final String draftKey;
  final ChatTaskSource? chatSource;
  final ChatCache? chatCache;
  late Map<String, dynamic> fields;
  late bool restored;
  bool busy = false, disposed = false;
  String? error;
  List<ShoppingItem> duplicates = [];
  bool get current => !disposed && shopping.current(originScope);
  void update(String key, dynamic value) {
    if (!current || busy) return;
    fields[key] = value;
    unawaited(persistDraft());
    notifyListeners();
  }

  Future<void> persistDraft() async {
    if (!current) return;
    if (chatSource == null) {
      await shopping.saveDraft(draftKey, fields, originScope);
      return;
    }
    try {
      await chatCache!.write(
        shopping.user!,
        shopping.household!,
        draftKey,
        fields,
      );
    } catch (_) {
      if (current) {
        error = 'local_storage';
        notifyListeners();
      }
    }
  }

  Future<void> discardDraft() async {
    if (!current) return;
    if (chatSource == null) {
      await shopping.clearDraft(draftKey, originScope);
      return;
    }
    try {
      await chatCache!.write(shopping.user!, shopping.household!, draftKey, {});
    } catch (_) {
      if (current) {
        error = 'local_storage';
        notifyListeners();
      }
    }
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
      final result = chatSource == null
          ? await shopping.save(initial?.id, body, originScope)
          : await shopping.createFromChat(body, fields, originScope);
      if (!current) return null;
      if (result != null) {
        await discardDraft();
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
