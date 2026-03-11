import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:x402_core/x402_core.dart';
import 'package:x402_shelf/x402_shelf.dart';

void main() async {
  final routes = {
    const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
      accepts: [
        // add payment options
      ],
      description: 'Access to premium content',
    ),
  };

  final resourceServer = await X402ResourceServer.create(
    schemeServers: [
      // add your scheme servers here
    ],
  );

  final handler = const Pipeline()
      .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
      .addHandler((request) => Response.ok('Request for "${request.url}"'));

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);

  stdout.writeln(
    'Server running on http://${server.address.host}:${server.port}',
  );
}
