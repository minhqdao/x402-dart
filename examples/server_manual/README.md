# x402 Manual Server Example

This example shows how to build an HTTP server that handles the x402 payment flow using only the components from `x402`. No framework integration is used. The server performs the full process itself: building payment requirements, verifying payments, and settling them.

## Setup

Copy the environment template:

```bash
cp .env-example .env
```

Then add the required addresses to `.env`:

```
EVM_ADDRESS=<your-evm-address>
SVM_ADDRESS=<your-solana-address>
```

## Run the Server

Install dependencies if needed:

```bash
dart pub get
```

Start the server:

```bash
dart bin/manual_server.dart
```

The server listens on http://localhost:8080.

## Usage

Test the routes:

   - **Public route** (No payment needed):
     ```bash
     curl http://localhost:8080/public
     ```

   - **Protected route** (Returns 402 Payment Required):
     ```bash
     curl -v http://localhost:8080/protected
     ```

You can run also the clients from the [example](https://github.com/minhqdao/x402-dart/tree/main/examples) folder against this server. If correctly set up, they can interact with the `/protected` route and complete the payment flow.
