import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:homecircle/features/auth/models/auth_identity.dart';
import 'package:homecircle/features/auth/viewmodels/auth_view_model.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const identity = AuthIdentity(id: 'user-a');

  test(
    'restores validated household preference among multiple memberships',
    () async {
      final fixture = await createTestRuntime(
        identity: identity,
        memberships: [membership('a'), membership('b')],
        preferences: {'homecircle.user.user-a.active': 'b'},
      );
      await fixture.runtime.session.start();
      expect(fixture.runtime.session.restoring, false);
      expect(fixture.runtime.session.activeHousehold?.id, 'b');
      expect(fixture.runtime.session.realtime.householdId, 'b');
      await fixture.dispose();
    },
  );

  test('untrusted local household IDs never establish membership', () async {
    final fixture = await createTestRuntime(
      identity: identity,
      preferences: {'homecircle.user.user-a.active': 'unauthorized'},
    );
    await fixture.runtime.session.start();
    expect(fixture.runtime.session.activeHousehold, null);
    expect(fixture.runtime.store.activeHousehold('user-a'), null);
    await fixture.dispose();
  });

  test(
    'switching clears old state immediately and validates membership again',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final fixture = await createTestRuntime(
        identity: identity,
        preferences: {'homecircle.user.user-a.active': 'a'},
        respond: (request) async {
          if (request.url.path == '/api/v1/households') {
            calls++;
            if (calls > 1) return pending.future;
          }
          return householdResponse(request, [membership('a'), membership('b')]);
        },
      );
      final vm = fixture.runtime.session;
      await vm.start();
      final previousRevision = vm.scopeRevision;
      final switching = vm.selectHousehold('b');
      expect(vm.activeHousehold, null);
      expect(vm.switching, true);
      await Future<void>.delayed(Duration.zero);
      expect(vm.realtime.householdId, null);
      pending.complete(
        http.Response(
          jsonEncode([membership('a'), membership('b')]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await switching;
      expect(vm.activeHousehold?.id, 'b');
      expect(vm.scopeRevision, greaterThan(previousRevision));
      expect(
        fixture.runtime.store.readCache('user-a', 'a', 'household')?['id'],
        'a',
      );
      expect(
        fixture.runtime.store.readCache('user-a', 'b', 'household')?['id'],
        'b',
      );
      await fixture.dispose();
    },
  );

  test('revocation removes active selection, cache and drafts', () async {
    var memberships = [membership('a')];
    final fixture = await createTestRuntime(
      identity: identity,
      respond: (request) async => householdResponse(request, memberships),
    );
    final vm = fixture.runtime.session;
    await vm.start();
    await fixture.runtime.store.saveDraft('user-a', 'a', 'task', {
      'title': 'Private',
    });
    memberships = [];
    await vm.refresh();
    expect(vm.activeHousehold, null);
    expect(fixture.runtime.store.readCache('user-a', 'a', 'household'), null);
    expect(fixture.runtime.store.readDraft('user-a', 'a', 'task'), null);
    await fixture.dispose();
  });

  test('late membership responses cannot restore state after logout', () async {
    final pending = Completer<http.Response>();
    final fixture = await createTestRuntime(
      identity: identity,
      respond: (request) => pending.future,
    );
    final restoring = fixture.runtime.session.start();
    await Future<void>.delayed(Duration.zero);
    await fixture.runtime.store.saveDraft('user-a', 'a', 'task', {
      'title': 'Private',
    });
    await fixture.runtime.session.logout();
    pending.complete(
      http.Response(
        jsonEncode([membership('a')]),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await restoring;
    expect(fixture.runtime.session.user, null);
    expect(fixture.runtime.session.activeHousehold, null);
    expect(fixture.runtime.store.readDraft('user-a', 'a', 'task'), null);
    await fixture.dispose();
  });

  test('auth ViewModel notifies loading, success and error states', () async {
    final fixture = await createTestRuntime();
    final vm = AuthViewModel(fixture.runtime.auth);
    var notifications = 0;
    vm.addListener(() => notifications++);
    await vm.submit('login', 'person@example.test', 'password', '');
    expect(vm.succeeded, true);
    expect(vm.busy, false);
    expect(notifications, 2);
    fixture.auth.fail = true;
    await vm.submit('login', 'person@example.test', 'wrong', '');
    expect(vm.failed, true);
    expect(vm.succeeded, false);
    vm.dispose();
    await fixture.dispose();
  });
}
