import '../localization/generated/app_localizations.dart';

/// Human readable "time ago" text shared across screens.
String relativeTime(AppLocalizations l, DateTime when, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(when);
  if (diff.isNegative || diff.inMinutes < 1) return l.agoJustNow;
  if (diff.inMinutes < 60) return l.agoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.agoHours(diff.inHours);
  if (diff.inDays == 1) return l.agoYesterday;
  if (diff.inDays < 7) return l.agoDays(diff.inDays);
  if (diff.inDays < 30) return l.agoWeeks(diff.inDays ~/ 7);
  if (diff.inDays < 365) return l.agoMonths(diff.inDays ~/ 30);
  return l.agoYears(diff.inDays ~/ 365);
}

/// Short form for tight spaces ("5m ago", "2h ago", "3d ago").
String compactAgo(AppLocalizations l, DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.isNegative || diff.inMinutes < 1) return l.agoJustNow.toLowerCase();
  if (diff.inMinutes < 60) return l.agoMinutesShort(diff.inMinutes);
  if (diff.inHours < 24) return l.agoHoursShort(diff.inHours);
  return l.agoDaysShort(diff.inDays);
}
