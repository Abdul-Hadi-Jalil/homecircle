// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get taskAny => 'Any';

  @override
  String get taskActivityCreated => 'Request created';

  @override
  String get taskActivityUpdated => 'Request updated';

  @override
  String get taskActivityAssigned => 'Assignment changed';

  @override
  String get taskActivityClaimed => 'Ownership taken';

  @override
  String get taskActivityUnassigned => 'Task unassigned';

  @override
  String get taskActivityPriority => 'Priority changed';

  @override
  String get taskActivityStatus => 'Status changed';

  @override
  String get taskActivityCompleted => 'Request completed';

  @override
  String get taskActivityCancelled => 'Request cancelled';

  @override
  String get taskActivityReopened => 'Request reopened';

  @override
  String get taskActivityArchived => 'Request archived';

  @override
  String get taskActivityRestored => 'Request restored';

  @override
  String get taskActivityCommentAdded => 'Comment added';

  @override
  String get taskActivityCommentEdited => 'Comment edited';

  @override
  String get taskActivityCommentDeleted => 'Comment deleted';

  @override
  String get taskActivityPhotoAdded => 'Photo added';

  @override
  String get taskActivityPhotoRemoved => 'Photo removed';

  @override
  String get taskCommentPhotoPartial =>
      'Your comment was posted, but its photo could not be uploaded. Add it to the comment from the discussion.';

  @override
  String get taskNoSavedView =>
      'This view has not been saved on this device. Reconnect to load it.';

  @override
  String get taskScreenTitle => 'Tasks & Requests';

  @override
  String get taskScreenSubtitle => 'Keep your family on track.';

  @override
  String get taskCreateRequest => 'Create Request';

  @override
  String get taskEditRequest => 'Edit Request';

  @override
  String get taskDetailsTitle => 'Task details';

  @override
  String get taskRepair => 'Repair';

  @override
  String get taskChore => 'Chore';

  @override
  String get taskGeneral => 'General';

  @override
  String get taskShoppingSoon => 'Shopping';

  @override
  String get taskAllTypes => 'All';

  @override
  String get taskLow => 'Low';

  @override
  String get taskNormal => 'Normal';

  @override
  String get taskHigh => 'High';

  @override
  String get taskUrgent => 'Urgent';

  @override
  String get taskOpen => 'Open';

  @override
  String get taskInProgress => 'In Progress';

  @override
  String get taskBlocked => 'Blocked';

  @override
  String get taskCompleted => 'Completed';

  @override
  String get taskCancelled => 'Cancelled';

  @override
  String get taskSearch => 'Search tasks';

  @override
  String get taskFilters => 'Filters';

  @override
  String get taskAllTasks => 'All Tasks';

  @override
  String get taskAssignedToMe => 'Assigned to Me';

  @override
  String get taskUnassigned => 'Unassigned';

  @override
  String get taskPriority => 'Priority';

  @override
  String get taskStatus => 'Status';

  @override
  String get taskDueDate => 'Due date';

  @override
  String get taskOverdue => 'Overdue';

  @override
  String get taskDueBefore => 'Due on or before';

  @override
  String get taskDueAfter => 'Due on or after';

  @override
  String get taskSort => 'Sort';

  @override
  String get taskSortPriority => 'Priority first';

  @override
  String get taskSortUpdated => 'Recently updated';

  @override
  String get taskSortDue => 'Due date';

  @override
  String get taskArchived => 'Archived';

  @override
  String get taskApplyFilters => 'Apply';

  @override
  String get taskClearFilters => 'Clear filters';

  @override
  String get taskTitleField => 'Title';

  @override
  String get taskDescription => 'Description';

  @override
  String get taskLocation => 'Room / location';

  @override
  String get taskType => 'Request type';

  @override
  String get taskAssignee => 'Assign to';

  @override
  String get taskLinkedItem => 'Linked inventory item';

  @override
  String get taskChooseItem => 'Choose inventory item';

  @override
  String get taskSearchItems => 'Search inventory';

  @override
  String get taskClearLink => 'Remove link';

  @override
  String get taskNoItems => 'No matching inventory items.';

  @override
  String get taskNoDueDate => 'No due date';

  @override
  String get taskClearDate => 'Clear date';

  @override
  String get taskSave => 'Save request';

  @override
  String get taskSaving => 'Saving…';

  @override
  String get taskDiscardDraft => 'Discard draft';

  @override
  String get taskDraftNote =>
      'Changes are saved as a draft on this device. They are sent only when you save. Photos are not saved in drafts.';

  @override
  String get taskDraftRestored => 'Your saved draft has been restored.';

  @override
  String get taskAddPhoto => 'Attach photo';

  @override
  String get taskRemovePhoto => 'Remove photo';

  @override
  String get taskPhotoSelected => 'Photo selected';

  @override
  String get taskUploading => 'Uploading photo…';

  @override
  String get taskPhotoLimit =>
      'Choose a JPEG, PNG or WebP up to 5 MiB and 16 MP.';

  @override
  String get taskPhotoPartial =>
      'The request was saved, but its photo could not be uploaded. Add the photo from task details.';

  @override
  String get taskTitleRequired => 'Enter a title.';

  @override
  String get taskCommentRequired => 'Write a comment.';

  @override
  String get taskInvalidDate => 'Choose a valid date.';

  @override
  String get taskCreate => 'Create Task';

  @override
  String get taskEdit => 'Edit';

  @override
  String get taskRefresh => 'Refresh';

  @override
  String get taskLoadMore => 'Load more';

  @override
  String get taskEmpty => 'No tasks yet. Create a request to get started.';

  @override
  String get taskNoResults => 'No tasks match these filters.';

  @override
  String get taskCached =>
      'Showing saved tasks. Reconnect and refresh before making changes.';

  @override
  String get taskError =>
      'Could not load or save the request. Check your connection and try again.';

  @override
  String get taskNetworkError =>
      'You are offline. Saved requests and local drafts remain available.';

  @override
  String get taskConflict =>
      'This request changed. Refresh to review the latest version before saving again.';

  @override
  String get taskForbidden =>
      'You no longer have access, or this action is restricted to its author or an administrator.';

  @override
  String get taskInvalidReference =>
      'Choose a current household member and an inventory item from this household.';

  @override
  String get taskAlreadyClaimed =>
      'Someone has already taken ownership. Refresh to see the assignee.';

  @override
  String get taskReopenRequired =>
      'Reopen this request explicitly before changing its status.';

  @override
  String get taskNotAvailable => 'This request is no longer available.';

  @override
  String get taskTakeOwnership => 'Take Ownership';

  @override
  String get taskChangePriority => 'Change Priority';

  @override
  String get taskChangeStatus => 'Change Status';

  @override
  String get taskComplete => 'Mark Completed';

  @override
  String get taskReopen => 'Reopen';

  @override
  String get taskCancel => 'Cancel Request';

  @override
  String get taskArchive => 'Archive';

  @override
  String get taskRestore => 'Restore';

  @override
  String get taskArchiveQuestion => 'Archive this request?';

  @override
  String get taskArchiveHelp =>
      'It will remain available under the Archived filter.';

  @override
  String get taskRestoreQuestion => 'Restore this request?';

  @override
  String get taskConfirm => 'Confirm';

  @override
  String get taskDismiss => 'Cancel';

  @override
  String get taskKeepCondition => 'Keep Current Condition';

  @override
  String get taskMarkWorking => 'Mark as Working';

  @override
  String get taskConditionQuestion =>
      'Would you also like to update this item\'s condition?';

  @override
  String get taskConditionHelp =>
      'The repair is completed. Updating the linked inventory item is a separate action.';

  @override
  String get taskConditionFailed =>
      'The repair remains completed. The inventory condition update failed; refresh the item and try again from inventory.';

  @override
  String get taskCompletionNote => 'Completion note (optional)';

  @override
  String get taskCompletionHistory => 'Completion note';

  @override
  String get taskComments => 'Discussion';

  @override
  String get taskAddComment => 'Write a comment…';

  @override
  String get taskSendComment => 'Send';

  @override
  String get taskEditComment => 'Edit comment';

  @override
  String get taskDeleteComment => 'Delete comment';

  @override
  String get taskDeleteCommentQuestion => 'Delete this comment?';

  @override
  String get taskNoComments => 'No comments yet.';

  @override
  String get taskActivity => 'Activity';

  @override
  String get taskNoActivity => 'No activity available.';

  @override
  String get taskAttachments => 'Photos';

  @override
  String get taskNoAttachments => 'No photos attached.';

  @override
  String get taskViewPhoto => 'View photo';

  @override
  String get taskRefreshPhoto => 'Refresh photo';

  @override
  String get taskPhotoError =>
      'Photo unavailable. Refresh for a new authorized link.';

  @override
  String get taskRemovePhotoQuestion => 'Remove this photo?';

  @override
  String get taskFormerMember => 'Former household member';

  @override
  String get taskSystem => 'System';

  @override
  String get taskCreatedBy => 'Created by';

  @override
  String get taskAssignedTo => 'Assigned to';

  @override
  String get taskUpdated => 'Updated';

  @override
  String get taskRelatedRepairs => 'Related repair requests';

  @override
  String get taskReportRepair => 'Report a repair';

  @override
  String get taskAllRelated => 'View all related repairs';

  @override
  String get taskNoRelated => 'No related repairs.';

  @override
  String get taskReassign => 'Assign / Reassign';

  @override
  String get taskUnassign => 'Unassign';

  @override
  String get taskReopenedHelp =>
      'Reopening keeps previous completion events in Activity.';

  @override
  String get taskCommentPhoto => 'Add photo to comment';

  @override
  String get taskSaved => 'Request saved.';

  @override
  String get taskDone => 'Done';

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

  @override
  String get shoppingSubtitle => 'Everything your family needs.';

  @override
  String get shoppingAdd => 'Add Item';

  @override
  String get shoppingAddToList => 'Add to List';

  @override
  String get shoppingToBuy => 'To Buy';

  @override
  String get shoppingPurchased => 'Purchased';

  @override
  String get shoppingCancelled => 'Cancelled';

  @override
  String get shoppingQuickAdd => 'Add something to buy';

  @override
  String get shoppingName => 'Item name';

  @override
  String get shoppingQuantity => 'Quantity';

  @override
  String get shoppingUnit => 'Unit';

  @override
  String get shoppingNoUnit => 'No unit';

  @override
  String get shoppingNotes => 'Notes & preferences';

  @override
  String get shoppingMarkPurchased => 'Mark Purchased';

  @override
  String get shoppingUndo => 'Undo Purchase';

  @override
  String get shoppingClaim => 'I’ll Buy This';

  @override
  String get shoppingActualQuantity => 'Actual quantity (optional)';

  @override
  String get shoppingPrice => 'Purchase price (optional)';

  @override
  String get shoppingCurrency => 'Currency';

  @override
  String get shoppingNote => 'Completion note (optional)';

  @override
  String get shoppingInventoryQuestion => 'Update household inventory?';

  @override
  String get shoppingInventoryHelp =>
      'Add this purchased quantity to your linked inventory? This action applies this purchase at most once.';

  @override
  String get shoppingNotNow => 'Not Now';

  @override
  String get shoppingUpdateInventory => 'Update Inventory';

  @override
  String get shoppingInventorySuccess => 'Inventory update confirmed.';

  @override
  String get shoppingInventoryFailure =>
      'The purchase remains saved. Inventory was not confirmed updated. You can retry safely from this item.';

  @override
  String get shoppingInventoryApplied =>
      'This purchase has already been applied to inventory.';

  @override
  String get shoppingUndoHelp =>
      'Reopen this purchase? Any stock already added will remain unchanged. Review inventory separately if it needs correction.';

  @override
  String get shoppingUndoSuccess =>
      'Purchase reopened. Review inventory separately if stock was already added.';

  @override
  String get shoppingPurchaseSuccess => 'Purchase saved.';

  @override
  String get shoppingUnitError =>
      'Choose the linked consumable’s exact unit and a quantity before purchasing. Unit conversion is not supported.';

  @override
  String get shoppingChanged =>
      'This purchase changed or is closed. Refresh and reopen it before editing.';

  @override
  String get shoppingDuplicate =>
      'This inventory item is already on your shopping list.';

  @override
  String get shoppingViewExisting => 'View Existing Request';

  @override
  String get shoppingAddAnother => 'Add Another Request';

  @override
  String get shoppingHistory => 'Purchase history';

  @override
  String get shoppingNoHistory => 'No saved purchase history yet.';

  @override
  String get shoppingEmpty =>
      'Your shopping list is empty. Add something your household needs.';

  @override
  String get shoppingAllPurchased =>
      'Everything in this list has been purchased.';

  @override
  String get shoppingRefreshNote =>
      'Pull to refresh. The list also refreshes when you return to the app.';

  @override
  String get shoppingNumberError =>
      'Enter a positive amount with up to 12 whole digits and 3 decimal places.';

  @override
  String get shoppingPriceError =>
      'Enter a nonnegative amount with up to 13 whole digits and 2 decimal places, and select a supported currency.';

  @override
  String get shoppingRequestedBy => 'Requested by';

  @override
  String get shoppingPurchasedBy => 'Purchased by';

  @override
  String shoppingProgress(int purchased, int total) {
    return '$purchased of $total items purchased';
  }

  @override
  String shoppingOutstanding(int active, int high, int mine) {
    return '$active to buy · $high high priority · $mine assigned to you';
  }

  @override
  String get shoppingNewest => 'Newest first';

  @override
  String get shoppingListTitle => 'Shopping List';

  @override
  String get shoppingSearch => 'Search shopping items';

  @override
  String get shoppingDraftNote =>
      'Your draft is saved on this device. Changes reach your household only when you save.';

  @override
  String get shoppingNoResults => 'No shopping items match these filters.';

  @override
  String get shoppingBeingHandled => 'Being Handled';
}
