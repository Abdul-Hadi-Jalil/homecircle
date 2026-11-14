import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum PushPermission { unavailable, notAsked, denied, authorized }

abstract class PushService {
  bool get available;
  Stream<String> get tokenChanges;
  Stream<Map<String, dynamic>> get foreground;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initial();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> removeToken();
  Future<void> dispose();
}

class NoPushService implements PushService {
  @override
  bool get available => false;
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get foreground => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get opened => const Stream.empty();
  @override
  Future<Map<String, dynamic>?> initial() async => null;
  @override
  Future<PushPermission> permission({bool request = false}) async =>
      PushPermission.unavailable;
  @override
  Future<String?> token() async => null;
  @override
  Future<void> removeToken() async {}
  @override
  Future<void> dispose() async {}
}

@pragma('vm:entry-point')
Future<void> homeCircleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // OS displays the generic notification. No protected data access or routing
  // happens in this unauthenticated background isolate.
}

class FirebasePushService implements PushService {
  FirebasePushService(this.messaging);
  final FirebaseMessaging messaging;
  Future<void> tail = Future.value();
  Future<void> serial(Future<void> Function() action) {
    final next = tail.then((_) => action());
    tail = next.catchError((_) {});
    return next;
  }

  static Future<PushService> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return NoPushService();
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(homeCircleBackgroundMessage);
      return FirebasePushService(FirebaseMessaging.instance);
    } catch (_) {
      return NoPushService();
    }
  }

  @override
  bool get available => true;
  @override
  Stream<String> get tokenChanges => messaging.onRegistered;
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((m) => m.data);
  @override
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  @override
  Future<Map<String, dynamic>?> initial() async =>
      (await messaging.getInitialMessage())?.data;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await messaging.requestPermission()
        : await messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.authorized,
      AuthorizationStatus.denied => PushPermission.denied,
      _ => PushPermission.notAsked,
    };
  }

  @override
  Future<String?> token() async {
    await serial(() async {
      await messaging.setAutoInitEnabled(true);
      await messaging.register();
    });
    // SDK 17 publishes the current direct-send target via onRegistered.
    return null;
  }

  @override
  Future<void> removeToken() async {
    await serial(() async {
      await messaging.setAutoInitEnabled(false);
      await messaging.unregister();
    });
  }

  @override
  Future<void> dispose() async {}
}
