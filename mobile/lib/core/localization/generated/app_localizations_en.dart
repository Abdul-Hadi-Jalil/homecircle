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
  String get login => 'Sign In';

  @override
  String get register => 'Create Account';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get resetPassword => 'Set a new password';

  @override
  String get email => 'Email Address';

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
  String get createHousehold => 'Create Household';

  @override
  String get joinHousehold => 'Join Household';

  @override
  String get inviteFamily => 'Invite Family Members';

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
  String get familyActivity => 'Family Activity';

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
  String get onboardTeamTitle => 'Share responsibilities without the friction.';

  @override
  String get onboardSyncTitle => 'Your whole household, effortlessly in sync.';

  @override
  String get onboardItems =>
      'Keep track of household items, supplies, and everything your family needs before you run out.';

  @override
  String get onboardTeam =>
      'A little teamwork makes home easier. Create tasks, report issues, and keep everyone informed.';

  @override
  String get onboardSync =>
      'Share messages, collaborate on shopping lists in real-time, and celebrate getting things done together.';

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
  String get householdConnection => 'Household Connection';

  @override
  String get householdConnectionDescription =>
      'New to HomeCircle? Creating an account connects you to your family household in the next step with an invite code.';

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
  String get adminNotice => 'You\'ll be the Household Admin';

  @override
  String get adminDescription =>
      'You can invite family members, assign roles, and manage household settings anytime.';

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
  String get shareInvitation => 'Share Invite';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0 · $role';
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
  String get fullName => 'Family Member Name';

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

  @override
  String get chatTitle => 'Family Chat';

  @override
  String get chatComposer => 'Message your family…';

  @override
  String get chatSend => 'Send message';

  @override
  String chatMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopy => 'Copy Text';

  @override
  String get chatCreateTask => 'Create Task from Message';

  @override
  String get chatEdit => 'Edit Message';

  @override
  String get chatDelete => 'Delete Message';

  @override
  String get chatDeleteHelp =>
      'Delete this message? Replies will show a deleted preview.';

  @override
  String get chatDeleted => 'This message was deleted.';

  @override
  String get chatReplyUnavailable =>
      'Original message is unavailable or deleted.';

  @override
  String get chatEdited => 'Edited';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatUploading => 'Uploading image…';

  @override
  String get chatAttach => 'Attach image';

  @override
  String get chatViewImage => 'View image';

  @override
  String get chatImageUnavailable =>
      'Image unavailable. Refresh the link to try again.';

  @override
  String get chatShareTask => 'Share Task';

  @override
  String get chatTaskUnavailable => 'Task unavailable';

  @override
  String get chatOlder => 'Load older messages';

  @override
  String get chatEmpty =>
      'Start your household conversation. Send a message to your family.';

  @override
  String get chatCached =>
      'Showing saved messages. They may have changed since your last connection.';

  @override
  String get chatReconnecting =>
      'Realtime is reconnecting or unavailable. Messages refresh when connectivity returns.';

  @override
  String get chatOffline =>
      'Connection lost. Saved messages and drafts remain available.';

  @override
  String get chatConflict =>
      'This message changed. Review the refreshed message before trying again.';

  @override
  String get chatAccessRevoked =>
      'Chat access could not be confirmed. Reconnect and check your household membership.';

  @override
  String get chatRateLimited =>
      'Too many chat actions. Please wait a moment and try again.';

  @override
  String get chatRetryOriginal =>
      'This request ID belongs to an earlier send. Retry the original message or refresh the conversation.';

  @override
  String get chatFailure =>
      'The action was not confirmed. Retry or refresh the conversation.';

  @override
  String get chatCacheError =>
      'Secure local storage is unavailable. Your latest chat or draft may not be saved on this device.';

  @override
  String get chatReselectImage => 'Select image again';

  @override
  String get chatDiscardPending => 'Discard local draft';

  @override
  String get chatPendingLimit =>
      'Retry or discard a failed send before adding more. Up to 20 failed sends can be saved.';

  @override
  String get chatEmptyText => 'Enter message text.';

  @override
  String chatNewMessages(int count) {
    return '$count new messages';
  }

  @override
  String get chatSave => 'Save';

  @override
  String get chatFailed => 'Failed to send';

  @override
  String hubMorning(String name) {
    return 'Good morning, $name 👋';
  }

  @override
  String hubAfternoon(String name) {
    return 'Good afternoon, $name 👋';
  }

  @override
  String hubEvening(String name) {
    return 'Good evening, $name 👋';
  }

  @override
  String get hubMember => 'Family member';

  @override
  String get hubGlance => 'Your home at a glance';

  @override
  String get hubQuick => 'Quick Actions';

  @override
  String get hubPending => 'Pending Tasks';

  @override
  String get hubUrgent => 'Urgent Issues';

  @override
  String get hubShopping => 'Shopping Items';

  @override
  String get hubLowStock => 'Low-Stock Items';

  @override
  String get hubOutStock => 'Out of Stock';

  @override
  String get hubOverdue => 'Overdue Tasks';

  @override
  String get hubMine => 'My Tasks';

  @override
  String get hubAddItem => 'Add Item';

  @override
  String get hubRequest => 'Request Item';

  @override
  String get hubReport => 'Report Issue';

  @override
  String get hubMessage => 'Send Message';

  @override
  String get hubAttention => 'Needs Attention';

  @override
  String get hubUpcoming => 'Upcoming Tasks';

  @override
  String get hubRecent => 'Recent Activity';

  @override
  String get hubViewAll => 'See All';

  @override
  String get hubEmptyTitle => 'Your home starts here!';

  @override
  String get hubEmptyBody =>
      'Add your first item or task to start organizing your family.';

  @override
  String get hubFirstItem => 'Add First Item';

  @override
  String get hubNoAttention => 'Nothing needs attention right now.';

  @override
  String get hubNoUpcoming => 'No tasks due in the next seven days.';

  @override
  String get hubCached =>
      'Offline cached view — reconnect for current information.';

  @override
  String hubUpdated(String time) {
    return 'Last refreshed: $time';
  }

  @override
  String hubZone(String zone) {
    return 'Household time zone: $zone';
  }

  @override
  String get hubActivitySubtitle => 'See what\'s been happening at home.';

  @override
  String get hubAll => 'All';

  @override
  String get hubInventory => 'Inventory';

  @override
  String get hubTasks => 'Tasks';

  @override
  String get hubRepairs => 'Repairs';

  @override
  String get hubMembers => 'Members';

  @override
  String get hubNoActivity => 'No matching activity yet.';

  @override
  String get hubDateRange => 'Filter by date';

  @override
  String get hubClearDates => 'Clear dates';

  @override
  String get hubToday => 'Today';

  @override
  String get hubYesterday => 'Yesterday';

  @override
  String get hubEarlier => 'Earlier';

  @override
  String get hubFormer => 'Former member';

  @override
  String get hubCreated => 'Added';

  @override
  String get hubUpdatedAction => 'Updated';

  @override
  String get hubCompleted => 'Completed';

  @override
  String get hubPurchased => 'Purchased';

  @override
  String get hubArchived => 'Archived';

  @override
  String get hubRestored => 'Restored';

  @override
  String get hubAssigned => 'Assigned';

  @override
  String get hubReopened => 'Reopened';

  @override
  String get hubCancelled => 'Cancelled';

  @override
  String get hubJoined => 'Joined';

  @override
  String get hubLeft => 'Left';

  @override
  String get hubRole => 'Changed member role';

  @override
  String get hubComment => 'Updated a discussion';

  @override
  String get hubPhoto => 'Updated an attachment';

  @override
  String get hubStock => 'Updated stock';

  @override
  String get hubCondition => 'Updated condition';

  @override
  String hubActivityDetail(String actor, String action) {
    return '$actor · $action';
  }

  @override
  String get hubNotifications => 'Notifications';

  @override
  String get hubReadAll => 'Mark All as Read';

  @override
  String get hubUnread => 'Unread only';

  @override
  String get hubRead => 'Mark read';

  @override
  String get hubDismiss => 'Dismiss';

  @override
  String get hubCaughtUp => 'All caught up!';

  @override
  String get hubCaughtUpBody =>
      'You\'re up to date with everything happening at home.';

  @override
  String get hubNoUnread => 'No unread notifications.';

  @override
  String get hubNotifySettings => 'Notification Settings';

  @override
  String get hubSaved => 'Settings saved.';

  @override
  String get hubTaskUpdates => 'Task updates';

  @override
  String get hubShoppingUpdates => 'Shopping updates';

  @override
  String get hubInventoryAlerts => 'Inventory alerts';

  @override
  String get hubChatUpdates => 'Family chat';

  @override
  String get hubMentions => 'Mentions';

  @override
  String get hubPush => 'Push notifications';

  @override
  String get hubPushExplanation =>
      'Push permission controls alerts on this device. In-app notifications are saved even when device permission is denied.';

  @override
  String get hubEnablePush => 'Enable device notifications';

  @override
  String get hubPushDenied =>
      'Device notifications are disabled. You can enable them in Android system settings.';

  @override
  String get hubPushUnavailable =>
      'Push is not configured on this device. In-app notifications still work.';

  @override
  String get hubPushAllowed => 'Device notifications are allowed.';

  @override
  String get hubPushRegistration =>
      'Push registration could not be confirmed. Reopen settings to retry.';

  @override
  String get hubForeground => 'A household update is available.';

  @override
  String get hubOpen => 'Open';

  @override
  String get hubUnavailable =>
      'This record is unavailable or you no longer have access.';

  @override
  String get hubLoadFailed =>
      'Could not load household updates. Refresh to try again.';

  @override
  String get hubMention => 'Mention a member';

  @override
  String get hubRemoveMention => 'Remove mention';

  @override
  String get hubNeedsRepair => 'Needs Repair';

  @override
  String get hubBroken => 'Broken';

  @override
  String get hubMemberAdded => 'Added member';

  @override
  String get hubMemberRemoved => 'Removed member';

  @override
  String hubUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get onboardBrandTag => 'Family Sync';

  @override
  String get onboardTab1 => '1. Organize';

  @override
  String get onboardTab2 => '2. Share';

  @override
  String get onboardTab3 => '3. Connect';

  @override
  String onboardStepCounter(int step) {
    return 'Step $step of 3';
  }

  @override
  String get onboardHaveAccount => 'Already have an account?';

  @override
  String get onboardSignIn => 'Sign In';

  @override
  String get demoPantry => 'Pantry & Supplies';

  @override
  String get demoRestocked => 'Restocked';

  @override
  String get demoOatMilk => 'Oat Milk & Coffee';

  @override
  String get demoDetergent => 'Eco Detergent';

  @override
  String get demoTwoLeft => '2 Left';

  @override
  String get demoSmartAlert => 'Smart Low Alert';

  @override
  String get demoMomUpdated => 'Mom updated shelf';

  @override
  String get demoChores => 'Household Chore Rotation';

  @override
  String get demoFairSplit => 'Fair Split';

  @override
  String get demoBins => 'Take Out Bins';

  @override
  String get demoDone => 'Done';

  @override
  String get demoPlants => 'Water Balcony Plants';

  @override
  String get demoToday => 'Today';

  @override
  String get demoNoNagging => 'No More Nagging';

  @override
  String get demoStream => 'Shared Family Stream';

  @override
  String get demoDadMarket => 'Dad • Market';

  @override
  String get demoTwoMin => '2m ago';

  @override
  String get demoSourdough => 'Grabbed the sourdough! Anything else?';

  @override
  String get demoEmma => 'Emma';

  @override
  String get demoJustNow => 'Just now';

  @override
  String get demoAvocados => 'Avocados are on the kitchen list! 🥑';

  @override
  String get demoInstantSync => 'Instant Family Sync';

  @override
  String get authBrandTag => 'Household Sync';

  @override
  String get forgotPasswordLink => 'Forgot Password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get authFailedTitle => 'Something went wrong';

  @override
  String get invalidCredentialsTitle => 'Invalid credentials';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get householdConnectionStep => 'Step 1 of 2';

  @override
  String get fullNameHint => 'e.g. Abu Bakr';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get setupBadge => 'Welcome to HomeCircle';

  @override
  String get setupTitle => 'Let\'s set up your home';

  @override
  String get setupSubtitle =>
      'Create a space for your family or join one they\'ve already created.';

  @override
  String get familyTip => 'Family Tip';

  @override
  String get familyTipBody =>
      'Family members living together should join the same household rather than creating separate spaces.';

  @override
  String get createCardTitle => 'Create a Household';

  @override
  String get recommendedHeads => 'Recommended for Heads';

  @override
  String get createCardBody =>
      'Start a new family space, become admin, and invite everyone to coordinate chores, groceries, and shared plans.';

  @override
  String get adminControls => 'Admin Controls';

  @override
  String get inviteLinkCode => 'Invite Code';

  @override
  String get joinCardTitle => 'Join a Household';

  @override
  String get gotInvite => 'Got an invite?';

  @override
  String get joinCardBody =>
      'Already invited by someone? Join your family\'s existing space with an invite code.';

  @override
  String get enterInviteCode => 'Enter Household Invitation Code';

  @override
  String get codeCharacters => '16 Characters';

  @override
  String get inviteCodeHint => 'HC-XXXX-XXXX-XXXX-XXXX';

  @override
  String get paste => 'Paste';

  @override
  String get findHousehold => 'Find Household';

  @override
  String get foundLabel => 'Found';

  @override
  String membersActive(int count) {
    return '$count members active';
  }

  @override
  String get invalidCodeHelp =>
      'Invalid code? Contact your household admin or verify the 16-character code.';

  @override
  String get needHelpSetup => 'Need help setting up?';

  @override
  String get askResendCode => 'Ask another member to resend the code';

  @override
  String get faq => 'FAQ';

  @override
  String get faqTitle => 'Setting up your home';

  @override
  String get faqJoinQ => 'Who should create the household?';

  @override
  String get faqJoinA =>
      'One adult creates it and becomes the admin. Everyone else joins with an invite code.';

  @override
  String get faqCodeQ => 'Where do I get an invite code?';

  @override
  String get faqCodeA =>
      'A household admin can generate one from Invite Family. Codes expire, so ask for a new one if yours stops working.';

  @override
  String get faqMultiQ => 'Can I belong to more than one household?';

  @override
  String get faqMultiA =>
      'Yes. You can switch between households from your profile at any time.';

  @override
  String get createTitle => 'Create Your Household';

  @override
  String get createSubtitle => 'Give your family space a name and personality.';

  @override
  String get householdAvatar => 'Household Avatar';

  @override
  String get cozyIcon => 'Cozy Icon';

  @override
  String selectedAvatar(String name) {
    return 'Selected: $name';
  }

  @override
  String get avatarCottage => 'Warm Family Cottage';

  @override
  String get avatarApartment => 'City Loft & Nest';

  @override
  String get avatarForest => 'Cabin in Woods';

  @override
  String get avatarPets => 'Pet Haven Hub';

  @override
  String get avatarFavorite => 'Heart of Family';

  @override
  String get householdNameLabel => 'Household Name';

  @override
  String get householdNamePlaceholder => 'e.g., The Miller Nest, Sunny Haven';

  @override
  String get visibleToMembers => 'Visible to all invited members and guests.';

  @override
  String get householdDescriptionLabel => 'Household Description';

  @override
  String get optional => 'Optional';

  @override
  String get descriptionPlaceholder => 'What is this household for?';

  @override
  String get helpsStaySynced =>
      'Helps everyone stay synced on routines and duties.';

  @override
  String get back => 'Back';

  @override
  String get inviteSetupBadge => 'Household Setup';

  @override
  String get inviteYourFamily => 'Invite Your Family';

  @override
  String get inviteSubtitle =>
      'HomeCircle works better together. Keep everyone in sync on chores, groceries, and plans.';

  @override
  String createdByMembers(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Created by $name • $_temp0';
  }

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String membersActiveCap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Members Active',
      one: '1 Member Active',
    );
    return '$_temp0';
  }

  @override
  String get inviteCodeTitle => 'Household Invite Code';

  @override
  String validDays(int days) {
    return 'Valid $days days';
  }

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String get noActiveCode => 'No code yet';

  @override
  String get codeShareHelp =>
      'Share this code with family members so they can join your household instantly during onboarding.';

  @override
  String get inviteMessagePreview => 'Invitation Message Preview';

  @override
  String get previewPre => '“Hey! Join ';

  @override
  String get previewMid => ' on HomeCircle! Use invitation code ';

  @override
  String get previewPost => ' to link our shared chores and pantry lists.”';

  @override
  String joinedCount(int count) {
    return '$count Joined';
  }

  @override
  String joinedOn(String date) {
    return 'Joined $date';
  }

  @override
  String get joinedPill => 'Joined';

  @override
  String get revokeExisting => 'Revoke Existing Code';

  @override
  String get codeExpiryNote =>
      'Invitation codes expire after 7 days or can be revoked by admins at any time.';

  @override
  String get doneGoDashboard => 'Done (Go to Dashboard)';

  @override
  String activeCodeExpires(String date) {
    return 'Expires $date';
  }

  @override
  String agoMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String agoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String agoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String agoYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get agoJustNow => 'Just now';

  @override
  String get agoYesterday => 'Yesterday';

  @override
  String get membersHeading => 'Family Members';

  @override
  String get membersSubtitle => 'Admin controls and member permissions';

  @override
  String get statusActive => 'Active';

  @override
  String createdByName(String name) {
    return 'Created by $name';
  }

  @override
  String get editHousehold => 'Edit Household';

  @override
  String get youBadge => 'You';

  @override
  String get creatorSoleAdmin => 'Creator • Sole Admin';

  @override
  String joinedWhen(String when) {
    return 'Joined $when';
  }

  @override
  String get rolesPermissions => 'Roles & Permissions';

  @override
  String get rolesAdminsLabel => 'Admins';

  @override
  String get rolesAdminsText =>
      ' manage household details, invite or remove members, and control settings. ';

  @override
  String get rolesMembersLabel => 'Members';

  @override
  String get rolesMembersText =>
      ' can coordinate tasks, update pantry inventory, shop, and chat freely.';

  @override
  String get householdAccess => 'Household Access';

  @override
  String get householdAccessSubtitle =>
      'Invite family or roommates to sync in real-time';

  @override
  String get inviteNewMember => 'Invite New Member';

  @override
  String get inviteNewMemberSubtitle => 'Send a fast join code';

  @override
  String get manageInviteCodes => 'Manage Invitation Codes';

  @override
  String activeCodeDays(int days) {
    return 'Active code valid for $days more days';
  }

  @override
  String get noActiveCodeShort => 'No active code';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get dangerSubtitle => 'Irreversible and destructive actions';

  @override
  String get leaveHousehold => 'Leave Household';

  @override
  String get leaveSoleAdminText =>
      'You are currently the sole admin. You must assign another member as admin before leaving.';

  @override
  String get leaveText =>
      'You will lose access to this household\'s lists, inventory, chores and messages.';

  @override
  String get leaveConfirm =>
      'Leave this household? You will need a new invite to join again.';

  @override
  String get deleteHouseholdTitle => 'Delete Household';

  @override
  String get deleteHouseholdText =>
      'Admin only. Permanently erases all lists, shared inventory items, chores, messages, and member links.';

  @override
  String get deleteHouseholdButton => 'Delete Household Permanently';

  @override
  String get deleteConfirm =>
      'Delete this household permanently? This cannot be undone.';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get makeMember => 'Make member';

  @override
  String get removeMember => 'Remove from household';

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name from this household?';
  }

  @override
  String memberOptions(String name) {
    return 'Member options for $name';
  }

  @override
  String get editHouseholdTitle => 'Edit Household';

  @override
  String get lastAdminError =>
      'A household needs at least one admin. Assign another admin first.';

  @override
  String get activeCodeLabel => 'Active code';

  @override
  String get noActiveCodeBody => 'Generate a code to invite your family.';

  @override
  String get hubHistory => 'History';

  @override
  String get hubFrequent => 'Frequent';

  @override
  String get hubGlanceSub => 'Synchronized in real-time';

  @override
  String hubUpdatedAgo(String when) {
    return 'Updated $when';
  }

  @override
  String get hubAddItemSub => 'To pantry or list';

  @override
  String get hubRequestSub => 'Ask a member';

  @override
  String get hubReportSub => 'Repairs & fixes';

  @override
  String get hubMessageSub => 'Household chat';

  @override
  String hubHighCount(int count) {
    return '$count high';
  }

  @override
  String get hubKindRepair => 'Repair';

  @override
  String get hubKindShopping => 'Shopping';

  @override
  String get hubKindChore => 'Chore';

  @override
  String get hubKindGeneral => 'General';

  @override
  String get hubKindInventory => 'Inventory';

  @override
  String hubAssignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String hubStatusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String hubDueOn(String date) {
    return 'Due $date';
  }

  @override
  String hubActivityLine(Object action, Object actor, Object title) {
    return '$actor $action $title';
  }

  @override
  String membersCountCap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Members',
      one: '1 Member',
    );
    return '$_temp0';
  }

  @override
  String get profileNameLabel => 'Full Name';

  @override
  String agoMinutesShort(int n) {
    return '${n}m ago';
  }

  @override
  String agoHoursShort(int n) {
    return '${n}h ago';
  }

  @override
  String agoDaysShort(int n) {
    return '${n}d ago';
  }

  @override
  String get hubLowStockShort => 'Low Stock';

  @override
  String get hubDueToday => 'Due today';

  @override
  String get hubDueTomorrow => 'Due tomorrow';

  @override
  String get hubShoppingShort => 'Shopping Items';

  @override
  String get profileTitle => 'Profile & Settings';

  @override
  String get profileSubtitle =>
      'Manage your personal details and household rules';

  @override
  String get householdAdminBadge => 'Household Admin';

  @override
  String get householdMemberBadge => 'Household Member';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String myHouseholdLine(int count, String role) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Members active',
      one: '1 Member active',
    );
    return '$_temp0 • $role';
  }

  @override
  String get adminControlsRole => 'Admin controls';

  @override
  String get memberAccessRole => 'Member access';

  @override
  String get manageHousehold => 'Manage Household';

  @override
  String get myActivity => 'My Activity';

  @override
  String get liveOverview => 'Live overview';

  @override
  String get myAssignedTasks => 'My Assigned Tasks';

  @override
  String get myRequests => 'My Requests';

  @override
  String get myCompletedTasks => 'My Completed Tasks';

  @override
  String countActive(int count) {
    return '$count active';
  }

  @override
  String countOpen(int count) {
    return '$count open';
  }

  @override
  String countDone(int count) {
    return '$count done';
  }

  @override
  String get preferencesHeading => 'Preferences';

  @override
  String get notifSubOn => 'Push & In-App enabled';

  @override
  String get notifSubOff => 'Push notifications off';

  @override
  String get appLanguage => 'App Language';

  @override
  String get languageValue => 'English (US)';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceValue => 'System Default';

  @override
  String get highContrast => 'High Contrast Mode';

  @override
  String get highContrastOff => 'Standard text rendering';

  @override
  String get highContrastOn => 'Bold, high-contrast text';

  @override
  String get accountSecurity => 'Account & Security';

  @override
  String get changePassword => 'Change Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get passwordChangedToast => 'Password updated';

  @override
  String get privacySecurity => 'Privacy & Security';

  @override
  String get privacyBody =>
      'Your data lives in a private database. Only members of your household can see its inventory, tasks, shopping lists and messages. Photos are kept in private storage, and invitation codes are stored only as one-way hashes.';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get helpMore =>
      'Still stuck? Ask your household admin to send a fresh invitation or check your connection and try again.';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutTitle => 'Sign out of HomeCircle?';

  @override
  String get signOutPre => 'You will need to sign in again to access ';

  @override
  String get signOutPost => ' chores, alerts, and pantry inventory.';

  @override
  String get madeForFamily => 'Made for family harmony';

  @override
  String get quickSettings => 'Quick Settings';

  @override
  String get close => 'Close';

  @override
  String taskRequestedBy(String name) {
    return 'Requested by $name';
  }

  @override
  String taskDueLabel(String when) {
    return 'Due: $when';
  }

  @override
  String get taskToday => 'Today';

  @override
  String get taskTomorrow => 'Tomorrow';

  @override
  String get taskActionComplete => 'Mark Complete';

  @override
  String get taskActionTake => 'Take Task';

  @override
  String get taskActionUpdate => 'Update Status';

  @override
  String get taskNewTask => 'New Task';

  @override
  String get taskAllClear => 'All clear for now!';

  @override
  String get taskAllClearBody =>
      'There are no active household tasks or requests. Everything at home is running smoothly.';

  @override
  String get taskCaughtUp => 'Household is all caught up';

  @override
  String get taskFilteredEmpty => 'Filtered view empty';

  @override
  String get taskFilteredEmptyBody => 'No requests match your current filters.';

  @override
  String get taskOfflineTitle => 'You\'re offline • Showing cached tasks';

  @override
  String get taskCouldntRefresh => 'Couldn\'t refresh tasks';

  @override
  String get taskSortBy => 'Sort by';

  @override
  String taskAssignedToName(String name) {
    return 'Assigned to $name';
  }

  @override
  String get taskKindRepairs => 'Repairs';

  @override
  String get taskKindChores => 'Chores';

  @override
  String get taskDetailsHeading => 'Task Details';

  @override
  String get taskCellReported => 'Reported by';

  @override
  String get taskCellAssigned => 'Assigned to';

  @override
  String get taskCellDue => 'Due by';

  @override
  String get taskCellLocation => 'Location';

  @override
  String get taskTapReassign => 'Tap to reassign';

  @override
  String get taskTapAssign => 'Tap to assign';

  @override
  String get taskUrgentTurnaround => 'Urgent turnaround';

  @override
  String get taskProgressState => 'Progress State';

  @override
  String get taskSynchronized => 'Synchronized';

  @override
  String get taskOfflineShort => 'Offline';

  @override
  String get taskSegProgress => 'Progress';

  @override
  String get taskSegDone => 'Done';

  @override
  String get taskMarkCompleted => 'Mark as Completed';

  @override
  String get taskNotifyHint =>
      'Your household is notified when you complete a request.';

  @override
  String get taskDiscussion => 'Discussion';

  @override
  String taskCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String get taskSharedWithHousehold => 'Shared with household';

  @override
  String get taskWriteUpdate => 'Write an update...';

  @override
  String get taskActivityLog => 'Activity Log';

  @override
  String taskEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get taskMoreOptions => 'More options';

  @override
  String get taskLoadPhoto => 'Load photo';

  @override
  String get taskLocationNone => 'Not specified';

  @override
  String get taskFormIntro =>
      'Let your family know what needs to be done. We\'ll alert the right household member right away!';

  @override
  String get taskStepKind => '1. What kind of request?';

  @override
  String get taskRequiredTag => 'REQUIRED';

  @override
  String get taskKindShoppingSub => 'Need to buy';

  @override
  String get taskKindRepairSub => 'Needs fixing';

  @override
  String get taskKindChoreSub => 'Routine tasks';

  @override
  String get taskKindGeneralSub => 'Other family note';

  @override
  String get taskWhatNeeds => 'What needs to be done?';

  @override
  String get taskTapEdit => 'Tap to edit';

  @override
  String get taskDescContext => 'Description & Context';

  @override
  String get taskDiagnostics => 'Repair Diagnostics';

  @override
  String get taskRepairActive => 'Repair Active';

  @override
  String get taskAffected => 'Affected Item / Room';

  @override
  String get taskLinkChange => 'Change';

  @override
  String taskLinkPrefix(String name) {
    return 'Inventory link: $name';
  }

  @override
  String get taskLinkNone => 'Link an inventory item';

  @override
  String get taskPhotoEvidence => 'Photo Evidence';

  @override
  String taskPhotoCount(int count) {
    return '$count of 1 uploaded';
  }

  @override
  String get taskAddPhotoShort => 'Add photo';

  @override
  String get taskMaxSize => 'Max 5MB';

  @override
  String get taskPriorityLevel => 'Priority Level';

  @override
  String get taskNeedsFast => 'Needs fast attention';

  @override
  String get taskAssignResp => 'Assign Responsibility';

  @override
  String get taskWhoHandles => 'Who will handle this?';

  @override
  String taskSelectedCount(int count) {
    return '$count Selected';
  }

  @override
  String get taskAnyone => 'Anyone';

  @override
  String get taskTargetCompletion => 'Target Completion';

  @override
  String get taskPickDate => 'Pick date';

  @override
  String get taskThisWeekend => 'This Weekend';

  @override
  String get taskDraftSaved => 'Draft saved on this device';

  @override
  String get shoppingTapCheckbox => 'Tap checkbox to mark purchased';

  @override
  String shoppingLinkedTo(String name) {
    return 'Linked to $name';
  }

  @override
  String get shoppingQuickHint => '+ Add something to buy...';

  @override
  String get shoppingStockNote =>
      'Purchasing an item notifies the household without auto-updating physical stock until confirmed.';

  @override
  String get shoppingUndoShort => 'Undo';

  @override
  String get shoppingFiltersTooltip => 'Filters';

  @override
  String get shoppingAddItemTitle => 'Add Shopping Item';

  @override
  String get shoppingSheetTitle => 'Add to Shopping List';

  @override
  String get shoppingSheetSubtitle => 'What should we replenish next?';

  @override
  String get shoppingAutoSuggest => 'Fast auto-suggest';

  @override
  String get shoppingQtyMeasure => 'Quantity & Measure';

  @override
  String get shoppingAmount => 'Amount';

  @override
  String get shoppingUrgency => 'Urgency Level';

  @override
  String get shoppingLinkInventory => 'Link to Inventory';

  @override
  String get shoppingStockHint =>
      'Asks before updating stock when marked purchased';

  @override
  String get shoppingAssignedFor => 'Assigned for trip by';

  @override
  String get shoppingFamilyShared => 'Family shared';

  @override
  String get shoppingAddShort => 'Add';

  @override
  String get assignSheetTitle => 'Assign Family Member';

  @override
  String assignedCount(int count) {
    return '$count Assigned';
  }

  @override
  String get unassignedPool => 'Pool';

  @override
  String get resetLabel => 'Reset';

  @override
  String get applySelection => 'Apply Selection';

  @override
  String get chatCreateTaskChip => '+ Create Task';

  @override
  String get chatAddShoppingChip => '+ Add to Shopping';

  @override
  String get chatViewTask => 'View Task';

  @override
  String chatSharedKind(String kind) {
    return 'Household $kind Task';
  }

  @override
  String hubUpdatesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates',
      one: '1 update',
    );
    return '$_temp0';
  }

  @override
  String hubNewCount(int count) {
    return '$count new';
  }

  @override
  String get hubStaySynced => 'Stay updated with home sync';

  @override
  String get hubViewTask => 'View Task';

  @override
  String get hubViewShopping => 'View Shopping';

  @override
  String get hubViewItem => 'View Item';

  @override
  String get hubViewDetails => 'Details';

  @override
  String get hubOpenChat => 'Open Chat';

  @override
  String get hubPeace => 'Peace of Mind';

  @override
  String get hubOlderArchives => 'Looking for older archives?';

  @override
  String get hubHistoryArchive => 'History Archive';

  @override
  String hubAllCount(int count) {
    return 'All ($count)';
  }
}
