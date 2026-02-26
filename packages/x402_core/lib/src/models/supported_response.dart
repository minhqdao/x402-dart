import 'package:x402_core/src/models/supported_kind.dart';

/// Describes supported payment kinds, extensions and signers.
class SupportedResponse {
  /// Supported payment kinds.
  final List<SupportedKind> kinds;

  /// Supported extension identifiers.
  final List<String> extensions;

  /// Mapping of CAIP family patterns to signer addresses.
  final Map<String, List<String>> signers;

  const SupportedResponse({
    required this.kinds,
    required this.extensions,
    required this.signers,
  });

  factory SupportedResponse.fromJson(Map<String, dynamic> json) {
    return SupportedResponse(
      kinds: (json['kinds'] as List<dynamic>)
          .map((e) => SupportedKind.fromJson(e as Map<String, dynamic>))
          .toList(),
      extensions: (json['extensions'] as List<dynamic>).cast<String>(),
      signers: (json['signers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).cast<String>(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'kinds': kinds.map((e) => e.toJson()).toList(),
        'extensions': extensions,
        'signers': signers,
      };
}
