@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

/// Thrown for transient payment failures (e.g. 402/500 with
/// `settlement_pending` from Solana 429 Too Many Requests).
///
/// Only this error (plus network-level [Exception]s) is retried.
/// `TestFailure` from content assertions is *not* retried so genuine
/// regressions stay visible.
class TransientPaymentFailure implements Exception {
  final String message;
  TransientPaymentFailure(this.message);
  @override
  String toString() => 'TransientPaymentFailure: $message';
}

void main() {
  late final Uri uri;
  late final String url;

  Future<void> ensureNodeAvailable() async {
    final node = await Process.run('node', ['--version']);
    if (node.exitCode != 0) {
      markTestSkipped('Node.js not installed');
    }
  }

  /// Retries a payment attempt on transient failures.
  ///
  /// Solana devnet / facilitator can return transient `settlement_pending`
  /// under load. Each attempt builds a fresh transaction (new blockhash +
  /// random memo), so retrying is safe (note: a retry submits a *new*
  /// on-chain transfer; fine at test amounts).
  /// Only [TransientPaymentFailure] and network [Exception]s are retried;
  /// `TestFailure` propagates immediately.
  Future<void> retryPayment(
    Future<void> Function() attempt, {
    int maxAttempts = 3,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        await attempt();
        return;
      } on TransientPaymentFailure catch (e) {
        stdout.writeln(
            'Transient payment failure (attempt ${i + 1}/$maxAttempts): $e');
        if (i == maxAttempts - 1) {
          fail('Payment still failing after $maxAttempts attempts: $e');
        }
        await Future.delayed(Duration(seconds: 5 * (i + 1)));
      } on Exception catch (e) {
        // Network-level transient (socket, timeout, Dio without response).
        stdout.writeln(
            'Transient network error (attempt ${i + 1}/$maxAttempts): $e');
        if (i == maxAttempts - 1) rethrow;
        await Future.delayed(Duration(seconds: 5 * (i + 1)));
      }
      // TestFailure/Error propagates immediately without retry.
    }
  }

  final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();

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
  var tsServerStarted = false;

  setUpAll(() async {
    await ensureNodeAvailable();

    // Start TS server
    tsServer = await Process.start(
      Platform.isWindows
          ? r'node_modules\.bin\tsx.cmd'
          : 'node_modules/.bin/tsx',
      ['dart_client_ts_server/server.ts'],
      environment: {
        ...Platform.environment,
        'EVM_ADDRESS': evmAddress,
        'SVM_ADDRESS': svmAddress,
        // Let the OS select a free port so parallel jobs cannot collide.
        'PORT': '0',
      },
    );
    tsServerStarted = true;

    final serverReady = Completer<Uri>();
    final output = StringBuffer();
    final listeningPattern = RegExp(r'Server listening at (http://\S+)');

    tsServer.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln(line);
      output.writeln(line);
      final match = listeningPattern.firstMatch(line);
      if (match != null && !serverReady.isCompleted) {
        serverReady.complete(Uri.parse('${match.group(1)}/weather'));
      }
    });
    tsServer.stderr.transform(utf8.decoder).listen((chunk) {
      stderr.write(chunk);
      output.write(chunk);
    });

    unawaited(tsServer.exitCode.then((exitCode) {
      if (!serverReady.isCompleted) {
        serverReady.completeError(
          StateError(
            'TS server exited with code $exitCode before becoming ready.\n'
            '$output',
          ),
        );
      }
    }));

    uri = await serverReady.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'TS server did not become ready within 30 seconds.\n$output',
      ),
    );
    url = uri.toString();
  });

  tearDownAll(() async {
    if (!tsServerStarted) return;
    tsServer.kill();
    try {
      await tsServer.exitCode.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      tsServer.kill(ProcessSignal.sigkill);
      await tsServer.exitCode;
    }
  });

  group('Clients using wrapper', () {
    test('Client wrapper pays for premium content', () async {
      await retryPayment(() async {
        final evmSigner = EvmSigner.fromPrivateKeyHex(
          privateKeyHex: evmPrivateKey,
          chainId: 84532,
        );

        final client = X402Client(
          signers: [evmSigner],
          retryDelay: const Duration(seconds: 1),
        );

        try {
          final response = await client.get(uri);

          if (response.statusCode != 200) {
            throw TransientPaymentFailure(
              'wrapper EVM: ${response.statusCode} body=${response.body}',
            );
          }

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
        } finally {
          client.close();
        }
      });
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
      await retryPayment(() async {
        final svmSigner = await SvmSigner.fromPrivateKeyHex(
          privateKeyHex: svmPrivateKey,
          cluster: SolanaCluster.devnet,
        );

        final client = X402Client(
          signers: [svmSigner],
          retryDelay: const Duration(seconds: 1),
        );

        try {
          final response = await client.get(uri);

          if (response.statusCode != 200) {
            throw TransientPaymentFailure(
              'wrapper SVM: ${response.statusCode} body=${response.body}',
            );
          }

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
        } finally {
          client.close();
        }
      });
    }, timeout: const Timeout(Duration(minutes: 2)));

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
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Manually-handled clients', () {
    test('Manual payment flow via EVM', () async {
      await retryPayment(() async {
        final client = Client();

        try {
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

          if (retryResponse.statusCode != 200) {
            throw TransientPaymentFailure(
              'manual EVM: ${retryResponse.statusCode} body=${retryResponse.body}',
            );
          }

          // Verify SettleResponse header
          final settleHeader = retryResponse.headers[kPaymentResponseHeader];
          expect(settleHeader, isNotNull,
              reason: 'Should return x402-payment-response header');
          final settleResponse = SettleResponse.fromHeader(settleHeader!);
          expect(settleResponse.success, isTrue);
          expect(settleResponse.transaction, isNotEmpty);

          final decoded =
              json.decode(retryResponse.body) as Map<String, dynamic>;
          expect(decoded, contains('report'));
          final report = decoded['report'] as Map<String, dynamic>;
          expect(report['weather'], equals('sunny'));
          expect(report['temperature'], equals(70));
        } finally {
          client.close();
        }
      });
    });

    test('Manual payment flow via SVM', () async {
      await retryPayment(() async {
        final client = Client();

        try {
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

          if (retryResponse.statusCode != 200) {
            throw TransientPaymentFailure(
              'manual SVM: ${retryResponse.statusCode} body=${retryResponse.body}',
            );
          }

          // Verify SettleResponse header
          final settleHeader = retryResponse.headers[kPaymentResponseHeader];
          expect(settleHeader, isNotNull,
              reason: 'Should return x402-payment-response header');
          final settleResponse = SettleResponse.fromHeader(settleHeader!);
          expect(settleResponse.success, isTrue);
          expect(settleResponse.transaction, isNotEmpty);

          final decoded =
              json.decode(retryResponse.body) as Map<String, dynamic>;
          expect(decoded, contains('report'));
          final report = decoded['report'] as Map<String, dynamic>;
          expect(report['weather'], equals('sunny'));
          expect(report['temperature'], equals(70));
        } finally {
          client.close();
        }
      });
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Clients using the Dio interceptor', () {
    test('Client Dio pays for premium content via EVM', () async {
      await retryPayment(() async {
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

          if (response.statusCode != 200) {
            throw TransientPaymentFailure(
              'Dio EVM: ${response.statusCode} data=${response.data}',
            );
          }

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
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status == 402 ||
              status == 500 ||
              status == 429 ||
              status == 503 ||
              e.response == null) {
            throw TransientPaymentFailure(
              'Dio EVM DioException: $status ${e.message} data=${e.response?.data}',
            );
          }
          fail('Received unexpected DioException: ${e.message}');
        } finally {
          dio.close(force: true);
        }
      });
    });

    test('Client Dio returns 402 when payment is denied via EVM', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        chainId: 84532,
        privateKeyHex: evmPrivateKey,
      );

      final dio = Dio();
      addTearDown(() => dio.close(force: true));
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
      await retryPayment(() async {
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

          if (response.statusCode != 200) {
            throw TransientPaymentFailure(
              'Dio SVM: ${response.statusCode} data=${response.data}',
            );
          }

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
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status == 402 ||
              status == 500 ||
              status == 429 ||
              status == 503 ||
              e.response == null) {
            throw TransientPaymentFailure(
              'Dio SVM DioException: $status ${e.message} data=${e.response?.data}',
            );
          }
          fail('Received unexpected DioException: ${e.message}');
        } finally {
          dio.close(force: true);
        }
      });
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Client Dio returns 402 when payment is denied via SVM', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final dio = Dio();
      addTearDown(() => dio.close(force: true));
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
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
