import '../../../core/errors/app_exception.dart';
import '../models/household.dart';
import '../models/invitation.dart';
import '../services/household_api.dart';

class HouseholdRepository {
  HouseholdRepository(this.service);
  final HouseholdApi service;

  Future<Map<String, dynamic>> profile() => service.me();
  Future<Map<String, dynamic>> updateProfile(String name) =>
      service.updateProfile(name.trim());

  Future<InvitationPreview> preview(String code) async =>
      InvitationPreview.fromJson(await service.preview(code));
  Future<Household> redeem(String code) async =>
      Household.fromJson(await service.redeem(code));
  Future<List<Invitation>> invitations(String id) async =>
      (await service.invites(id))
          .map((row) => Invitation.fromJson(row as Map<String, dynamic>))
          .toList();
  Future<IssuedInvitation> issue(String id) async {
    final result = await service.issue(id);
    return IssuedInvitation(
      Invitation.fromJson(result['invitation'] as Map<String, dynamic>),
      result['code'] as String,
    );
  }

  Future<void> revoke(String id, String inviteId) =>
      service.revoke(id, inviteId);
  Future<List<HouseholdMember>> members(String id, int offset) async =>
      (await service.members(id, offset))
          .map((row) => HouseholdMember.fromJson(row as Map<String, dynamic>))
          .toList();
  Future<void> update(String id, String name, String? description) =>
      service.update(id, name.trim(), description);

  Future<Household> getHousehold(String householdId) async {
    try {
      final household = Household.fromJson(await service.detail(householdId));
      if (household.id != householdId) throw const InvalidResponseException();
      return household;
    } on TypeError {
      throw const InvalidResponseException();
    } on FormatException {
      throw const InvalidResponseException();
    }
  }

  Future<List<Household>> memberships() async {
    try {
      return (await service.memberships())
          .map((row) => Household.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on TypeError {
      throw const InvalidResponseException();
    } on FormatException {
      throw const InvalidResponseException();
    }
  }

  Future<Household> create(String name, String? description) async {
    try {
      return Household.fromJson(await service.create(name.trim(), description));
    } on TypeError {
      throw const InvalidResponseException();
    } on FormatException {
      throw const InvalidResponseException();
    }
  }
}
