import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'HomeCircle'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Everything your home needs, in one place.'**
  String get tagline;

  /// No description provided for @configurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Development configuration'**
  String get configurationTitle;

  /// No description provided for @configurationMessage.
  ///
  /// In en, this message translates to:
  /// **'Set API_BASE_URL, SUPABASE_URL and a public SUPABASE_PUBLISHABLE_KEY using --dart-define-from-file. See docs/setup.md. If values are set, check your connection and device secure storage, then restart.'**
  String get configurationMessage;

  /// No description provided for @bootstrap.
  ///
  /// In en, this message translates to:
  /// **'Getting your home ready…'**
  String get bootstrap;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get resetPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @shortPassword.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get shortPassword;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication could not be completed. Check your details and connection.'**
  String get authFailed;

  /// No description provided for @authSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request completed. Check your email if confirmation is required.'**
  String get authSuccess;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get passwordUpdated;

  /// No description provided for @selectHousehold.
  ///
  /// In en, this message translates to:
  /// **'Select household'**
  String get selectHousehold;

  /// No description provided for @createHousehold.
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get createHousehold;

  /// No description provided for @joinHousehold.
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get joinHousehold;

  /// No description provided for @inviteFamily.
  ///
  /// In en, this message translates to:
  /// **'Invite family'**
  String get inviteFamily;

  /// No description provided for @householdName.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdName;

  /// No description provided for @noHouseholds.
  ///
  /// In en, this message translates to:
  /// **'Create a household or join your family using an invitation code.'**
  String get noHouseholds;

  /// No description provided for @householdError.
  ///
  /// In en, this message translates to:
  /// **'Household access could not be verified. Reconnect and try again.'**
  String get householdError;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @inventoryDetails.
  ///
  /// In en, this message translates to:
  /// **'Inventory details'**
  String get inventoryDetails;

  /// No description provided for @addInventory.
  ///
  /// In en, this message translates to:
  /// **'Add inventory item'**
  String get addInventory;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get createTask;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @householdSettings.
  ///
  /// In en, this message translates to:
  /// **'Household settings'**
  String get householdSettings;

  /// No description provided for @familyActivity.
  ///
  /// In en, this message translates to:
  /// **'Family activity'**
  String get familyActivity;

  /// No description provided for @placeholder.
  ///
  /// In en, this message translates to:
  /// **'This screen is ready for a future milestone.'**
  String get placeholder;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline · cached information may be out of date. Writes are not queued.'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @switchHousehold.
  ///
  /// In en, this message translates to:
  /// **'Switch household'**
  String get switchHousehold;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @checkApi.
  ///
  /// In en, this message translates to:
  /// **'Check API connection'**
  String get checkApi;

  /// No description provided for @apiConnected.
  ///
  /// In en, this message translates to:
  /// **'API is available.'**
  String get apiConnected;

  /// No description provided for @apiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'API is unavailable. Check your connection and configuration.'**
  String get apiUnavailable;

  /// No description provided for @checkProfile.
  ///
  /// In en, this message translates to:
  /// **'Check authenticated profile'**
  String get checkProfile;

  /// No description provided for @profileConnected.
  ///
  /// In en, this message translates to:
  /// **'Your authenticated API profile is available.'**
  String get profileConnected;

  /// No description provided for @onboardTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'A little teamwork makes home easier.'**
  String get onboardTeamTitle;

  /// No description provided for @onboardSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Your family, always in sync.'**
  String get onboardSyncTitle;

  /// No description provided for @onboardItems.
  ///
  /// In en, this message translates to:
  /// **'Keep track of household items, supplies, and everything your family needs.'**
  String get onboardItems;

  /// No description provided for @onboardTeam.
  ///
  /// In en, this message translates to:
  /// **'Create tasks, report issues, and keep everyone informed.'**
  String get onboardTeam;

  /// No description provided for @onboardSync.
  ///
  /// In en, this message translates to:
  /// **'Share messages, manage shopping lists, and stay updated.'**
  String get onboardSync;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your family home.'**
  String get signInSubtitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Make room for your family.'**
  String get createAccountTitle;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your home works better together.'**
  String get accountSubtitle;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match.'**
  String get passwordMismatch;

  /// No description provided for @checkEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmail;

  /// No description provided for @verificationMessage.
  ///
  /// In en, this message translates to:
  /// **'We sent you a verification link to finish creating your account.'**
  String get verificationMessage;

  /// No description provided for @resendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get resendVerification;

  /// No description provided for @resendWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait 60 seconds before requesting another email.'**
  String get resendWait;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToLogin;

  /// No description provided for @neutralReset.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, a password reset link is on its way.'**
  String get neutralReset;

  /// No description provided for @authLinkError.
  ///
  /// In en, this message translates to:
  /// **'This verification or recovery link is invalid or has expired. Request a new link and try again.'**
  String get authLinkError;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Check your email and password, and confirm your email before signing in.'**
  String get invalidCredentials;

  /// No description provided for @authRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get authRateLimit;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password that meets the project’s requirements.'**
  String get weakPassword;

  /// No description provided for @householdConnection.
  ///
  /// In en, this message translates to:
  /// **'Household connection'**
  String get householdConnection;

  /// No description provided for @householdConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your account first, then choose a household or join with an invitation.'**
  String get householdConnectionDescription;

  /// No description provided for @prepareHome.
  ///
  /// In en, this message translates to:
  /// **'Let’s set up your home'**
  String get prepareHome;

  /// No description provided for @createHomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a family space, become its admin, and invite everyone to join.'**
  String get createHomeDescription;

  /// No description provided for @joinHomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Already invited? Use your family’s invitation code to join their shared space.'**
  String get joinHomeDescription;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @optionalImage.
  ///
  /// In en, this message translates to:
  /// **'A default household avatar is provided. Photo uploads are optional and will be available later.'**
  String get optionalImage;

  /// No description provided for @adminNotice.
  ///
  /// In en, this message translates to:
  /// **'You’ll be the Household Admin'**
  String get adminNotice;

  /// No description provided for @adminDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage household details and invite family members.'**
  String get adminDescription;

  /// No description provided for @invitationCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get invitationCode;

  /// No description provided for @previewInvitation.
  ///
  /// In en, this message translates to:
  /// **'Check invitation'**
  String get previewInvitation;

  /// No description provided for @joinConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Join this household?'**
  String get joinConfirmation;

  /// No description provided for @invitationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This invitation is invalid or unavailable.'**
  String get invitationUnavailable;

  /// No description provided for @invitationExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired. Ask an admin for a new code.'**
  String get invitationExpired;

  /// No description provided for @invitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'This invitation was revoked. Ask an admin for a new code.'**
  String get invitationRevoked;

  /// No description provided for @invitationLimit.
  ///
  /// In en, this message translates to:
  /// **'This invitation has reached its usage limit.'**
  String get invitationLimit;

  /// No description provided for @invitationRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many code attempts. Try again in five minutes.'**
  String get invitationRateLimit;

  /// No description provided for @alreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You already belong to this household. Continue to switch to it.'**
  String get alreadyMember;

  /// No description provided for @generateCode.
  ///
  /// In en, this message translates to:
  /// **'Generate New Code'**
  String get generateCode;

  /// No description provided for @revokeCode.
  ///
  /// In en, this message translates to:
  /// **'Revoke Code'**
  String get revokeCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share Invitation'**
  String get shareInvitation;

  /// No description provided for @codeShownOnce.
  ///
  /// In en, this message translates to:
  /// **'Codes are shown only when generated. Generate a replacement to copy or share a code again.'**
  String get codeShownOnce;

  /// No description provided for @replaceCodeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Generate a new invitation? Existing active codes will be revoked.'**
  String get replaceCodeQuestion;

  /// No description provided for @revokeCodeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revoke this invitation? It will no longer accept new members.'**
  String get revokeCodeQuestion;

  /// No description provided for @invitationCreated.
  ///
  /// In en, this message translates to:
  /// **'Invitation created. Copy or share it before leaving this screen.'**
  String get invitationCreated;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @uses.
  ///
  /// In en, this message translates to:
  /// **'Uses'**
  String get uses;

  /// No description provided for @revoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get revoked;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get copied;

  /// No description provided for @invitationShare.
  ///
  /// In en, this message translates to:
  /// **'Join {household} on HomeCircle. Use this invitation code to join: {code}.'**
  String invitationShare(String household, String code);

  /// No description provided for @memberSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} members · {role}'**
  String memberSummary(int count, String role);

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRole;

  /// No description provided for @memberRole.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRole;

  /// No description provided for @familyMembers.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get familyMembers;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileSaved;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Household updated.'**
  String get settingsSaved;

  /// No description provided for @noInvitations.
  ///
  /// In en, this message translates to:
  /// **'No invitations yet. Generate a code to invite your family.'**
  String get noInvitations;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t complete that request. Check your connection and try again.'**
  String get operationFailed;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get permissionDenied;

  /// No description provided for @profileAvatar.
  ///
  /// In en, this message translates to:
  /// **'Profile avatar'**
  String get profileAvatar;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @householdSaved.
  ///
  /// In en, this message translates to:
  /// **'Household created.'**
  String get householdSaved;

  /// No description provided for @selectHome.
  ///
  /// In en, this message translates to:
  /// **'Choose your household'**
  String get selectHome;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @householdNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Our Family Home'**
  String get householdNameHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
