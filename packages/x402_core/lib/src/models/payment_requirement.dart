import 'dart:convert';

import 'package:x402_core/src/models/network.dart';

/// Represents a specific payment option offered by a server in a 402 response.
///
/// A single 402 response may contain multiple [PaymentRequirement]s,
/// allowing the client to choose the most suitable network, asset, and scheme.
///
/// The [network] is represented as a strongly-typed [Network] internally,
/// but is serialized/deserialized as a CAIP-2 string.
final class PaymentRequirement {
  /// The protocol scheme to use for this payment
  /// (e.g., `"exact"`, `"v2:solana:exact"`).
  final String scheme;

  /// The CAIP-2 network this requirement applies to.
  ///
  /// Examples:
  /// - `eip155:8453`
  /// - `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d`
  final Network network;

  /// The contract address or identifier of the asset (e.g., USDC token address).
  final String asset;

  /// The exact amount required in the asset's smallest atomic unit.
  ///
  /// For example, USDC uses 6 decimals.
  final String amount;

  /// The destination address where the payment should be sent.
  final String payTo;

  /// The number of seconds this requirement remains valid after issuance.
  final int maxTimeoutSeconds;

  /// Arbitrary extra data required by the specific [scheme] or [network].
  final Map<String, dynamic> extra;

  PaymentRequirement({
    required this.scheme,
    required this.network,
    required this.asset,
    required this.amount,
    required this.payTo,
    required this.maxTimeoutSeconds,
    required Map<String, dynamic> extra,
  }) : extra = Map.unmodifiable(extra);

  /// Creates a [PaymentRequirement] from JSON.
  ///
  /// The `network` field must be a valid CAIP-2 string.
  factory PaymentRequirement.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'] ?? json['maxAmountRequired'];

    if (rawAmount == null) {
      throw const FormatException('Missing amount field');
    }

    return PaymentRequirement(
      scheme: json['scheme'] as String,
      network: Network.parse(json['network'] as String),
      asset: json['asset'] as String,
      amount: rawAmount.toString(),
      payTo: json['payTo'] as String,
      maxTimeoutSeconds: (json['maxTimeoutSeconds'] as num).toInt(),
      extra: Map.unmodifiable((json['extra'] ??
          json['data'] ??
          <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  /// Converts this requirement to JSON.
  ///
  /// The [network] is serialized as its canonical CAIP-2 string.
  Map<String, dynamic> toJson() {
    return {
      'scheme': scheme,
      'network': network.identifier,
      'asset': asset,
      'amount': amount,
      'payTo': payTo,
      'maxTimeoutSeconds': maxTimeoutSeconds,
      'extra': extra,
    };
  }

  /// Returns a copy of this requirement with the given fields replaced.
  PaymentRequirement copyWith({
    String? scheme,
    Network? network,
    String? asset,
    String? amount,
    String? payTo,
    int? maxTimeoutSeconds,
    Map<String, dynamic>? extra,
  }) {
    return PaymentRequirement(
      scheme: scheme ?? this.scheme,
      network: network ?? this.network,
      asset: asset ?? this.asset,
      amount: amount ?? this.amount,
      payTo: payTo ?? this.payTo,
      maxTimeoutSeconds: maxTimeoutSeconds ?? this.maxTimeoutSeconds,
      extra: Map.unmodifiable(extra ?? this.extra),
    );
  }

  /// Decodes a Base64-encoded JSON 402 payment header.
  factory PaymentRequirement.fromHeader(String base64Json) {
    final decoded = jsonDecode(utf8.decode(base64Decode(base64Json)))
        as Map<String, dynamic>;
    return PaymentRequirement.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRequirement &&
          scheme == other.scheme &&
          network == other.network &&
          asset == other.asset &&
          amount == other.amount &&
          payTo == other.payTo &&
          maxTimeoutSeconds == other.maxTimeoutSeconds &&
          _deepEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        scheme,
        network,
        asset,
        amount,
        payTo,
        maxTimeoutSeconds,
        _deepHash(extra),
      );

  static bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  static int _deepHash(dynamic a) {
    if (a is Map) {
      return Object.hashAllUnordered(
        a.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
      );
    }
    if (a is List) {
      return Object.hashAll(a.map(_deepHash));
    }
    return a.hashCode;
  }
}
