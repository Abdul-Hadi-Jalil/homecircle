import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecircle/core/theme/app_theme.dart';

void main() {
  test('secondary and error text meet 4.5 to 1 contrast on app surfaces', () {
    for (final foreground in [AppColors.muted, AppColors.danger]) {
      for (final background in [AppColors.surface, AppColors.background]) {
        final contrast =
            (background.computeLuminance() + .05) /
            (foreground.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
    expect(AppTheme.light.colorScheme.onError, Colors.white);
  });
}
