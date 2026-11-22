import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../repositories/household_repository.dart';
import '../viewmodels/household_actions.dart';
import 'household_management_view.dart';
import 'invite_view.dart';
import 'profile_view.dart';

String actionError(AppLocalizations l, String? code) => switch (code) {
  'expired_invitation' => l.invitationExpired,
  'revoked_invitation' => l.invitationRevoked,
  'invitation_limit' => l.invitationLimit,
  'rate_limit' => l.invitationRateLimit,
  'invalid_invitation' => l.invitationUnavailable,
  'forbidden' => l.permissionDenied,
  _ => l.operationFailed,
};

/// Dispatches the household membership screens (invite, management, profile).
class MembershipView extends StatelessWidget {
  const MembershipView({required this.mode, super.key});
  final String mode;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => HouseholdActions(context.read<HouseholdRepository>()),
    child: switch (mode) {
      'invite' => const InviteView(),
      'profile' => const ProfileView(),
      _ => const HouseholdManagementView(),
    },
  );
}
