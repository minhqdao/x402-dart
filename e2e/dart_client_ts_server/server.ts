import { config } from "dotenv";
import express from "express";
import { paymentMiddleware, x402ResourceServer } from "@x402/express";
import { ExactEvmScheme } from "@x402/evm/exact/server";
import { ExactSvmScheme } from "@x402/svm/exact/server";

config();

const evmAddress = process.env.EVM_ADDRESS as `0x${string}`;
const svmAddress = process.env.SVM_ADDRESS;

if (!evmAddress) {
    console.error("EVM_ADDRESS not found");
    process.exit(1);
}

if (!svmAddress) {
    console.error("SVM_ADDRESS not found");
    process.exit(1);
}

const app = express();

const resourceServer = new x402ResourceServer()
    .register("eip155:84532", new ExactEvmScheme())
    .register("solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1", new ExactSvmScheme());

app.use(
    paymentMiddleware(
        {
            "GET /weather": {
                accepts: [
                    {
                        scheme: "exact",
                        price: "$0.001",
                        network: "eip155:84532",
                        payTo: evmAddress,
                    },
                    {
                        scheme: "exact",
                        price: "$0.001",
                        network: "solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1",
                        payTo: svmAddress,
                    },
                ],
                description: "Access to premium content",
            },
        },
        resourceServer,
    ),
);

app.get("/weather", (req, res) => {
    res.send({
        report: {
            weather: "sunny",
            temperature: 70,
        },
    });
});

const port = 4021;

app.listen(port, () => {
    console.log(`Server listening at http://localhost:${port}`);
});
