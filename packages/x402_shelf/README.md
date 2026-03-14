# x402_shelf

A Shelf middleware for the **x402 payment protocol**.

It allows you to protect HTTP routes behind blockchain-based payments using the standard `402 Payment Required` flow.

> This package supports **V2** of the protocol only. V1 is legacy and unsupported.

`x402_shelf` focuses purely on HTTP transport integration.  
All protocol semantics are delegated to `x402_core` and registered scheme server implementations (e.g. EVM or SVM).

## Features

- Shelf middleware integration via `x402PaymentMiddleware`
- Multi-chain support (EVM and SVM)
- Dynamic per-request payment requirement generation
- Automatic `402 Payment Required` responses

## Installation

Add dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  shelf: ^1.4.2
  x402: ^0.3.0
  x402_shelf: ^0.1.0
```

## Usage

### 1. Define Protected Routes

```dart
final routes = <RoutePattern, RouteConfig>{
  const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
    accepts: [
      PaymentOption(
        scheme: 'exact',
        price: Money('0.10'),
        network: EvmNetwork(chainId: 84532),
        payTo: '0xYourAddress',
      ),
    ],
    description: 'Access to premium content',
  ),
};
```

### 2. Create a Resource Server

The resource server wires your facilitator and scheme servers.

```dart
final resourceServer = await X402ResourceServer.create(
  schemeServers: [
    ExactEvmSchemeServer(chainId: 84532),
  ],
);
```

### 3. Apply the Middleware

```dart
  final handler = const Pipeline()
      .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
      .addHandler((request) => Response.ok('Protected content'));
```

Take a look at the [example](https://github.com/minhqdao/x402-dart/tree/main/examples) folder for a complete implementation.

## How It Works

When a request matches a protected route:

1. The middleware builds payment requirements via `X402ResourceServer`.
2. If no payment proof is provided, it returns `402 Payment Required`.
3. If a payment proof is present:
   - The server verifies it.
   - If valid, the request proceeds.
   - If invalid, a `402` response is returned again.

The middleware handles HTTP orchestration only.  
All payment validation and scheme dispatching live inside the resource server.
