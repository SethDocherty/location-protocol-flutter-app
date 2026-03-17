/// Configuration for the Location Protocol service layer.
///
/// Pass an instance to [LocationProtocolProvider] in `main.dart`.
///
/// ```dart
/// LocationProtocolProvider(
///   config: const LocationProtocolConfig(),   // flag off — safe default
///   child: myApp,
/// )
/// ```
class LocationProtocolConfig {
  /// When `true`, [LibraryLocationProtocolService] is used instead of
  /// [LegacyLocationProtocolService].
  ///
  /// Defaults to `false` so that existing behaviour is preserved until the
  /// full library migration is ready.
  final bool useLocationProtocolLibrary;

  const LocationProtocolConfig({
    this.useLocationProtocolLibrary = false,
  });
}
