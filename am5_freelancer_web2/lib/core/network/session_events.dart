import 'package:flutter/foundation.dart';

/// App-wide signal used to redirect protected screens after a server rejects
/// the persisted bearer token.
abstract final class SessionEvents {
  static final ValueNotifier<int> expired = ValueNotifier<int>(0);
  static void notifyExpired() => expired.value++;
}
