/// Maps Firebase Authentication errors and general exceptions to user-friendly messages.
/// Technical error codes and raw Firebase exceptions are never exposed to users.
String formatAuthError(dynamic error) {
  if (error == null) return '';
  final errStr = error.toString().toLowerCase();

  if (errStr.contains('invalid-credential') ||
      errStr.contains('wrong-password') ||
      errStr.contains('user-not-found')) {
    return 'Incorrect email or password. Please check your credentials and try again.';
  }
  if (errStr.contains('invalid-email')) {
    return 'Enter a valid email address containing "@".';
  }
  if (errStr.contains('user-disabled')) {
    return 'This branch account has been disabled. Please contact the administrator.';
  }
  if (errStr.contains('too-many-requests')) {
    return 'Too many unsuccessful login attempts. Please wait a moment and try again.';
  }
  if (errStr.contains('network-request-failed') ||
      errStr.contains('network') ||
      errStr.contains('socketexception') ||
      errStr.contains('connection')) {
    return 'Network connection error. Please check your internet connection and try again.';
  }
  if (errStr.contains('service-unavailable') ||
      errStr.contains('unavailable') ||
      errStr.contains('deadline-exceeded')) {
    return 'Authentication service is temporarily unavailable. Please try again later.';
  }
  if (errStr.contains('unauthorized-device') ||
      errStr.contains('not authorized') ||
      errStr.contains('no valid branch') ||
      errStr.contains('permission-denied')) {
    return 'This account is not authorized for the Staff App.';
  }

  return 'Unable to sign in. Please check your credentials and try again.';
}

