class Invitation {
  const Invitation({
    required this.id,
    required this.expiresAt,
    required this.uses,
    required this.maxUses,
    required this.revoked,
  });
  final String id;
  final DateTime expiresAt;
  final int uses;
  final int? maxUses;
  final bool revoked;
  factory Invitation.fromJson(Map<String, dynamic> value) => Invitation(
    id: value['id'] as String,
    expiresAt: DateTime.parse(value['expires_at'] as String),
    uses: value['uses_count'] as int,
    maxUses: value['max_uses'] as int?,
    revoked: value['revoked_at'] != null,
  );
}

class IssuedInvitation {
  const IssuedInvitation(this.invitation, this.code);
  final Invitation invitation;
  final String code;
}

class InvitationPreview {
  const InvitationPreview(
    this.householdId,
    this.name,
    this.alreadyMember, {
    this.memberCount = 0,
    this.avatarKey,
  });
  final String householdId;
  final String name;
  final bool alreadyMember;
  final int memberCount;
  final String? avatarKey;
  factory InvitationPreview.fromJson(Map<String, dynamic> value) =>
      InvitationPreview(
        value['household_id'] as String,
        value['name'] as String,
        value['already_member'] as bool,
        memberCount: (value['member_count'] as num?)?.toInt() ?? 0,
        avatarKey: value['avatar_key'] as String?,
      );
}

class HouseholdMember {
  const HouseholdMember(this.name, this.role, {this.userId, this.joinedAt});
  final String name;
  final String role;
  final String? userId;
  final DateTime? joinedAt;
  factory HouseholdMember.fromJson(Map<String, dynamic> value) =>
      HouseholdMember(
        value['display_name'] as String,
        value['role'] as String,
        userId: value['user_id'] as String?,
        joinedAt: DateTime.tryParse(value['joined_at'] as String? ?? ''),
      );
}
