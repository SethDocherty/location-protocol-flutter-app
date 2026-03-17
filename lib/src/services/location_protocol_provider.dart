import 'package:flutter/widgets.dart';

import 'library_location_protocol_service.dart';
import 'location_protocol_service.dart';

/// Provides a [LocationProtocolService] to the widget tree.
///
/// Wire this provider near the root of the app (in `main.dart`) so that any
/// descendant can obtain the active service via [LocationProtocolProvider.of]:
///
/// ```dart
/// // main.dart
/// LocationProtocolProvider(
///   child: MaterialApp(...),
/// )
///
/// // any screen
/// final service = LocationProtocolProvider.of(context);
/// ```
class LocationProtocolProvider extends InheritedWidget {
  /// The active service implementation.
  final LocationProtocolService service;

  LocationProtocolProvider({
    super.key,
    required super.child,
  }) : service = const LibraryLocationProtocolService();

  /// Returns the [LocationProtocolService] from the nearest ancestor
  /// [LocationProtocolProvider].
  ///
  /// Throws if no provider is found in the tree.
  static LocationProtocolService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<LocationProtocolProvider>();
    assert(
      provider != null,
      'No LocationProtocolProvider found in the widget tree. '
      'Make sure LocationProtocolProvider wraps your app in main.dart.',
    );
    return provider!.service;
  }

  @override
  bool updateShouldNotify(LocationProtocolProvider oldWidget) =>
      service != oldWidget.service;
}
