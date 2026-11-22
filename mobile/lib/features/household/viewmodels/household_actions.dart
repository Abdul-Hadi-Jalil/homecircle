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

  /// Counts shown under My Activity on the profile.
  int assignedActive = 0;
  int requestsOpen = 0;
  int completedMine = 0;
  Future<bool> loadMyActivity(String id) => run(() async {
    final counts = await Future.wait([
      repository.taskTotal(id, {'assignment': 'me', 'active_only': 'true'}),
      repository.taskTotal(id, {
        'assignment': 'requested',
        'active_only': 'true',
      }),
      repository.taskTotal(id, {'assignment': 'me', 'status': 'completed'}),
    ]);
    assignedActive = counts[0];
    requestsOpen = counts[1];
    completedMine = counts[2];
  });
  Future<bool> reloadMembers(String id) => run(() async {
    members = [];
    final batch = await repository.members(id, 0);
    members = batch;
    moreMembers = batch.length == 50;
  });
  Future<bool> setMemberRole(String id, String userId, String role) =>
      run(() async {
        await repository.setMemberRole(id, userId, role);
        members = await repository.members(id, 0);
      });
  Future<bool> removeMember(String id, String userId) => run(() async {
    await repository.removeMember(id, userId);
    members = await repository.members(id, 0);
  });
  Future<bool> leave(String id) => run(() => repository.leave(id));
  Future<bool> deleteHousehold(String id) =>
      run(() => repository.deleteHousehold(id));
  Future<bool> update(
    String id,
    String name,
    String? description, {
    String? avatarKey,
  }) =>
      run(() => repository.update(id, name, description, avatarKey: avatarKey));
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
