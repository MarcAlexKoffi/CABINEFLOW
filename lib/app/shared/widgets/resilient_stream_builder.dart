import 'package:cabine_flow/app/core/resilience/backend_failure_policy.dart';
import 'package:flutter/material.dart';

/// Keeps the last successful value visible during a temporary read failure.
/// Authorization and contract errors clear it immediately. The cache belongs
/// to this stream subscription and is discarded when its identity changes.
class ResilientStreamBuilder<T> extends StatefulWidget {
  const ResilientStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
  });
  final Stream<T>? stream;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<ResilientStreamBuilder<T>> createState() =>
      _ResilientStreamBuilderState<T>();
}

class _ResilientStreamBuilderState<T> extends State<ResilientStreamBuilder<T>> {
  T? _last;
  bool _hasLast = false;

  @override
  void didUpdateWidget(covariant ResilientStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _last = null;
      _hasLast = false;
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    key: ValueKey(widget.stream),
    stream: widget.stream,
    builder: (context, snapshot) {
      if (snapshot.hasData && !snapshot.hasError) {
        _last = snapshot.data;
        _hasLast = true;
      }
      final stale =
          snapshot.hasError &&
          _hasLast &&
          BackendFailurePolicy.canRetryRead(snapshot.error!);
      final ancestorWarning = _ReadWarningScope.maybeOf(context);
      if (snapshot.hasError && !stale) {
        _last = null;
        _hasLast = false;
      }
      return Column(
        children: [
          if (stale && !ancestorWarning)
            const Padding(
              key: ValueKey('read-warning'),
              padding: EdgeInsets.all(12),
              child: Text(
                'Connexion interrompue. Les dernières données restent affichées pendant la reconnexion.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            key: const ValueKey('read-content'),
            child: _ReadWarningScope(
              warning: ancestorWarning || stale,
              child: widget.builder(
                context,
                stale
                    ? AsyncSnapshot<T>.withData(
                        snapshot.connectionState,
                        _last as T,
                      )
                    : snapshot,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ReadWarningScope extends InheritedWidget {
  const _ReadWarningScope({required this.warning, required super.child});
  final bool warning;
  static bool maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ReadWarningScope>()
          ?.warning ??
      false;
  @override
  bool updateShouldNotify(_ReadWarningScope oldWidget) =>
      warning != oldWidget.warning;
}
