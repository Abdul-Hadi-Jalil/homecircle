import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../models/invitation.dart';
import '../repositories/household_repository.dart';

class HouseholdActions extends ChangeNotifier {
  HouseholdActions(this.repository);
  final HouseholdRepository repository;
  bool busy = false;
  bool _disposed = false;
  String? error;
  InvitationPreview? preview;
  IssuedInvitation? issued;
  List<Invitation> invitations = [];
  List<HouseholdMember> members = [];
  bool moreMembers = true;
  Map<String, dynamic>? profile;

  Future<bool> run(Future<void> Function() operation) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    var success = false;
    try {
      await operation();
      success = true;
    } on AppException catch (e) {
      error = e.code;
    } on Object {
      error = 'unknown';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
    return success && !_disposed;
  }

  void clearPreview() {
    preview = null;
    error = null;
    notifyListeners();
  }

  Future<bool> previewCode(String code) => run(() async {
    preview = null;
    preview = await repository.preview(code);
  });
  Future<bool> loadInvitations(String id) => run(() async {
    invitations = await repository.invitations(id);
  });
  Future<bool> issue(String id) => run(() async {
    issued = null;
    issued = await repository.issue(id);
    invitations = await repository.invitations(id);
  });
  Future<bool> revoke(String id, String invite) => run(() async {
    await repository.revoke(id, invite);
    if (issued?.invitation.id == invite) issued = null;
    invitations = await repository.invitations(id);
  });
  Future<bool> loadMembers(String id) => run(() async {
    final batch = await repository.members(id, members.length);
    members = [...members, ...batch];
    moreMembers = batch.length == 50;
  });
  Future<bool> update(String id, String name, String? description) =>
      run(() => repository.update(id, name, description));
  Future<bool> loadProfile() => run(() async {
    profile = await repository.profile();
  });
  Future<bool> saveProfile(String name) => run(() async {
    profile = await repository.updateProfile(name);
  });
  @override
  void dispose() {
    _disposed = true;
    profile = null;
    issued = null;
    super.dispose();
  }
}
