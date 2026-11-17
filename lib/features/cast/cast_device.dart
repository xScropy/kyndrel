import 'package:flutter/foundation.dart';

enum CastKind { chromecast, dlna }

@immutable
class CastDevice {
  const new({
    required this.id,
    required this.name,
    required this.kind,
    required this.host,
    required this.port,
    this.avTransportUrl,
    this.renderingControlUrl,
  });

  final String id;
  final String name;
  final CastKind kind;
  final String host;
  final int port;

  /// DLNA control endpoints.
  final Uri? avTransportUrl;
  final Uri? renderingControlUrl;

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CastDevice($name, ${kind.name}, $host:$port)';
}
