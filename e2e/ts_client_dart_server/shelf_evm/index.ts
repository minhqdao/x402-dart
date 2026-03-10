import { config } from "dotenv";

import { wrapFetchWithPayment, x402Client, x402HTTPClient } from "@x402/fetch";
import { ExactEvmScheme, toClientEvmSigner } from "@x402/evm";

import { createPublicClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";

config();

const evmPrivateKey = process.env.EVM_PRIVATE_KEY as `0x${string}`;
const baseURL = process.env.RESOURCE_SERVER_URL ?? "http://localhost:8080";

async function main(): Promise<void> {
    if (!evmPrivateKey) {
        throw new Error("EVM_PRIVATE_KEY not set");
    }

    if (!baseURL) {
        throw new Error("RESOURCE_SERVER_URL not set");
    }

    const url = `${baseURL}/premium`;

    const account = privateKeyToAccount(evmPrivateKey);

    const publicClient = createPublicClient({
        chain: baseSepolia,
        transport: http(),
    });

    const signer = toClientEvmSigner(account, publicClient);

    const client = new x402Client();
    client.register("eip155:*", new ExactEvmScheme(signer));

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
