import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

void main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((request) => Response.ok('Request for "${request.url}"'));

  final server = await serve(handler, 'localhost', 8080);

  stdout.writeln('Serving at http://${server.address.host}:${server.port}');
}

// Middleware x402PaymentMiddleware(
//     {void Function(String message, bool isError)? logger}) {
//       return
//     }

// Middleware x402PaymentMiddleware({required PaymentGuard guard}) {
//   return (Handler innerHandler) {
//     return (Request request) async {
//       return innerHandler(request);
//     };
//   };
// }

/// Middleware that enforces x402 payment requirements.
///
/// It uses a [PaymentGuard] to evaluate each request.
// Middleware x402PaymentMiddleware({required PaymentGuard guard}) {
//   return (Handler innerHandler) {
//     return (Request request) async {
//       final x402Request = ShelfX402Request(request);
//       final decision = await guard.evaluate(x402Request);

//       switch (decision.type) {
//         case PaymentDecisionType.allow:
//           return innerHandler(request);

//         case PaymentDecisionType.requirePayment:
//           final requirement = decision.requirement;
//           if (requirement == null) {
//             return Response.internalServerError(
//               body: 'Payment requirement missing from decision.',
//             );
//           }
//           final paymentResponse = PaymentRequiredResponse(
//             x402Version: kX402Version,
//             resource: ResourceInfo(
//               url: request.requestedUri.toString(),
//               description: 'Payment required',
//               mimeType: 'text/plain',
//             ),
//             accepts: [requirement],
//           );

//           final jsonString = jsonEncode(paymentResponse.toJson());
//           final headerValue = base64Encode(utf8.encode(jsonString));

//           return Response(
//             kPaymentRequiredStatus,
//             headers: {
//               kPaymentHeader: headerValue,
//               'WWW-Authenticate': 'x402',
//               'Content-Type': 'application/json',
//             },
//             body: jsonString,
//           );

//         case PaymentDecisionType.reject:
//           return Response.forbidden(decision.reason ?? 'Access denied');
//       }
//     };
//   };
// }
