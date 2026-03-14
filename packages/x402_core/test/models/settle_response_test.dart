import 'dart:convert';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('SettleResponse', () {
    const json = {
      'success': true,
      'errorReason': null,
      'errorMessage': 'Payment processed successfully',
      'payer': '0xPayer',
      'transaction': '0xTx',
      'network': 'eip155:1',
      'extensions': {'foo': 'bar'},
    };

    test('fromJson', () {
      final response = SettleResponse.fromJson(json);
      expect(response.success, true);
      expect(response.errorReason, isNull);
      expect(response.errorMessage, 'Payment processed successfully');
      expect(response.payer, '0xPayer');
      expect(response.transaction, '0xTx');
      expect(response.network.identifier, 'eip155:1');
      expect(response.extensions?['foo'], 'bar');
    });

    test('toJson', () {
      const response = SettleResponse(
        success: true,
        errorMessage: 'Payment processed successfully',
        payer: '0xPayer',
        transaction: '0xTx',
        network: Network(namespace: 'eip155', reference: '1'),
        extensions: {'foo': 'bar'},
      );
      final out = response.toJson();
      expect(out['success'], true);
      expect(out['errorMessage'], 'Payment processed successfully');
      expect(out['payer'], '0xPayer');
      expect(out['transaction'], '0xTx');
      expect(out['network'], 'eip155:1');
      expect(out['extensions'], {'foo': 'bar'});
      expect(out.containsKey('errorReason'), isFalse);
    });

    test('fromJson with missing errorMessage', () {
      final minimalJson = {
        'success': true,
        'transaction': '0xTx',
        'network': 'eip155:1',
      };
      final response = SettleResponse.fromJson(minimalJson);
      expect(response.success, true);
      expect(response.errorMessage, isNull);
    });

    test('fromJson with null payer', () {
      final jsonWithNullPayer = {
        'success': true,
        'payer': null,
        'transaction': '0xTx',
        'network': 'eip155:1',
      };
      final response = SettleResponse.fromJson(jsonWithNullPayer);
      expect(response.payer, isNull);
    });

    test('fromJson with all fields', () {
      final fullJson = {
        'success': true,
        'errorReason': 'reason',
        'errorMessage': 'message',
        'payer': 'payer',
        'transaction': 'tx',
        'network': 'solana:123',
        'extensions': {'foo': 'bar'},
      };
      final response = SettleResponse.fromJson(fullJson);
      expect(response.success, true);
      expect(response.errorReason, 'reason');
      expect(response.errorMessage, 'message');
      expect(response.payer, 'payer');
      expect(response.transaction, 'tx');
      expect(response.network.namespace, 'solana');
      expect(response.network.reference, '123');
      expect(response.extensions, {'foo': 'bar'});
    });

    test('toJson with minimal fields', () {
      const response = SettleResponse(
        success: false,
        transaction: 'tx',
        network: Network(namespace: 'n', reference: 'r'),
      );
      final out = response.toJson();
      expect(out['success'], false);
      expect(out['transaction'], 'tx');
      expect(out['network'], 'n:r');
      expect(out.containsKey('errorReason'), isFalse);
      expect(out.containsKey('errorMessage'), isFalse);
      expect(out.containsKey('payer'), isFalse);
      expect(out.containsKey('extensions'), isFalse);
    });

    test('encoded round-trip', () {
      const response = SettleResponse(
        success: true,
        transaction: '0xTx',
        network: Network(namespace: 'eip155', reference: '1'),
      );
      final encoded = response.encoded;
      final decodedJson = jsonDecode(utf8.decode(base64Decode(encoded)))
          as Map<String, dynamic>;
      final decodedResponse = SettleResponse.fromJson(decodedJson);

      expect(decodedResponse.success, response.success);
      expect(decodedResponse.transaction, response.transaction);
      expect(decodedResponse.network.identifier, response.network.identifier);
    });
  });
}
