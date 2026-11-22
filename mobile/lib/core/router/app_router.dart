import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/views/auth_view.dart';
import '../../features/auth/views/onboarding_view.dart';
import '../../features/auth/views/auth_notice_view.dart';
import '../../features/household/views/membership_views.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/dashboard/views/home_view.dart';
import '../../features/household/viewmodels/session_view_model.dart';
import '../../features/household/views/household_view.dart';
import '../../features/inventory/views/inventory_views.dart';
import '../../features/tasks/views/tasks_screen.dart';
import '../../features/shopping/views/shopping_list_screen.dart';
import '../../features/shopping/views/shopping_item_form.dart';
import '../../features/shopping/views/shopping_details_screen.dart';
import '../../features/chat/views/family_chat_screen.dart';
import '../../features/chat/models/chat_task_source.dart';
import '../../features/activity/views/family_activity_screen.dart';
import '../../features/notifications/views/notifications_screen.dart';
import '../../features/notifications/views/notification_settings_screen.dart';
import '../../features/tasks/views/task_form_screen.dart';
import '../../features/tasks/views/task_details_screen.dart';
import '../localization/generated/app_localizations.dart';
import '../widgets/mock_widgets.dart';
import 'route_guard.dart';

GoRouter createRouter(SessionViewModel session) => GoRouter(
  initialLocation: '/bootstrap',
  refreshListenable: session,
  redirect: (context, state) => routeRedirect(
    path: state.uri.path,
    restoring:
        session.restoring || session.switching || !session.splashDone,
    signedIn: session.user != null,
    hasHousehold: session.activeHousehold != null,
    passwordRecovery: session.passwordRecovery,
    isAdmin: session.activeHousehold?.role == 'admin',
    pendingVerification: session.pendingEmail != null,
    authError: session.authCallbackError,
    unauthenticatedPath: session.loggedOut
        ? '/login'
        : session.onboardingCompleted
        ? '/login'
        : '/onboarding',
    inviteAfterCreate: session.inviteAfterCreate,
  ),
  routes: [
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingView(),
    ),
    GoRoute(
      path: '/verify-email',
      name: 'verifyEmail',
      builder: (context, state) => const AuthNoticeView(),
    ),
    GoRoute(
      path: '/auth-error',
      name: 'authError',
      builder: (context, state) => const AuthNoticeView(invalidLink: true),
    ),
    for (final entry in [
      ('inviteFamily', '/invite-family', 'invite'),
      ('householdSettings', '/household-settings', 'settings'),
      ('members', '/members', 'members'),
    ])
      GoRoute(
        path: entry.$2,
        name: entry.$1,
        builder: (context, state) => MembershipView(
          key: ValueKey(
            '${entry.$3}-${session.user?.id}-${session.activeHousehold?.id}',
          ),
          mode: entry.$3,
        ),
      ),
    GoRoute(
      path: '/bootstrap',
      name: 'bootstrap',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      redirect: (context, state) => '/login',
    ),
    for (final route in [
      ('login', '/login'),
      ('register', '/register'),
      ('forgotPassword', '/forgot-password'),
      ('resetPassword', '/reset-password'),
    ])
      GoRoute(
        path: route.$2,
        name: route.$1,
        builder: (context, state) =>
            AuthView(key: ValueKey(route.$1), mode: route.$1),
      ),
    GoRoute(
      path: '/households',
      name: 'selectHousehold',
      builder: (context, state) => const HouseholdSelectionView(),
    ),
    GoRoute(
      path: '/households/create',
      name: 'createHousehold',
      builder: (context, state) => const CreateHouseholdView(),
    ),
    GoRoute(
      path: '/households/join',
      name: 'joinHousehold',
      redirect: (context, state) => '/households',
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => NavigationShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              name: 'inventory',
              builder: (context, state) => InventoryOverview(
                key: ValueKey(
                  '${session.scopeRevision}-${state.uri.queryParameters['stock']}',
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              name: 'tasks',
              builder: (context, state) => TasksScreen(
                key: ValueKey(
                  'tasks-${session.scopeRevision}-${state.uri.queryParameters['item']}-${state.uri.queryParameters['active']}-${state.uri.queryParameters['priority']}-${state.uri.queryParameters['assignment']}-${state.uri.queryParameters['status']}',
                ),
                linkedItemId: state.uri.queryParameters['item'],
                initialFilters: state.uri.queryParameters['active'] == 'true'
                    ? {
                        'active_only': 'true',
                        'exclude_shopping': 'true',
                        if (state.uri.queryParameters['priority'] == 'urgent')
                          'priority': 'urgent',
                        if (state.uri.queryParameters['assignment'] != null)
                          'assignment':
                              state.uri.queryParameters['assignment']!,
                      }
                    : state.uri.queryParameters['assignment'] != null ||
                          state.uri.queryParameters['status'] != null
                    ? {
                        if (state.uri.queryParameters['assignment'] != null)
                          'assignment':
                              state.uri.queryParameters['assignment']!,
                        if (state.uri.queryParameters['status'] != null)
                          'status': state.uri.queryParameters['status']!,
                      }
                    : null,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              name: 'chat',
              builder: (context, state) => FamilyChatScreen(
                key: ValueKey('chat-${session.scopeRevision}'),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => MembershipView(
                key: ValueKey(session.user?.id),
                mode: 'profile',
              ),
            ),
          ],
        ),
      ],
    ),
    for (final entry in <(String, String, String Function(AppLocalizations))>[
      ('notifications', '/notifications', (l) => l.notifications),
      ('familyActivity', '/family-activity', (l) => l.familyActivity),
    ])
      GoRoute(
        path: entry.$2,
        name: entry.$1,
        builder: (context, state) => entry.$1 == 'notifications'
            ? NotificationsScreen(
                key: ValueKey('notifications-${session.scopeRevision}'),
              )
            : FamilyActivityScreen(
                key: ValueKey('activity-${session.scopeRevision}'),
              ),
      ),
    GoRoute(
      path: '/notification-settings',
      name: 'notificationSettings',
      builder: (context, state) => NotificationSettingsScreen(
        key: ValueKey('preferences-${session.scopeRevision}'),
      ),
    ),
    GoRoute(
      path: '/shopping',
      name: 'shopping',
      builder: (context, state) => ShoppingListScreen(
        key: ValueKey('shopping-${session.scopeRevision}'),
      ),
    ),
    GoRoute(
      path: '/shopping/history',
      name: 'shoppingHistory',
      builder: (context, state) => ShoppingHistoryScreen(
        key: ValueKey('shopping-history-${session.scopeRevision}'),
      ),
    ),
    GoRoute(
      path: '/add-shopping',
      name: 'addShopping',
      builder: (context, state) => ShoppingItemForm(
        chatSource: state.extra is ChatTaskSource
            ? state.extra as ChatTaskSource
            : null,
        key: ValueKey('shopping-new-${session.scopeRevision}'),
        prefill: {
          if (state.uri.queryParameters['item'] != null)
            'linked_inventory_item_id': state.uri.queryParameters['item'],
          if (state.uri.queryParameters['name'] != null)
            'title': state.uri.queryParameters['name'],
          if (state.uri.queryParameters['name'] != null)
            'linked_inventory_name': state.uri.queryParameters['name'],
          if (state.uri.queryParameters['unit']?.isNotEmpty == true)
            'unit': state.uri.queryParameters['unit'],
        },
      ),
    ),
    GoRoute(
      path: '/shopping/:id/edit',
      name: 'editShopping',
      builder: (context, state) => ShoppingItemForm(
        key: ValueKey(
          'shopping-edit-${session.scopeRevision}-${state.pathParameters['id']}',
        ),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/shopping/:id',
      name: 'shoppingDetails',
      builder: (context, state) => ShoppingDetailsScreen(
        state.pathParameters['id']!,
        key: ValueKey(
          'shopping-${session.scopeRevision}-${state.pathParameters['id']}',
        ),
      ),
    ),
    GoRoute(
      path: '/inventory/:id',
      name: 'inventoryDetails',
      builder: (context, state) => InventoryDetails(
        key: ValueKey('${session.scopeRevision}-${state.pathParameters['id']}'),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/create-task',
      name: 'createTask',
      builder: (context, state) => TaskFormScreen(
        chatSource: state.extra is ChatTaskSource
            ? state.extra as ChatTaskSource
            : null,
        key: ValueKey('task-new-${session.scopeRevision}'),
        initialItemId: state.uri.queryParameters['item'],
        initialItemName: state.uri.queryParameters['itemName'],
        initialType: state.uri.queryParameters['type'],
      ),
    ),
    GoRoute(
      path: '/tasks/:id',
      name: 'taskDetails',
      builder: (context, state) => TaskDetailsScreen(
        key: ValueKey(
          'task-${session.scopeRevision}-${state.pathParameters['id']}',
        ),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/tasks/:id/edit',
      name: 'editTask',
      builder: (context, state) => TaskFormScreen(
        key: ValueKey(
          'task-edit-${session.scopeRevision}-${state.pathParameters['id']}',
        ),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/add-inventory',
      name: 'addInventory',
      builder: (context, state) =>
          InventoryEditor(key: ValueKey('new-${session.scopeRevision}')),
    ),
    GoRoute(
      path: '/inventory/:id/edit',
      name: 'editInventory',
      builder: (context, state) => InventoryEditor(
        key: ValueKey(
          'edit-${session.scopeRevision}-${state.pathParameters['id']}',
        ),
        id: state.pathParameters['id']!,
      ),
    ),
  ],
);

class NavigationShell extends StatelessWidget {
  const NavigationShell({required this.shell, super.key});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final revision = context.select<SessionViewModel, int>(
      (vm) => vm.scopeRevision,
    );
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(revision), child: shell),
      bottomNavigationBar: AppBottomNav(
        index: shell.currentIndex,
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        items: [
          (Icons.home_outlined, l.home),
          (Icons.inventory_2_outlined, l.inventory),
          (Icons.check_box_outlined, l.tasks),
          (Icons.chat_bubble_outline, l.chat),
          (Icons.person_outline, l.profile),
        ],
      ),
    );
  }
}
