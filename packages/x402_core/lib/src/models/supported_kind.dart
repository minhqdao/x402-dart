/// A payment kind supported by a facilitator.
class SupportedKind {
  /// Supported x402 protocol version.
  final int x402Version;

  /// Payment scheme identifier.
  final String scheme;

  /// Network identifier.
  final String network;

  /// Optional scheme-specific metadata.
  final Map<String, dynamic>? extra;

  const SupportedKind({
    required this.x402Version,
    required this.scheme,
    required this.network,
    this.extra,
  });

  factory SupportedKind.fromJson(Map<String, dynamic> json) {
    return SupportedKind(
      x402Version: json['x402Version'] as int,
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'x402Version': x402Version,
        'scheme': scheme,
        'network': network,
        if (extra != null) 'extra': extra,
      };
}
