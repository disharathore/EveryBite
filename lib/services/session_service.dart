class SessionService {
  SessionService._();

  static String? currentUserId;

  static bool get isLoggedIn => currentUserId != null && currentUserId!.isNotEmpty;

  static void clear() {
    currentUserId = null;
  }
}
