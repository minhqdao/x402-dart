import { config } from "dotenv";

import { wrapFetchWithPayment, x402Client, x402HTTPClient } from "@x402/fetch";
import { ExactSvmScheme, toClientSvmSigner } from "@x402/svm";

import { createKeyPairSignerFromPrivateKeyBytes } from "@solana/kit";

config();

const svmPrivateKey = process.env.SVM_PRIVATE_KEY;
const baseURL = process.env.RESOURCE_SERVER_URL;

async function main(): Promise<void> {
    if (!svmPrivateKey) {
        throw new Error("SVM_PRIVATE_KEY not set");
    }

    if (!baseURL) {
        throw new Error("RESOURCE_SERVER_URL not set");
    }

    const url = `${baseURL}/premium`;

    const privateKeyBytes = Buffer.from(svmPrivateKey, "hex");

    const keypair = await createKeyPairSignerFromPrivateKeyBytes(
        privateKeyBytes,
    );

    const signer = toClientSvmSigner(keypair);

    const client = new x402Client();
    client.register("solana:*", new ExactSvmScheme(signer));

    if (typeof fetch === "undefined") {
        throw new Error("Global fetch not available. Use Node 18+.");
    }

    const fetchWithPayment = wrapFetchWithPayment(fetch, client);

    console.log(`Requesting: ${url}\n`);

    const response = await fetchWithPayment(url, {
        method: "GET",
    });

    if (!response.ok) {
        const body = await response.text();
        console.error("Response not OK:", response.status, body);
        throw new Error(
            `Expected 200 but got ${response.status}\nBody: ${body}`,
        );
    }

    const body = await response.json();
    console.log("Response body:", JSON.stringify(body, null, 2));

    let paymentResponse;

    try {
        paymentResponse = new x402HTTPClient(client).getPaymentSettleResponse(
            (name) => response.headers.get(name),
        );
    } catch {
        paymentResponse = null;
    }

    if (paymentResponse) {
        console.log(
            "\nPayment response:",
            JSON.stringify(paymentResponse, null, 2),
        );
    } else {
        console.log("\nPayment succeeded (no settlement header returned)");
    }
}

main().catch((error) => {
    console.error("Error in TS client:", error?.message ?? error);
    process.exit(1);
});
