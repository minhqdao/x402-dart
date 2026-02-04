import 'package:test/test.dart';
import 'package:x402_server/x402_server.dart';

void main() {
  group('PaymentVerifier', () {
    test('uses the first scheme that supports the payment header', () async {
      final scheme1 = _FakeScheme(supportsHeader: true, isValid: true);
      final scheme2 = _FakeScheme(supportsHeader: true);
      final verifier = PaymentVerifier([scheme1, scheme2]);
      final request = _FakeRequest();

      final result = await verifier.verify(
        paymentHeader: 'header1',
        request: request,
      );

      expect(result.isValid, isTrue);
      expect(scheme1.callCount, equals(1));
      expect(scheme2.callCount, equals(0));
    });

    test('returns invalid when no scheme supports the payment header',
        () async {
      final scheme1 = _FakeScheme();
      final scheme2 = _FakeScheme();
      final verifier = PaymentVerifier([scheme1, scheme2]);
      final request = _FakeRequest();

      final result = await verifier.verify(
        paymentHeader: 'unknown',
        request: request,
      );

      expect(result.isValid, isFalse);
      expect(result.reason, equals('No supported payment scheme'));
    });

    test('delegates verification result from the selected scheme', () async {
      final scheme1 = _FakeScheme(
        supportsHeader: true,
        reason: 'test error',
      );
      final verifier = PaymentVerifier([scheme1]);
      final request = _FakeRequest();

      final result = await verifier.verify(
        paymentHeader: 'header1',
        request: request,
      );

      expect(result.isValid, isFalse);
      expect(result.reason, equals('test error'));
    });
  });
}

class _FakeRequest implements X402Request {
  @override
  Map<String, String> get headers => {};

  @override
  String get method => 'GET';

  @override
  Uri get uri => Uri.parse('http://example.com');
}

class _FakeScheme implements PaymentSchemeVerifier {
  final bool supportsHeader;
  final bool isValid;
  final String? reason;
  int callCount = 0;

  _FakeScheme({
    this.supportsHeader = false,
    this.isValid = false,
    this.reason,
  });

  @override
  bool supports(String paymentHeader) => supportsHeader;

  @override
  Future<VerificationResult> verify({
    required String paymentHeader,
    required X402Request request,
  }) async {
    callCount++;
    if (isValid) {
      return const VerificationResult.valid();
    } else {
      return VerificationResult.invalid(reason);
    }
  }
}
