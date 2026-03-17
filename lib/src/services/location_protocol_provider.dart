import 'package:flutter/widgets.dart';

import 'legacy_location_protocol_service.dart';
import 'library_location_protocol_service.dart';
import 'location_protocol_config.dart';
import 'location_protocol_service.dart';

/// Provides a [LocationProtocolService] to the widget tree.
///
/// Wire this provider near the root of the app (in `main.dart`) so that any
/// descendant can obtain the active service via [LocationProtocolProvider.of]:
///
/// ```dart
/// // main.dart
/// LocationProtocolProvider(
///   config: const LocationProtocolConfig(),
///   child: MaterialApp(...),
/// )
///
/// // any screen
/// final service = LocationProtocolProvider.of(context);
/// ```
///
/// The concrete [LocationProtocolService] implementation is chosen based on
/// [LocationProtocolConfig.useLocationProtocolLibrary]:
/// - `false` → [LegacyLocationProtocolService] (default, existing behaviour)
/// - `true`  → [LibraryLocationProtocolService] (library-backed)
class LocationProtocolProvider extends InheritedWidget {
  /// The active service implementation.
  final LocationProtocolService service;

  /// Configuration used to select the implementation.
  final LocationProtocolConfig config;

  LocationProtocolProvider({
    super.key,
    LocationProtocolConfig config = const LocationProtocolConfig(),
    required super.child,
  })  : config = config,
        service = config.useLocationProtocolLibrary
            ? LibraryLocationProtocolService()
            : const LegacyLocationProtocolService();

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

  /// Returns the [LocationProtocolConfig] from the nearest ancestor
  /// [LocationProtocolProvider].
  static LocationProtocolConfig configOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<LocationProtocolProvider>();
    assert(
      provider != null,
      'No LocationProtocolProvider found in the widget tree.',
    );
    return provider!.config;
  }

  @override
  bool updateShouldNotify(LocationProtocolProvider oldWidget) =>
      service != oldWidget.service || config != oldWidget.config;
}
