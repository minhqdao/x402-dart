import 'dart:io';

import 'package:dio/dio.dart';
import 'package:x402_dio/x402_dio.dart';

void main() async {
  final dio = Dio();
  dio.interceptors.add(X402Interceptor(
    dio: dio,
    signers: [
      // Add signers here
    ],
    onPaymentRequired: (requirement, resource, signer) async {
      final paymentCondition = int.parse(requirement.amount) <= 5000000;
      if (paymentCondition) {
        stdout.writeln('✅ Payment Approved for ${resource.url}');
        return true;
      } else {
        stdout.writeln('❌ Payment Denied for ${resource.url}: Amount too high');
        return false;
      }
    },
  ));

  try {
    final response = await dio.get('https://api.example.com/premium-content');

    if (response.statusCode == 200) {
      stdout.writeln('✅ Success! Received premium content:');
      stdout.writeln(response.data);
      // HTTP 402 is fully handled by X402Interceptor (payment + retry),
      // so it will never reach this point and does not need to be checked here.
    } else {
      throw Exception(
          'Request failed with status ${response.statusCode}: ${response.data}');
    }
  } on DioException catch (e) {
    stdout.writeln('❌ Error during request: ${e.message}');
    if (e.response != null) {
      stdout.writeln('Status: ${e.response?.statusCode}');
      stdout.writeln('Data: ${e.response?.data}');
    }
  } catch (e) {
    stdout.writeln('❌ Unexpected error: $e');
  } finally {
    dio.close();
  }
}
