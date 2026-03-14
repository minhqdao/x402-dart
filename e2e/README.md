# End-to-End Tests


These end-to-end tests verify that the Dart implementation interoperates correctly with both Dart and TypeScript clients and servers. The tests exercise the full payment flow across different client–server combinations.

The following scenarios are covered:

- **Dart Client <> Dart Server**  
  Ensures the Dart implementation works end-to-end within the Dart ecosystem.

- **Dart Client <> TypeScript Server**  
  Verifies that Dart clients can interact with the official TypeScript server implementation.

- **TypeScript Client <> Dart Server**  
  Confirms that TypeScript clients (including the reference implementation) can interact with the Dart server.

- **_denied**  
  Verifies correct behavior when a payment request is rejected by the user.

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

For convenience, you can also run the tests with `melos e2e` after having added all the necessary information to the `.env` file.

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
