import 'dart:async';

import 'package:flutter_cache_manager/src/web/file_service.dart';

/// Tracks the callers that share one piece of work, such as a download, and
/// cancels [token] once every caller has cancelled.
///
/// A caller that joins without a token cannot cancel, so it keeps the work
/// alive until the work completes on its own.
class SharedCancellation {
  /// The token that stops the shared work.
  final CancellationToken token = CancellationToken();

  /// Called once, when the last caller cancels.
  void Function()? onAllCancelled;

  int _callers = 0;

  /// Gives a caller its own view of [source].
  ///
  /// When [callerToken] is cancelled, only this caller's stream ends, with a
  /// [CancelledException]. The shared work is cancelled when no caller is
  /// left.
  Stream<T> join<T>(Stream<T> source, CancellationToken? callerToken) {
    _callers++;
    if (callerToken == null) return source;

    StreamSubscription<T>? subscription;
    var finished = false;
    final controller = StreamController<T>();

    void leave() {
      _callers--;
      if (_callers == 0 && !token.isCancelled) {
        token.cancel();
        onAllCancelled?.call();
      }
    }

    controller
      ..onListen = () {
        if (finished) return;
        subscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            finished = true;
            controller.close();
          },
        );
      }
      ..onPause = (() => subscription?.pause())
      ..onResume = (() => subscription?.resume())
      ..onCancel = () => subscription?.cancel();

    callerToken.whenCancelled.then((_) {
      if (finished) return;
      finished = true;
      final pending = subscription;
      subscription = null;
      pending?.cancel();
      controller.addError(CancelledException());
      controller.close();
      leave();
    });

    return controller.stream;
  }
}
