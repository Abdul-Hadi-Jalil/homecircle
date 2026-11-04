const publicPaths = {
  '/welcome',
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
  '/verify-email',
  '/auth-error',
};
const setupPaths = {'/households', '/households/create', '/households/join'};

String? routeRedirect({
  required String path,
  required bool restoring,
  required bool signedIn,
  required bool hasHousehold,
  required bool passwordRecovery,
  required bool isAdmin,
  bool pendingVerification = false,
  bool authError = false,
  String unauthenticatedPath = '/welcome',
  bool inviteAfterCreate = false,
}) {
  if (restoring) return path == '/bootstrap' ? null : '/bootstrap';
  if (authError) return path == '/auth-error' ? null : '/auth-error';
  if (!signedIn && pendingVerification && path != '/login') {
    return path == '/verify-email' ? null : '/verify-email';
  }
  if (!signedIn) return publicPaths.contains(path) ? null : unauthenticatedPath;
  if (passwordRecovery) {
    return path == '/reset-password' ? null : '/reset-password';
  }
  if (!hasHousehold) return setupPaths.contains(path) ? null : '/households';
  if (path == '/household-settings' && !isAdmin) return '/home';
  if (path == '/invite-family' && !isAdmin) return '/home';
  if (path == '/bootstrap' ||
      publicPaths.contains(path) ||
      path == '/reset-password') {
    return inviteAfterCreate && isAdmin ? '/invite-family' : '/home';
  }
  return null;
}
