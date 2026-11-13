import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/household_task.dart';
import 'tasks_view_model.dart';

class TaskFormViewModel extends ChangeNotifier {
  TaskFormViewModel(
    this.tasks, {
    this.initial,
    String? initialItemId,
    String? initialItemName,
    String? initialType,
  }) : originScope = tasks.scopeKey {
    final saved = tasks.draft(initial?.id ?? 'new');
    restored = saved != null;
    fields = {
      ...?initial?.data,
      if (initial == null)
        'task_type':
            initialType ?? (initialItemId == null ? 'general' : 'repair'),
      if (initial == null) 'priority': 'normal',
      if (initial != null) 'expected_revision': initial!.revision,
      if (initialItemId != null && initial == null)
        'linked_inventory_item_id': initialItemId,
      if (initialItemName != null && initial == null)
        'linked_inventory_name': initialItemName,
      ...?saved,
    };
  }
  final TasksViewModel tasks;
  final HouseholdTask? initial;
  final String originScope;
  late Map<String, dynamic> fields;
  late bool restored;
  bool busy = false, _disposed = false, uploading = false;
  Uint8List? photo;
  String? errorCode;
  String get draftKey => initial?.id ?? 'new';
  bool get current =>
      !_disposed && tasks.ready && tasks.scopeKey == originScope;
  void update(String key, dynamic value) {
    if (!current || busy) return;
    fields[key] = value;
    if (key == 'task_type' && value != 'repair') {
      fields['linked_inventory_item_id'] = null;
      fields['linked_inventory_name'] = null;
    }
    unawaited(tasks.saveDraft(draftKey, fields, originScope));
    notifyListeners();
  }

  void setPhoto(Uint8List? value) {
    if (current && !busy) {
      photo = value;
      notifyListeners();
    }
  }

  Map<String, dynamic> payload() => {
    for (final key in [
      'task_type',
      'title',
      'description',
      'priority',
      'assigned_to',
      'due_date',
      'location',
      'linked_inventory_item_id',
    ])
      key: fields[key] is String && (fields[key] as String).trim().isEmpty
          ? null
          : fields[key],
    if (initial != null) 'expected_revision': fields['expected_revision'],
  };
  Future<HouseholdTask?> submit() async {
    if (!current || busy) return null;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final saved = await tasks.save(initial?.id, payload());
      if (!current) return null;
      if (saved == null) {
        errorCode = tasks.errorCode;
        return null;
      }
      await tasks.clearDraft(draftKey, originScope);
      if (photo != null && current) {
        uploading = true;
        notifyListeners();
        if (await tasks.upload(saved, photo!) == null && current) {
          errorCode = 'task_saved_photo_failed';
        }
      }
      return current ? saved : null;
    } finally {
      if (current) {
        busy = uploading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    photo = null;
    super.dispose();
  }
}
