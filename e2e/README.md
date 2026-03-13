# End-to-End Tests

This directory contains end-to-end tests for the x402 protocol, covering various client and server combinations for both EVM and SVM.

## Overview

These end-to-end tests validate the cross-compatibility of the x402 protocol across various client and server implementations, including the official TypeScript reference. The test suite ensures seamless interaction between Dart and TypeScript components, covering both EVM and SVM.

## Prerequisites

To run these tests locally, you need:
1.  **Node.js and npm**: Required for setting up TypeScript-based servers and clients.
2.  **Dart SDK**: Required for running Dart-based servers and clients, and for executing the tests.
3.  **Public Addresses** and **Private Keys** with funds on:
    - **Base Sepolia** (EVM)
    - **Solana Devnet** (SVM)

## Running Locally

1.  Navigate to the `e2e` directory.
    ```bash
    cd e2e
    ```
2.  Install TypeScript client/server dependencies:
    ```bash
    npm install
    ```
3.  Create a `.env` file from the example and fill in the values:
    ```bash
    cp .env-example .env
    ```
    Edit the `.env` file with your specific keys and addresses:
    ```env
    EVM_PRIVATE_KEY_PAYER=your_evm_private_key
    SVM_PRIVATE_KEY_PAYER=your_svm_private_key
    ...
    ```

4.  Execute the tests using Dart's test runner:
    ```bash
    dart test --concurrency=1 .
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

The test cases are designed to verify interoperability across client and server stacks, ensuring compatibility with the official TypeScript implementation. They cover:

- **Dart Client <> Dart Server**: Validates end-to-end flow purely within Dart.
- **Dart Client <> TypeScript Server**: Ensures Dart clients can interact with TypeScript servers (including the reference implementation).
- **TypeScript Client <> Dart Server**: Confirms TypeScript clients (including the reference implementation) can interact with Dart servers.
- **_denied**: Verifies correct handling of user-rejected payment requests.
