/// An exception whose [message] is written for the person using the app and
/// safe to show as-is. Domain failures in each app and [ApiException] implement
/// it so one line can turn any error into a notice.
abstract interface class UserFacingFailure implements Exception {
  String get message;
}

/// The failure's own message when it is meant for people; otherwise
/// [fallback]. Raw exception text can contain private machine data, so it is
/// never shown.
String describeFailure(Object error, {required String fallback}) =>
    error is UserFacingFailure ? error.message : fallback;
