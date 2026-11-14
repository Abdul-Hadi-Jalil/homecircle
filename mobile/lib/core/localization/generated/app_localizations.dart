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

  /// No description provided for @taskAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get taskAny;

  /// No description provided for @taskActivityCreated.
  ///
  /// In en, this message translates to:
  /// **'Request created'**
  String get taskActivityCreated;

  /// No description provided for @taskActivityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Request updated'**
  String get taskActivityUpdated;

  /// No description provided for @taskActivityAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assignment changed'**
  String get taskActivityAssigned;

  /// No description provided for @taskActivityClaimed.
  ///
  /// In en, this message translates to:
  /// **'Ownership taken'**
  String get taskActivityClaimed;

  /// No description provided for @taskActivityUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Task unassigned'**
  String get taskActivityUnassigned;

  /// No description provided for @taskActivityPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority changed'**
  String get taskActivityPriority;

  /// No description provided for @taskActivityStatus.
  ///
  /// In en, this message translates to:
  /// **'Status changed'**
  String get taskActivityStatus;

  /// No description provided for @taskActivityCompleted.
  ///
  /// In en, this message translates to:
  /// **'Request completed'**
  String get taskActivityCompleted;

  /// No description provided for @taskActivityCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get taskActivityCancelled;

  /// No description provided for @taskActivityReopened.
  ///
  /// In en, this message translates to:
  /// **'Request reopened'**
  String get taskActivityReopened;

  /// No description provided for @taskActivityArchived.
  ///
  /// In en, this message translates to:
  /// **'Request archived'**
  String get taskActivityArchived;

  /// No description provided for @taskActivityRestored.
  ///
  /// In en, this message translates to:
  /// **'Request restored'**
  String get taskActivityRestored;

  /// No description provided for @taskActivityCommentAdded.
  ///
  /// In en, this message translates to:
  /// **'Comment added'**
  String get taskActivityCommentAdded;

  /// No description provided for @taskActivityCommentEdited.
  ///
  /// In en, this message translates to:
  /// **'Comment edited'**
  String get taskActivityCommentEdited;

  /// No description provided for @taskActivityCommentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get taskActivityCommentDeleted;

  /// No description provided for @taskActivityPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get taskActivityPhotoAdded;

  /// No description provided for @taskActivityPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get taskActivityPhotoRemoved;

  /// No description provided for @taskCommentPhotoPartial.
  ///
  /// In en, this message translates to:
  /// **'Your comment was posted, but its photo could not be uploaded. Add it to the comment from the discussion.'**
  String get taskCommentPhotoPartial;

  /// No description provided for @taskNoSavedView.
  ///
  /// In en, this message translates to:
  /// **'This view has not been saved on this device. Reconnect to load it.'**
  String get taskNoSavedView;

  /// No description provided for @taskScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks & Requests'**
  String get taskScreenTitle;

  /// No description provided for @taskScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your family on track.'**
  String get taskScreenSubtitle;

  /// No description provided for @taskCreateRequest.
  ///
  /// In en, this message translates to:
  /// **'Create Request'**
  String get taskCreateRequest;

  /// No description provided for @taskEditRequest.
  ///
  /// In en, this message translates to:
  /// **'Edit Request'**
  String get taskEditRequest;

  /// No description provided for @taskDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetailsTitle;

  /// No description provided for @taskRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get taskRepair;

  /// No description provided for @taskChore.
  ///
  /// In en, this message translates to:
  /// **'Chore'**
  String get taskChore;

  /// No description provided for @taskGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get taskGeneral;

  /// No description provided for @taskShoppingSoon.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get taskShoppingSoon;

  /// No description provided for @taskAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskAllTypes;

  /// No description provided for @taskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskLow;

  /// No description provided for @taskNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get taskNormal;

  /// No description provided for @taskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskHigh;

  /// No description provided for @taskUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskUrgent;

  /// No description provided for @taskOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskOpen;

  /// No description provided for @taskInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get taskInProgress;

  /// No description provided for @taskBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskBlocked;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskCompleted;

  /// No description provided for @taskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskCancelled;

  /// No description provided for @taskSearch.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get taskSearch;

  /// No description provided for @taskFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get taskFilters;

  /// No description provided for @taskAllTasks.
  ///
  /// In en, this message translates to:
  /// **'All Tasks'**
  String get taskAllTasks;

  /// No description provided for @taskAssignedToMe.
  ///
  /// In en, this message translates to:
  /// **'Assigned to Me'**
  String get taskAssignedToMe;

  /// No description provided for @taskUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @taskStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskStatus;

  /// No description provided for @taskDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get taskDueDate;

  /// No description provided for @taskOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskOverdue;

  /// No description provided for @taskDueBefore.
  ///
  /// In en, this message translates to:
  /// **'Due on or before'**
  String get taskDueBefore;

  /// No description provided for @taskDueAfter.
  ///
  /// In en, this message translates to:
  /// **'Due on or after'**
  String get taskDueAfter;

  /// No description provided for @taskSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get taskSort;

  /// No description provided for @taskSortPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority first'**
  String get taskSortPriority;

  /// No description provided for @taskSortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get taskSortUpdated;

  /// No description provided for @taskSortDue.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get taskSortDue;

  /// No description provided for @taskArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get taskArchived;

  /// No description provided for @taskApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get taskApplyFilters;

  /// No description provided for @taskClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get taskClearFilters;

  /// No description provided for @taskTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitleField;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescription;

  /// No description provided for @taskLocation.
  ///
  /// In en, this message translates to:
  /// **'Room / location'**
  String get taskLocation;

  /// No description provided for @taskType.
  ///
  /// In en, this message translates to:
  /// **'Request type'**
  String get taskType;

  /// No description provided for @taskAssignee.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get taskAssignee;

  /// No description provided for @taskLinkedItem.
  ///
  /// In en, this message translates to:
  /// **'Linked inventory item'**
  String get taskLinkedItem;

  /// No description provided for @taskChooseItem.
  ///
  /// In en, this message translates to:
  /// **'Choose inventory item'**
  String get taskChooseItem;

  /// No description provided for @taskSearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search inventory'**
  String get taskSearchItems;

  /// No description provided for @taskClearLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get taskClearLink;

  /// No description provided for @taskNoItems.
  ///
  /// In en, this message translates to:
  /// **'No matching inventory items.'**
  String get taskNoItems;

  /// No description provided for @taskNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get taskNoDueDate;

  /// No description provided for @taskClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get taskClearDate;

  /// No description provided for @taskSave.
  ///
  /// In en, this message translates to:
  /// **'Save request'**
  String get taskSave;

  /// No description provided for @taskSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get taskSaving;

  /// No description provided for @taskDiscardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get taskDiscardDraft;

  /// No description provided for @taskDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved as a draft on this device. They are sent only when you save. Photos are not saved in drafts.'**
  String get taskDraftNote;

  /// No description provided for @taskDraftRestored.
  ///
  /// In en, this message translates to:
  /// **'Your saved draft has been restored.'**
  String get taskDraftRestored;

  /// No description provided for @taskAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach photo'**
  String get taskAddPhoto;

  /// No description provided for @taskRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get taskRemovePhoto;

  /// No description provided for @taskPhotoSelected.
  ///
  /// In en, this message translates to:
  /// **'Photo selected'**
  String get taskPhotoSelected;

  /// No description provided for @taskUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get taskUploading;

  /// No description provided for @taskPhotoLimit.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG, PNG or WebP up to 5 MiB and 16 MP.'**
  String get taskPhotoLimit;

  /// No description provided for @taskPhotoPartial.
  ///
  /// In en, this message translates to:
  /// **'The request was saved, but its photo could not be uploaded. Add the photo from task details.'**
  String get taskPhotoPartial;

  /// No description provided for @taskTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title.'**
  String get taskTitleRequired;

  /// No description provided for @taskCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a comment.'**
  String get taskCommentRequired;

  /// No description provided for @taskInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid date.'**
  String get taskInvalidDate;

  /// No description provided for @taskCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get taskCreate;

  /// No description provided for @taskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get taskEdit;

  /// No description provided for @taskRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get taskRefresh;

  /// No description provided for @taskLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get taskLoadMore;

  /// No description provided for @taskEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Create a request to get started.'**
  String get taskEmpty;

  /// No description provided for @taskNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tasks match these filters.'**
  String get taskNoResults;

  /// No description provided for @taskCached.
  ///
  /// In en, this message translates to:
  /// **'Showing saved tasks. Reconnect and refresh before making changes.'**
  String get taskCached;

  /// No description provided for @taskError.
  ///
  /// In en, this message translates to:
  /// **'Could not load or save the request. Check your connection and try again.'**
  String get taskError;

  /// No description provided for @taskNetworkError.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Saved requests and local drafts remain available.'**
  String get taskNetworkError;

  /// No description provided for @taskConflict.
  ///
  /// In en, this message translates to:
  /// **'This request changed. Refresh to review the latest version before saving again.'**
  String get taskConflict;

  /// No description provided for @taskForbidden.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access, or this action is restricted to its author or an administrator.'**
  String get taskForbidden;

  /// No description provided for @taskInvalidReference.
  ///
  /// In en, this message translates to:
  /// **'Choose a current household member and an inventory item from this household.'**
  String get taskInvalidReference;

  /// No description provided for @taskAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'Someone has already taken ownership. Refresh to see the assignee.'**
  String get taskAlreadyClaimed;

  /// No description provided for @taskReopenRequired.
  ///
  /// In en, this message translates to:
  /// **'Reopen this request explicitly before changing its status.'**
  String get taskReopenRequired;

  /// No description provided for @taskNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer available.'**
  String get taskNotAvailable;

  /// No description provided for @taskTakeOwnership.
  ///
  /// In en, this message translates to:
  /// **'Take Ownership'**
  String get taskTakeOwnership;

  /// No description provided for @taskChangePriority.
  ///
  /// In en, this message translates to:
  /// **'Change Priority'**
  String get taskChangePriority;

  /// No description provided for @taskChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get taskChangeStatus;

  /// No description provided for @taskComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get taskComplete;

  /// No description provided for @taskReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get taskReopen;

  /// No description provided for @taskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get taskCancel;

  /// No description provided for @taskArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get taskArchive;

  /// No description provided for @taskRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get taskRestore;

  /// No description provided for @taskArchiveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Archive this request?'**
  String get taskArchiveQuestion;

  /// No description provided for @taskArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'It will remain available under the Archived filter.'**
  String get taskArchiveHelp;

  /// No description provided for @taskRestoreQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restore this request?'**
  String get taskRestoreQuestion;

  /// No description provided for @taskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get taskConfirm;

  /// No description provided for @taskDismiss.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskDismiss;

  /// No description provided for @taskKeepCondition.
  ///
  /// In en, this message translates to:
  /// **'Keep Current Condition'**
  String get taskKeepCondition;

  /// No description provided for @taskMarkWorking.
  ///
  /// In en, this message translates to:
  /// **'Mark as Working'**
  String get taskMarkWorking;

  /// No description provided for @taskConditionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you also like to update this item\'s condition?'**
  String get taskConditionQuestion;

  /// No description provided for @taskConditionHelp.
  ///
  /// In en, this message translates to:
  /// **'The repair is completed. Updating the linked inventory item is a separate action.'**
  String get taskConditionHelp;

  /// No description provided for @taskConditionFailed.
  ///
  /// In en, this message translates to:
  /// **'The repair remains completed. The inventory condition update failed; refresh the item and try again from inventory.'**
  String get taskConditionFailed;

  /// No description provided for @taskCompletionNote.
  ///
  /// In en, this message translates to:
  /// **'Completion note (optional)'**
  String get taskCompletionNote;

  /// No description provided for @taskCompletionHistory.
  ///
  /// In en, this message translates to:
  /// **'Completion note'**
  String get taskCompletionHistory;

  /// No description provided for @taskComments.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get taskComments;

  /// No description provided for @taskAddComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get taskAddComment;

  /// No description provided for @taskSendComment.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get taskSendComment;

  /// No description provided for @taskEditComment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get taskEditComment;

  /// No description provided for @taskDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get taskDeleteComment;

  /// No description provided for @taskDeleteCommentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get taskDeleteCommentQuestion;

  /// No description provided for @taskNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get taskNoComments;

  /// No description provided for @taskActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get taskActivity;

  /// No description provided for @taskNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity available.'**
  String get taskNoActivity;

  /// No description provided for @taskAttachments.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get taskAttachments;

  /// No description provided for @taskNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'No photos attached.'**
  String get taskNoAttachments;

  /// No description provided for @taskViewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View photo'**
  String get taskViewPhoto;

  /// No description provided for @taskRefreshPhoto.
  ///
  /// In en, this message translates to:
  /// **'Refresh photo'**
  String get taskRefreshPhoto;

  /// No description provided for @taskPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable. Refresh for a new authorized link.'**
  String get taskPhotoError;

  /// No description provided for @taskRemovePhotoQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo?'**
  String get taskRemovePhotoQuestion;

  /// No description provided for @taskFormerMember.
  ///
  /// In en, this message translates to:
  /// **'Former household member'**
  String get taskFormerMember;

  /// No description provided for @taskSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get taskSystem;

  /// No description provided for @taskCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get taskCreatedBy;

  /// No description provided for @taskAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get taskAssignedTo;

  /// No description provided for @taskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get taskUpdated;

  /// No description provided for @taskRelatedRepairs.
  ///
  /// In en, this message translates to:
  /// **'Related repair requests'**
  String get taskRelatedRepairs;

  /// No description provided for @taskReportRepair.
  ///
  /// In en, this message translates to:
  /// **'Report a repair'**
  String get taskReportRepair;

  /// No description provided for @taskAllRelated.
  ///
  /// In en, this message translates to:
  /// **'View all related repairs'**
  String get taskAllRelated;

  /// No description provided for @taskNoRelated.
  ///
  /// In en, this message translates to:
  /// **'No related repairs.'**
  String get taskNoRelated;

  /// No description provided for @taskReassign.
  ///
  /// In en, this message translates to:
  /// **'Assign / Reassign'**
  String get taskReassign;

  /// No description provided for @taskUnassign.
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get taskUnassign;

  /// No description provided for @taskReopenedHelp.
  ///
  /// In en, this message translates to:
  /// **'Reopening keeps previous completion events in Activity.'**
  String get taskReopenedHelp;

  /// No description provided for @taskCommentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo to comment'**
  String get taskCommentPhoto;

  /// No description provided for @taskSaved.
  ///
  /// In en, this message translates to:
  /// **'Request saved.'**
  String get taskSaved;

  /// No description provided for @taskDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDone;

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

  /// No description provided for @shoppingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything your family needs.'**
  String get shoppingSubtitle;

  /// No description provided for @shoppingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get shoppingAdd;

  /// No description provided for @shoppingAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get shoppingAddToList;

  /// No description provided for @shoppingToBuy.
  ///
  /// In en, this message translates to:
  /// **'To Buy'**
  String get shoppingToBuy;

  /// No description provided for @shoppingPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get shoppingPurchased;

  /// No description provided for @shoppingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shoppingCancelled;

  /// No description provided for @shoppingQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add something to buy'**
  String get shoppingQuickAdd;

  /// No description provided for @shoppingName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get shoppingName;

  /// No description provided for @shoppingQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get shoppingQuantity;

  /// No description provided for @shoppingUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get shoppingUnit;

  /// No description provided for @shoppingNoUnit.
  ///
  /// In en, this message translates to:
  /// **'No unit'**
  String get shoppingNoUnit;

  /// No description provided for @shoppingNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes & preferences'**
  String get shoppingNotes;

  /// No description provided for @shoppingMarkPurchased.
  ///
  /// In en, this message translates to:
  /// **'Mark Purchased'**
  String get shoppingMarkPurchased;

  /// No description provided for @shoppingUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo Purchase'**
  String get shoppingUndo;

  /// No description provided for @shoppingClaim.
  ///
  /// In en, this message translates to:
  /// **'I’ll Buy This'**
  String get shoppingClaim;

  /// No description provided for @shoppingActualQuantity.
  ///
  /// In en, this message translates to:
  /// **'Actual quantity (optional)'**
  String get shoppingActualQuantity;

  /// No description provided for @shoppingPrice.
  ///
  /// In en, this message translates to:
  /// **'Purchase price (optional)'**
  String get shoppingPrice;

  /// No description provided for @shoppingCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get shoppingCurrency;

  /// No description provided for @shoppingNote.
  ///
  /// In en, this message translates to:
  /// **'Completion note (optional)'**
  String get shoppingNote;

  /// No description provided for @shoppingInventoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Update household inventory?'**
  String get shoppingInventoryQuestion;

  /// No description provided for @shoppingInventoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Add this purchased quantity to your linked inventory? This action applies this purchase at most once.'**
  String get shoppingInventoryHelp;

  /// No description provided for @shoppingNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get shoppingNotNow;

  /// No description provided for @shoppingUpdateInventory.
  ///
  /// In en, this message translates to:
  /// **'Update Inventory'**
  String get shoppingUpdateInventory;

  /// No description provided for @shoppingInventorySuccess.
  ///
  /// In en, this message translates to:
  /// **'Inventory update confirmed.'**
  String get shoppingInventorySuccess;

  /// No description provided for @shoppingInventoryFailure.
  ///
  /// In en, this message translates to:
  /// **'The purchase remains saved. Inventory was not confirmed updated. You can retry safely from this item.'**
  String get shoppingInventoryFailure;

  /// No description provided for @shoppingInventoryApplied.
  ///
  /// In en, this message translates to:
  /// **'This purchase has already been applied to inventory.'**
  String get shoppingInventoryApplied;

  /// No description provided for @shoppingUndoHelp.
  ///
  /// In en, this message translates to:
  /// **'Reopen this purchase? Any stock already added will remain unchanged. Review inventory separately if it needs correction.'**
  String get shoppingUndoHelp;

  /// No description provided for @shoppingUndoSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase reopened. Review inventory separately if stock was already added.'**
  String get shoppingUndoSuccess;

  /// No description provided for @shoppingPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase saved.'**
  String get shoppingPurchaseSuccess;

  /// No description provided for @shoppingUnitError.
  ///
  /// In en, this message translates to:
  /// **'Choose the linked consumable’s exact unit and a quantity before purchasing. Unit conversion is not supported.'**
  String get shoppingUnitError;

  /// No description provided for @shoppingChanged.
  ///
  /// In en, this message translates to:
  /// **'This purchase changed or is closed. Refresh and reopen it before editing.'**
  String get shoppingChanged;

  /// No description provided for @shoppingDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This inventory item is already on your shopping list.'**
  String get shoppingDuplicate;

  /// No description provided for @shoppingViewExisting.
  ///
  /// In en, this message translates to:
  /// **'View Existing Request'**
  String get shoppingViewExisting;

  /// No description provided for @shoppingAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add Another Request'**
  String get shoppingAddAnother;

  /// No description provided for @shoppingHistory.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get shoppingHistory;

  /// No description provided for @shoppingNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No saved purchase history yet.'**
  String get shoppingNoHistory;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your shopping list is empty. Add something your household needs.'**
  String get shoppingEmpty;

  /// No description provided for @shoppingAllPurchased.
  ///
  /// In en, this message translates to:
  /// **'Everything in this list has been purchased.'**
  String get shoppingAllPurchased;

  /// No description provided for @shoppingRefreshNote.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh. The list also refreshes when you return to the app.'**
  String get shoppingRefreshNote;

  /// No description provided for @shoppingNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount with up to 12 whole digits and 3 decimal places.'**
  String get shoppingNumberError;

  /// No description provided for @shoppingPriceError.
  ///
  /// In en, this message translates to:
  /// **'Enter a nonnegative amount with up to 13 whole digits and 2 decimal places, and select a supported currency.'**
  String get shoppingPriceError;

  /// No description provided for @shoppingRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by'**
  String get shoppingRequestedBy;

  /// No description provided for @shoppingPurchasedBy.
  ///
  /// In en, this message translates to:
  /// **'Purchased by'**
  String get shoppingPurchasedBy;

  /// No description provided for @shoppingProgress.
  ///
  /// In en, this message translates to:
  /// **'{purchased} of {total} items purchased'**
  String shoppingProgress(int purchased, int total);

  /// No description provided for @shoppingOutstanding.
  ///
  /// In en, this message translates to:
  /// **'{active} to buy · {high} high priority · {mine} assigned to you'**
  String shoppingOutstanding(int active, int high, int mine);

  /// No description provided for @shoppingNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get shoppingNewest;

  /// No description provided for @shoppingListTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingListTitle;

  /// No description provided for @shoppingSearch.
  ///
  /// In en, this message translates to:
  /// **'Search shopping items'**
  String get shoppingSearch;

  /// No description provided for @shoppingDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Your draft is saved on this device. Changes reach your household only when you save.'**
  String get shoppingDraftNote;

  /// No description provided for @shoppingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No shopping items match these filters.'**
  String get shoppingNoResults;

  /// No description provided for @shoppingBeingHandled.
  ///
  /// In en, this message translates to:
  /// **'Being Handled'**
  String get shoppingBeingHandled;
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
