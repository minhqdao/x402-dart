/// Response from facilitator's /settle endpoint
class SettlementResponse {
  /// Whether settlement was successful
  final bool success;

  /// Error message (if any)
  final String? error;

  /// Transaction hash
  final String? txHash;

  /// Network ID where transaction was settled
  final String? networkId;

  const SettlementResponse({required this.success, this.error, this.txHash, this.networkId});

  factory SettlementResponse.fromJson(Map<String, dynamic> json) {
    return SettlementResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
      txHash: json['txHash'] as String?,
      networkId: json['networkId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (error != null) 'error': error,
      if (txHash != null) 'txHash': txHash,
      if (networkId != null) 'networkId': networkId,
    };
  }
}
