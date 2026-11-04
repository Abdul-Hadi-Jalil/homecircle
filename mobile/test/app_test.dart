import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecircle/app.dart';
import 'package:homecircle/core/config/app_config.dart';
import 'package:homecircle/core/router/route_guard.dart';
import 'package:homecircle/core/theme/app_theme.dart';
import 'package:homecircle/features/auth/models/auth_identity.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'missing configuration starts a useful development screen with the theme',
    (tester) async {
      await tester.pumpWidget(const ConfigurationApp());
      await tester.pumpAndSettle();
      expect(find.text('Development configuration'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).useMaterial3,
        true,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
        AppColors.primary,
      );
    },
  );

  test('rejects secret configuration and allows emulator API URL', () {
    expect(const AppConfig.fromEnvironment().isValid, false);
    expect(
      const AppConfig(
        apiBaseUrl: 'http://10.0.2.2:8000',
        supabaseUrl: 'https://example.supabase.co',
        supabaseKey: 'sb_publishable_example',
      ).isValid,
      true,
    );
    expect(
      const AppConfig(
        apiBaseUrl: 'https://api.example.test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseKey: 'sb_secret_server_only',
      ).isValid,
      false,
    );
  });

  test(
    'route guards cover restoration, auth, household, recovery and admin',
    () {
      String? redirect(
        String path, {
        bool restoring = false,
        bool signedIn = false,
        bool hasHousehold = false,
        bool recovery = false,
        bool admin = false,
      }) => routeRedirect(
        path: path,
        restoring: restoring,
        signedIn: signedIn,
        hasHousehold: hasHousehold,
        passwordRecovery: recovery,
        isAdmin: admin,
      );
      expect(redirect('/home', restoring: true), '/bootstrap');
      expect(redirect('/bootstrap', restoring: true), null);
      expect(redirect('/home'), '/welcome');
      expect(redirect('/login'), null);
      expect(redirect('/home', signedIn: true), '/households');
      expect(redirect('/households/create', signedIn: true), null);
      expect(redirect('/welcome', signedIn: true, hasHousehold: true), '/home');
      expect(redirect('/home', signedIn: true, hasHousehold: true), null);
      expect(redirect('/households', signedIn: true, hasHousehold: true), null);
      expect(
        redirect('/home', signedIn: true, recovery: true),
        '/reset-password',
      );
      expect(
        redirect('/household-settings', signedIn: true, hasHousehold: true),
        '/home',
      );
      expect(
        redirect(
          '/household-settings',
          signedIn: true,
          hasHousehold: true,
          admin: true,
        ),
        null,
      );
    },
  );

  testWidgets('initial unauthenticated router settles on welcome', (
    tester,
  ) async {
    final fixture = await createTestRuntime();
    await tester.pumpWidget(HomeCircleApp(runtime: fixture.runtime));
    await tester.pumpAndSettle();
    expect(
      find.text('Everything your home needs, in one place.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    await fixture.auth.events.close();
  });

  testWidgets('authenticated user without memberships selects a household', (
    tester,
  ) async {
    final fixture = await createTestRuntime(
      identity: const AuthIdentity(id: 'user-a'),
    );
    await tester.pumpWidget(HomeCircleApp(runtime: fixture.runtime));
    await tester.pumpAndSettle();
    expect(find.text('Select household'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await fixture.auth.events.close();
  });

  testWidgets('validated household opens the five-tab application shell', (
    tester,
  ) async {
    final fixture = await createTestRuntime(
      identity: const AuthIdentity(id: 'user-a'),
      memberships: [membership('a')],
    );
    await tester.pumpWidget(HomeCircleApp(runtime: fixture.runtime));
    await tester.pumpAndSettle();
    expect(find.text('Home a'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    await fixture.auth.events.close();
  });
}
