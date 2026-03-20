import 'package:flutter/material.dart';

import 'attestation_service.dart';

/// Provides [AttestationService] to the widget tree via [InheritedWidget].
///
/// Access via `AttestationServiceProvider.of(context)`.
class AttestationServiceProvider extends InheritedWidget {
  final AttestationService? service;

  const AttestationServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  /// Retrieves the nearest [AttestationService] from the widget tree.
  ///
  /// Returns `null` if no service is available (e.g., no signer configured).
  static AttestationService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AttestationServiceProvider>()
        ?.service;
  }

  @override
  bool updateShouldNotify(AttestationServiceProvider oldWidget) {
    return service != oldWidget.service;
  }
}
