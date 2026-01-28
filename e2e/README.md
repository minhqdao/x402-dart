# x402 End-to-End Tests

This directory contains end-to-end tests for the x402 protocol, covering both EVM and SVM implementations across different HTTP clients (Standard HTTP and Dio).

## Overview

The tests spin up a complete environment including:
- **Facilitator**: Negotiates and verifies payments.
- **Resource Server**: A mock server that requires x402 payments to access "weather" data.
- **Dart Clients**: Various E2E test packages that exercise different client implementations.

The Facilitator and Resource Server are taken from the official [x402 TypeScript examples](https://github.com/coinbase/x402/tree/main/examples/typescript).

## Prerequisites

To run these tests locally, you need:
1. **Docker & Docker Compose** installed.
2. **Public Addresses** and **Private Keys** with funds on:
   - **Base Sepolia** (EVM)
   - **Solana Devnet** (SVM)

## Running Locally

1. Navigate to the `e2e` directory.
   ```bash
   cd e2e
   ```
2. Create a `.env` file from the example:
   ```bash
   cp .env-example .env
   ```
3. Fill in the values in the `.env` file:
   ```env
   EVM_PRIVATE_KEY_PAYER=your_evm_private_key
   SVM_PRIVATE_KEY_PAYER=your_svm_private_key
   ...
   ```

4. Execute the tests:
   ```bash
   docker compose up --build --abort-on-container-exit
   ```

## Continuous Integration

These tests run automatically on every push via GitHub Actions.

### Forking & Secrets
If you fork this repository, the E2E tests in the CI will fail unless you provide your own secrets in the repository settings:
- `EVM_PRIVATE_KEY_PAYER`: Private key used by the client to sign EVM payments.
- `SVM_PRIVATE_KEY_PAYER`: Private key used by the client to sign SVM payments.
- `EVM_PRIVATE_KEY`: Private key for the facilitator (EVM).
- `SVM_PRIVATE_KEY`: Private key for the facilitator (SVM).
- `EVM_ADDRESS`: Target address for EVM payments.
- `SVM_ADDRESS`: Target address for SVM payments.

## Test Cases

- **wrapper_***: Tests using the high-level `X402Client` (http package wrapper).
- **dio_***: Tests using the `X402Interceptor` for Dio.
- **manual_***: Tests demonstrating manual handling of the 402 flow.
- **_denied**: Verifies that the client correctly handles user-rejected payment requests.
