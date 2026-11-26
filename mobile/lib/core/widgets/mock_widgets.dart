import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// White surface card used throughout the design mockups.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsetsDirectional.all(20),
    this.color = Colors.white,
    this.radius = 16,
    this.shadow = true,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow ? AppShadows.sm : null,
    ),
    child: child,
  );
}

/// Rounded label chip (status, priority, counts).
class AppPill extends StatelessWidget {
  const AppPill(
    this.text, {
    required this.bg,
    required this.fg,
    this.icon,
    this.radius = 9999,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    this.style,
    super.key,
  });
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final double radius;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: (style ?? AppText.labelSm).copyWith(color: fg),
          ),
        ),
      ],
    ),
  );
}

/// Full-width 48dp call-to-action button from the mockups.
class AppCta extends StatelessWidget {
  const AppCta({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.color = AppColors.primaryContainer,
    this.foreground = Colors.white,
    this.shadow = true,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final Color color;
  final Color foreground;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: shadow && enabled ? AppShadows.sm : null,
      ),
      child: Material(
        color: enabled ? color : color.withAlpha(97),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 48,
            child: loading
                ? Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: foreground),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelLg.copyWith(color: foreground),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, size: 20, color: foreground),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Square rounded icon tile (e.g. list leading icon).
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 36,
    this.iconSize = 20,
    this.radius = 12,
    super.key,
  });
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: iconSize, color: fg),
  );
}

/// Circular initials avatar (the app has no member photos).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.name, {
    this.size = 48,
    this.bg = AppColors.tertiaryFixed,
    this.fg = AppColors.onTertiaryFixed,
    super.key,
  });
  final String name;
  final double size;
  final Color bg;
  final Color fg;
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Text(
      _initials,
      style: AppText.labelMd.copyWith(
        color: fg,
        fontSize: size * 0.3 < 10 ? 10 : size * 0.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
  );
}

/// Preset household avatars (stored server-side as `avatar_key`).
abstract final class HouseholdAvatars {
  static const keys = ['cottage', 'apartment', 'forest', 'pets', 'favorite'];
  static IconData icon(String? key, {bool filled = true}) => switch (key) {
    'apartment' => Icons.apartment,
    'forest' => Icons.forest,
    'pets' => Icons.pets,
    'favorite' => filled ? Icons.favorite : Icons.favorite_border,
    _ => filled ? Icons.cottage : Icons.cottage_outlined,
  };
  static String label(AppLocalizations l, String? key) => switch (key) {
    'apartment' => l.avatarApartment,
    'forest' => l.avatarForest,
    'pets' => l.avatarPets,
    'favorite' => l.avatarFavorite,
    _ => l.avatarCottage,
  };
}

/// Circular round icon button used for back/leading actions.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.bg = AppColors.surfaceLow,
    super.key,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final Color bg;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 24, color: AppColors.text),
        ),
      ),
    ),
  );
}

/// Top bar used by the detail screens in the mockups: back, logo, title, profile.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    required this.title,
    this.onBack,
    this.onProfile,
    this.showLogo = true,
    this.actions = const [],
    super.key,
  });
  final List<Widget> actions;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;
  final bool showLogo;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    elevation: 0,
    shadowColor: Colors.black,
    child: SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: AppLocalizations.of(context)!.back,
                onPressed: onBack,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: AppColors.text,
                ),
              )
            else
              const SizedBox(width: 12),
            if (showLogo) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo_mark.png',
                  width: 32,
                  height: 32,
                  semanticLabel: 'HomeCircle',
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleMd.copyWith(
                  color: AppColors.text,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            ...actions,
            if (onProfile != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onProfile,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom navigation used by the main tabs (UI/home_dashboard).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.index,
    required this.items,
    required this.onSelected,
    super.key,
  });
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x0D1C2434),
          blurRadius: 20,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: items[i].$2,
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[i].$1,
                              size: 24,
                              color: i == index
                                  ? AppColors.primaryContainer
                                  : const Color(0xFF747686),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                items[i].$2,
                                style: AppText.labelSm.copyWith(
                                  letterSpacing: 0,
                                  fontWeight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: i == index
                                      ? AppColors.primaryContainer
                                      : const Color(0xFF747686),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
