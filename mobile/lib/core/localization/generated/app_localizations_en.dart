// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'HomeCircle';

  @override
  String get tagline => 'Everything your home needs, in one place.';

  @override
  String get configurationTitle => 'Development configuration';

  @override
  String get configurationMessage =>
      'Set API_BASE_URL, SUPABASE_URL and a public SUPABASE_PUBLISHABLE_KEY using --dart-define-from-file. See docs/setup.md. If values are set, check your connection and device secure storage, then restart.';

  @override
  String get bootstrap => 'Getting your home ready…';

  @override
  String get welcome => 'Welcome';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Create account';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get resetPassword => 'Set a new password';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display name';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get shortPassword => 'Use at least 8 characters.';

  @override
  String get authFailed =>
      'Authentication could not be completed. Check your details and connection.';

  @override
  String get authSuccess =>
      'Request completed. Check your email if confirmation is required.';

  @override
  String get passwordUpdated => 'Your password has been updated.';

  @override
  String get selectHousehold => 'Select household';

  @override
  String get createHousehold => 'Create household';

  @override
  String get joinHousehold => 'Join household';

  @override
  String get inviteFamily => 'Invite family';

  @override
  String get householdName => 'Household name';

  @override
  String get noHouseholds =>
      'Create a household or join your family using an invitation code.';

  @override
  String get householdError =>
      'Household access could not be verified. Reconnect and try again.';

  @override
  String get home => 'Home';

  @override
  String get inventory => 'Inventory';

  @override
  String get tasks => 'Tasks';

  @override
  String get shopping => 'Shopping';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get inventoryDetails => 'Inventory details';

  @override
  String get addInventory => 'Add inventory item';

  @override
  String get createTask => 'Create task';

  @override
  String get taskDetails => 'Task details';

  @override
  String get notifications => 'Notifications';

  @override
  String get householdSettings => 'Household settings';

  @override
  String get familyActivity => 'Family activity';

  @override
  String get placeholder => 'This screen is ready for a future milestone.';

  @override
  String get offline =>
      'Offline · cached information may be out of date. Writes are not queued.';

  @override
  String get retry => 'Retry';

  @override
  String get logout => 'Log out';

  @override
  String get switchHousehold => 'Switch household';

  @override
  String get continueAction => 'Continue';

  @override
  String get checkApi => 'Check API connection';

  @override
  String get apiConnected => 'API is available.';

  @override
  String get apiUnavailable =>
      'API is unavailable. Check your connection and configuration.';

  @override
  String get checkProfile => 'Check authenticated profile';

  @override
  String get profileConnected => 'Your authenticated API profile is available.';

  @override
  String get onboardTeamTitle => 'A little teamwork makes home easier.';

  @override
  String get onboardSyncTitle => 'Your family, always in sync.';

  @override
  String get onboardItems =>
      'Keep track of household items, supplies, and everything your family needs.';

  @override
  String get onboardTeam =>
      'Create tasks, report issues, and keep everyone informed.';

  @override
  String get onboardSync =>
      'Share messages, manage shopping lists, and stay updated.';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get Started';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get signInSubtitle => 'Sign in to your family home.';

  @override
  String get createAccountTitle => 'Make room for your family.';

  @override
  String get accountSubtitle => 'Your home works better together.';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordMismatch => 'Passwords must match.';

  @override
  String get checkEmail => 'Check your email';

  @override
  String get verificationMessage =>
      'We sent you a verification link to finish creating your account.';

  @override
  String get resendVerification => 'Resend verification email';

  @override
  String get resendWait =>
      'Please wait 60 seconds before requesting another email.';

  @override
  String get backToLogin => 'Back to Sign In';

  @override
  String get neutralReset =>
      'If an account exists for that email, a password reset link is on its way.';

  @override
  String get authLinkError =>
      'This verification or recovery link is invalid or has expired. Request a new link and try again.';

  @override
  String get invalidCredentials =>
      'Check your email and password, and confirm your email before signing in.';

  @override
  String get authRateLimit =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get weakPassword =>
      'Choose a stronger password that meets the project’s requirements.';

  @override
  String get householdConnection => 'Household connection';

  @override
  String get householdConnectionDescription =>
      'Create your account first, then choose a household or join with an invitation.';

  @override
  String get prepareHome => 'Let’s set up your home';

  @override
  String get createHomeDescription =>
      'Start a family space, become its admin, and invite everyone to join.';

  @override
  String get joinHomeDescription =>
      'Already invited? Use your family’s invitation code to join their shared space.';

  @override
  String get description => 'Description';

  @override
  String get optionalImage =>
      'A default household avatar is provided. Photo uploads are optional and will be available later.';

  @override
  String get adminNotice => 'You’ll be the Household Admin';

  @override
  String get adminDescription =>
      'Manage household details and invite family members.';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get previewInvitation => 'Check invitation';

  @override
  String get joinConfirmation => 'Join this household?';

  @override
  String get invitationUnavailable =>
      'This invitation is invalid or unavailable.';

  @override
  String get invitationExpired =>
      'This invitation has expired. Ask an admin for a new code.';

  @override
  String get invitationRevoked =>
      'This invitation was revoked. Ask an admin for a new code.';

  @override
  String get invitationLimit => 'This invitation has reached its usage limit.';

  @override
  String get invitationRateLimit =>
      'Too many code attempts. Try again in five minutes.';

  @override
  String get alreadyMember =>
      'You already belong to this household. Continue to switch to it.';

  @override
  String get generateCode => 'Generate New Code';

  @override
  String get revokeCode => 'Revoke Code';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get shareInvitation => 'Share Invitation';

  @override
  String get codeShownOnce =>
      'Codes are shown only when generated. Generate a replacement to copy or share a code again.';

  @override
  String get replaceCodeQuestion =>
      'Generate a new invitation? Existing active codes will be revoked.';

  @override
  String get revokeCodeQuestion =>
      'Revoke this invitation? It will no longer accept new members.';

  @override
  String get invitationCreated =>
      'Invitation created. Copy or share it before leaving this screen.';

  @override
  String get expires => 'Expires';

  @override
  String get uses => 'Uses';

  @override
  String get revoked => 'Revoked';

  @override
  String get active => 'Active';

  @override
  String get expired => 'Expired';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get done => 'Done';

  @override
  String get copied => 'Code copied';

  @override
  String invitationShare(String household, String code) {
    return 'Join $household on HomeCircle. Use this invitation code to join: $code.';
  }

  @override
  String memberSummary(int count, String role) {
    return '$count members · $role';
  }

  @override
  String get adminRole => 'Admin';

  @override
  String get memberRole => 'Member';

  @override
  String get familyMembers => 'Family members';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get settingsSaved => 'Household updated.';

  @override
  String get noInvitations =>
      'No invitations yet. Generate a code to invite your family.';

  @override
  String get operationFailed =>
      'We couldn’t complete that request. Check your connection and try again.';

  @override
  String get permissionDenied =>
      'You do not have permission to perform this action.';

  @override
  String get profileAvatar => 'Profile avatar';

  @override
  String get loadMore => 'Load more';

  @override
  String get householdSaved => 'Household created.';

  @override
  String get selectHome => 'Choose your household';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get fullName => 'Full name';

  @override
  String get householdNameHint => 'e.g. Our Family Home';
}
