import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/app.dart';
import 'package:homecircle/core/router/route_guard.dart';
import 'package:homecircle/features/auth/models/form_validation.dart';
import 'package:homecircle/features/auth/viewmodels/auth_view_model.dart';
import 'package:homecircle/features/household/viewmodels/household_actions.dart';

import 'support/fakes.dart';

void main() {
  test('auth validation handles email, password and confirmation', () {
    expect(FormValidation.email('invalid'), false);
    expect(FormValidation.email('person@example.test'), true);
    expect(FormValidation.password('short'), false);
    expect(FormValidation.password('long-enough'), true);
    expect(FormValidation.confirmation('a', 'b'), false);
    expect(FormValidation.confirmation('same', 'same'), true);
  });
  test('pending verification and logout have dedicated destinations', () {
    String? redirect({
      bool pending = false,
      bool error = false,
      String destination = '/login',
    }) => routeRedirect(
      path: '/bootstrap',
      restoring: false,
      signedIn: false,
      hasHousehold: false,
      passwordRecovery: false,
      isAdmin: false,
      pendingVerification: pending,
      authError: error,
      unauthenticatedPath: destination,
    );
    expect(redirect(pending: true), '/verify-email');
    expect(redirect(error: true), '/auth-error');
    expect(redirect(), '/login');
    expect(redirect(destination: '/onboarding'), '/onboarding');
    expect(
      routeRedirect(
        path: '/bootstrap',
        restoring: false,
        signedIn: true,
        hasHousehold: true,
        passwordRecovery: false,
        isAdmin: true,
        inviteAfterCreate: true,
      ),
      '/invite-family',
    );
  });
  test('resend has a cooldown and onboarding completion persists', () async {
    final fixture = await createTestRuntime();
    final vm = AuthViewModel(fixture.runtime.auth);
    await vm.resend('person@example.test');
    final deadline = vm.resendAvailableAt;
    await vm.resend('person@example.test');
    expect(vm.resendAvailableAt, deadline);
    expect(vm.succeeded, true);
    await fixture.runtime.session.completeOnboarding();
    expect(fixture.runtime.session.onboardingCompleted, true);
    vm.dispose();
    await fixture.dispose();
  });
  test(
    'invitation preview resets and backend errors are recoverable',
    () async {
      var requests = 0;
      final fixture = await createTestRuntime(
        respond: (_) async {
          requests++;
          return http.Response(
            jsonEncode(
              requests == 1
                  ? {
                      'error': {'code': 'expired_invitation'},
                    }
                  : {
                      'household_id': 'home',
                      'name': 'Family',
                      'already_member': false,
                    },
            ),
            requests == 1 ? 400 : 200,
            headers: {'content-type': 'application/json'},
          );
        },
      );
      // The fake token source requires an authenticated identity.
      await fixture.auth.login('person@example.test', 'password');
      final vm = HouseholdActions(fixture.runtime.households);
      expect(await vm.previewCode('code'), false);
      expect(vm.error, 'expired_invitation');
      expect(await vm.previewCode('code'), true);
      expect(vm.preview?.name, 'Family');
      vm.clearPreview();
      expect(vm.preview, null);
      vm.dispose();
      await fixture.dispose();
    },
  );
  testWidgets(
    'registration is usable at narrow phone width and validates confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await createTestRuntime();
      await tester.pumpWidget(HomeCircleApp(runtime: fixture.runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm password'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Person');
      await tester.enterText(fields.at(1), 'person@example.test');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.enterText(fields.at(3), 'different-password');
      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Passwords must match.'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await fixture.auth.events.close();
    },
  );
}
