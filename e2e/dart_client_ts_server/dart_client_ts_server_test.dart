import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() {
  const url = 'http://localhost:4021/weather';
  final uri = Uri.parse(url);

  Future<void> ensureNodeAvailable() async {
    final node = await Process.run('node', ['--version']);
    if (node.exitCode != 0) {
      markTestSkipped('Node.js not installed');
    }
  }

  Future<void> waitForServer() async {
    final client = HttpClient();

    for (var i = 0; i < 30; i++) {
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 402 || response.statusCode == 200) return;
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 1));
    }

    throw Exception("TS server did not start");
  }

  final env = DotEnv(includePlatformEnvironment: true)..load();

  final evmAddress = env['EVM_ADDRESS'];
  if (evmAddress == null || evmAddress.isEmpty) {
    fail('EVM_ADDRESS is not set in environment or .env file.');
  }

  final svmAddress = env['SVM_ADDRESS'];
  if (svmAddress == null || svmAddress.isEmpty) {
    fail('SVM_ADDRESS is not set in environment or .env file.');
  }

  final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
  if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
    fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
  }

  final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
  if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
    fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
  }

  late final Process tsServer;

  setUpAll(() async {
    await ensureNodeAvailable();

    // Start TS server
    tsServer = await Process.start(
      'npm',
      ['run', 'ts-server'],
      environment: {
        ...Platform.environment,
        'EVM_ADDRESS': evmAddress,
        'SVM_ADDRESS': svmAddress,
      },
    );

    tsServer.stdout.transform(utf8.decoder).listen(stdout.writeln);
    tsServer.stderr.transform(utf8.decoder).listen(stderr.writeln);

    await waitForServer();
    stdout.writeln('TS server is up and running');
  });

  tearDownAll(() => tsServer.kill());

  group('Clients using wrapper', () {
    test('Client wrapper pays for premium content', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        privateKeyHex: evmPrivateKey,
        chainId: 84532,
      );

      final client = X402Client(
        signers: [evmSigner],
        retryDelay: const Duration(seconds: 1),
      );

      addTearDown(() => client.close());

      try {
        final response = await client.get(uri);

        expect(response.statusCode, equals(200),
            reason: 'Should return 200 OK after payment');

        // Verify SettleResponse header
        final settleHeader = response.headers[kPaymentResponseHeader];
        expect(settleHeader, isNotNull,
            reason: 'Should return x402-payment-response header');
        final settleResponse = SettleResponse.fromHeader(settleHeader!);
        expect(settleResponse.success, isTrue);

        expect(response.body, isNotEmpty,
            reason: 'Response body should not be empty');

        final decoded = json.decode(response.body) as Map<String, dynamic>;
        expect(decoded, contains('report'));

        final report = decoded['report'] as Map<String, dynamic>;
        expect(report['weather'], equals('sunny'));
        expect(report['temperature'], equals(70));
      } catch (e) {
        fail('Exception during request: $e');
      }
    });

    test('Client wrapper returns 402 when payment is denied', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        chainId: 84532,
        privateKeyHex: evmPrivateKey,
      );

      final client = X402Client(
        signers: [evmSigner],
        onPaymentRequired: (req, resource, signer) async => false,
      );

      addTearDown(() => client.close());

      try {
        final response = await client.get(uri);

        expect(response.statusCode, equals(402),
            reason:
                'Should return 402 Payment Required when user denies payment');
      } catch (e) {
        fail('Exception during request: $e');
      }
    });

    test('Client wrapper pays for premium content via SVM', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final client = X402Client(
        signers: [svmSigner],
        retryDelay: const Duration(seconds: 1),
      );

      addTearDown(() => client.close());

      try {
        final response = await client.get(uri);

        expect(response.statusCode, equals(200),
            reason: 'Should return 200 OK after payment');

        // Verify SettleResponse header
        final settleHeader = response.headers[kPaymentResponseHeader];
        expect(settleHeader, isNotNull,
            reason: 'Should return x402-payment-response header');
        final settleResponse = SettleResponse.fromHeader(settleHeader!);
        expect(settleResponse.success, isTrue);

        expect(response.body, isNotEmpty,
            reason: 'Response body should not be empty');

        final decoded = json.decode(response.body) as Map<String, dynamic>;
        expect(decoded, contains('report'));

        final report = decoded['report'] as Map<String, dynamic>;
        expect(report['weather'], equals('sunny'));
        expect(report['temperature'], equals(70));
      } catch (e) {
        fail('Exception during request: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('Client wrapper returns 402 when payment is denied via SVM', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final client = X402Client(
        signers: [svmSigner],
        onPaymentRequired: (req, resource, signer) async => false,
      );

      addTearDown(() => client.close());

      try {
        final response = await client.get(uri);

        expect(response.statusCode, equals(402),
            reason:
                'Should return 402 Payment Required when user denies payment');
      } catch (e) {
        fail('Exception during request: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('Manually-handled clients', () {
    test('Manual payment flow via EVM', () async {
      final client = Client();
      addTearDown(() => client.close());

      // 1. Initial Request
      final initialResponse = await client.get(uri);

      expect(initialResponse.statusCode, equals(402),
          reason: 'Initial request should return 402 Payment Required');

      // 2. Parse 402 Header
      final header = initialResponse.headers[kPaymentRequiredHeader];
      expect(header, isNotNull,
          reason: 'Missing $kPaymentRequiredHeader header');

      final paymentResponse = PaymentRequiredResponse.fromHeader(header!);

      // 3. Setup Signer and Sign
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        chainId: 84532,
        privateKeyHex: evmPrivateKey,
      );

      final requirement = paymentResponse.findFirstSupportedBy(evmSigner);
      expect(requirement, isNotNull,
          reason: 'No compatible requirement found for EVM signer');

      final signature = await evmSigner.sign(
        requirement!,
        paymentResponse.resource,
        extensions: paymentResponse.extensions,
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // 4. Retry Request with Signature
      final retryResponse = await client.get(
        uri,
        headers: {kPaymentSignatureHeader: signature.encoded},
      );

      expect(retryResponse.statusCode, equals(200),
          reason: 'Retry with signature should return 200 OK');

      // Verify SettleResponse header
      final settleHeader = retryResponse.headers[kPaymentResponseHeader];
      expect(settleHeader, isNotNull,
          reason: 'Should return x402-payment-response header');
      final settleResponse = SettleResponse.fromHeader(settleHeader!);
      expect(settleResponse.success, isTrue);
      expect(settleResponse.transaction, isNotEmpty);

      final decoded = json.decode(retryResponse.body) as Map<String, dynamic>;
      expect(decoded, contains('report'));
      final report = decoded['report'] as Map<String, dynamic>;
      expect(report['weather'], equals('sunny'));
      expect(report['temperature'], equals(70));
    });

    test('Manual payment flow via SVM', () async {
      final client = Client();
      addTearDown(() => client.close());

      // 1. Initial Request
      final initialResponse = await client.get(uri);

      expect(initialResponse.statusCode, equals(402),
          reason: 'Initial request should return 402 Payment Required');

      // 2. Parse 402 Header
      final header = initialResponse.headers[kPaymentRequiredHeader];
      expect(header, isNotNull,
          reason: 'Missing $kPaymentRequiredHeader header');

      final paymentResponse = PaymentRequiredResponse.fromHeader(header!);

      // 3. Setup Signer and Sign
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final requirement = paymentResponse.findFirstSupportedBy(svmSigner);
      expect(requirement, isNotNull,
          reason: 'No compatible requirement found for SVM signer');

      final signature = await svmSigner.sign(
        requirement!,
        paymentResponse.resource,
        extensions: paymentResponse.extensions,
      );

      // 4. Retry Request with Signature
      final retryResponse = await client.get(
        uri,
        headers: {kPaymentSignatureHeader: signature.encoded},
      );

      expect(retryResponse.statusCode, equals(200),
          reason: 'Retry with signature should return 200 OK');

      // Verify SettleResponse header
      final settleHeader = retryResponse.headers[kPaymentResponseHeader];
      expect(settleHeader, isNotNull,
          reason: 'Should return x402-payment-response header');
      final settleResponse = SettleResponse.fromHeader(settleHeader!);
      expect(settleResponse.success, isTrue);
      expect(settleResponse.transaction, isNotEmpty);

      final decoded = json.decode(retryResponse.body) as Map<String, dynamic>;
      expect(decoded, contains('report'));
      final report = decoded['report'] as Map<String, dynamic>;
      expect(report['weather'], equals('sunny'));
      expect(report['temperature'], equals(70));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('Clients using the Dio interceptor', () {
    test('Client Dio pays for premium content via EVM', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        chainId: 84532,
        privateKeyHex: evmPrivateKey,
      );

      final dio = Dio();
      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [evmSigner],
        retryDelay: const Duration(seconds: 1),
      ));

      try {
        final response = await dio.get(url);

        expect(response.statusCode, equals(200),
            reason: 'Should return 200 OK after payment');

        // Verify SettleResponse header
        final settleHeader = response.headers.value(kPaymentResponseHeader);
        expect(settleHeader, isNotNull,
            reason: 'Should return x402-payment-response header');
        final settleResponse = SettleResponse.fromHeader(settleHeader!);
        expect(settleResponse.success, isTrue);

        expect(response.data, isNotEmpty,
            reason: 'Response body should not be empty');

        // Dio automatically decodes JSON if content-type is application/json
        final data = response.data as Map<String, dynamic>;
        expect(data, contains('report'));

        final report = data['report'] as Map<String, dynamic>;
        expect(report['weather'], equals('sunny'));
        expect(report['temperature'], equals(70));
      } catch (e) {
        fail('Exception during request: $e');
      }
    });

    test('Client Dio returns 402 when payment is denied via EVM', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        chainId: 84532,
        privateKeyHex: evmPrivateKey,
      );

      final dio = Dio();
      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [evmSigner],
        onPaymentRequired: (req, resource, signer) async {
          return false; // Deny payment
        },
      ));

      try {
        final response = await dio.get(url);

        expect(
          response.statusCode,
          equals(402),
          reason: 'Should return 402 Payment Required when user denies payment',
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 402) {
          expect(e.response?.statusCode, equals(402));
        } else {
          fail('Received unexpected DioException: ${e.message}');
        }
      } catch (e) {
        fail('Exception during request: $e');
      }
    });

    test('Client Dio pays for premium content via SVM', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final dio = Dio();
      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [svmSigner],
        retryDelay: const Duration(seconds: 1),
      ));

      try {
        final response = await dio.get(url);

        expect(response.statusCode, equals(200),
            reason: 'Should return 200 OK after payment');

        // Verify SettleResponse header
        final settleHeader = response.headers.value(kPaymentResponseHeader);
        expect(settleHeader, isNotNull,
            reason: 'Should return x402-payment-response header');
        final settleResponse = SettleResponse.fromHeader(settleHeader!);
        expect(settleResponse.success, isTrue);

        expect(response.data, isNotEmpty,
            reason: 'Response body should not be empty');

        // Dio automatically decodes JSON if content-type is application/json
        final data = response.data as Map<String, dynamic>;
        expect(data, contains('report'));

        final report = data['report'] as Map<String, dynamic>;
        expect(report['weather'], equals('sunny'));
        expect(report['temperature'], equals(70));
      } catch (e) {
        fail('Exception during request: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('Client Dio returns 402 when payment is denied via SVM', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final dio = Dio();
      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [svmSigner],
        onPaymentRequired: (req, resource, signer) async => false,
      ));

      try {
        final response = await dio.get(url);

        // Note: If X402Interceptor works correctly, it should let the 402 through if rejected.
        // However, Dio usually throws on 4xx unless configured otherwise.
        // The X402Interceptor might need to handle this.
        expect(response.statusCode, equals(402),
            reason:
                'Should return 402 Payment Required when user denies payment');
      } on DioException catch (e) {
        if (e.response?.statusCode == 402) {
          expect(e.response?.statusCode, equals(402));
        } else {
          fail('Received unexpected DioException: ${e.message}');
        }
      } catch (e) {
        fail('Exception during request: $e');
      }
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
