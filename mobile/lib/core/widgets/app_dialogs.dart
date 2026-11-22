import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'mock_widgets.dart';

/// Centered modal card (UI/modal_confirmation_dialog): icon, title, body, stacked buttons.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    required this.title,
    required this.actions,
    this.message,
    this.child,
    this.icon = Icons.help_outline,
    this.iconBg = const Color(0xFFFFDAD6),
    this.iconFg = AppColors.danger,
    super.key,
  });
  final String title;
  final String? message;
  final Widget? child;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: iconFg),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.headlineMd.copyWith(color: AppColors.text),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppText.bodyLg.copyWith(color: AppColors.muted),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 16), child!],
          const SizedBox(height: 20),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            actions[i],
          ],
        ],
      ),
    ),
  );
}

/// Two-button confirmation. Returns true only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  IconData icon = Icons.help_outline,
  bool destructive = false,
  Widget? child,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AppDialogFrame(
        title: title,
        message: message,
        icon: icon,
        iconBg: destructive ? const Color(0xFFFFDAD6) : AppColors.primaryFixed,
        iconFg: destructive ? AppColors.danger : AppColors.primary,
        actions: [
          AppCta(
            label: confirmLabel,
            color: destructive ? const Color(0xFFBA1A1A) : AppColors.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
          AppCta(
            label: cancelLabel,
            color: AppColors.surfaceContainer,
            foreground: AppColors.primary,
            shadow: false,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
        child: child,
      ),
    ) ??
    false;

/// Member picker (UI/selection_bottom_sheet). Result `(id,)`; a null id means unassigned.
Future<(String?,)?> showMemberSheet(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> members,
  required String? current,
  required String unassignedLabel,
  required String unassignedSub,
  required String resetLabel,
  required String applyLabel,
  required String selectedLabel,
  required String Function(Map<String, dynamic>) roleLabel,
  required String fallbackName,
}) => showModalBottomSheet<(String?,)>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (context) {
    var selected = current;
    return StatefulBuilder(
      builder: (context, setState) {
        final tiles = <Widget>[
          for (final member in members)
            _MemberTile(
              name: (member['display_name'] as String?)?.isNotEmpty == true
                  ? member['display_name'] as String
                  : fallbackName,
              sub: roleLabel(member),
              selected: selected == member['user_id'],
              onTap: () =>
                  setState(() => selected = member['user_id'] as String),
            ),
          _MemberTile(
            name: unassignedLabel,
            sub: unassignedSub,
            selected: selected == null,
            unassigned: true,
            onTap: () => setState(() => selected = null),
          ),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      selectedLabel,
                      style: AppText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final w = (box.maxWidth - 16) / 3;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tile in tiles)
                              SizedBox(width: w, child: tile),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppCta(
                        label: resetLabel,
                        color: AppColors.surfaceContainer,
                        foreground: AppColors.text,
                        shadow: false,
                        onPressed: () => setState(() => selected = current),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: AppCta(
                        label: applyLabel,
                        icon: Icons.done_all,
                        color: AppColors.primary,
                        onPressed: () => Navigator.pop(context, (selected,)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.unassigned = false,
  });
  final String name;
  final String sub;
  final bool selected;
  final bool unassigned;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.surfaceLow,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 4,
          vertical: 12,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                unassigned
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withAlpha(60)
                              : AppColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_off_outlined,
                          color: selected ? Colors.white : AppColors.muted,
                        ),
                      )
                    : InitialsAvatar(name, size: 48),
                if (selected && !unassigned)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.titleMd.copyWith(
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
            Text(
              sub.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelSm.copyWith(
                color: selected ? Colors.white70 : AppColors.muted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
