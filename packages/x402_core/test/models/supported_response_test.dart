import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('SupportedResponse', () {
    const json = {
      'kinds': [
        {
          'x402Version': 2,
          'scheme': 'exact',
          'network': 'eip155:1',
        },
        {
          'x402Version': 1,
          'scheme': 'exact',
          'network': 'invalid-legacy-network',
        }
      ],
      'extensions': ['ext1'],
      'signers': {
        'eip155:*': ['0x123']
      },
    };

    test('fromJson skips invalid kinds', () {
      final response = SupportedResponse.fromJson(json);
      expect(response.kinds, hasLength(1));
      expect(response.kinds[0].network.identifier, 'eip155:1');
      expect(response.extensions, ['ext1']);
      expect(response.signers['eip155:*'], ['0x123']);
    });

    test('toJson', () {
      const response = SupportedResponse(
        kinds: [
          SupportedKind(
            x402Version: 2,
            scheme: 'exact',
            network: Network(namespace: 'eip155', reference: '1'),
          ),
        ],
        extensions: ['ext1'],
        signers: {
          'eip155:*': ['0x123']
        },
      );
      final out = response.toJson();
      expect(out['kinds'], hasLength(1));
      expect(out['extensions'], ['ext1']);
      expect(out['signers'], {
        'eip155:*': ['0x123']
      });
    });
  });
}
