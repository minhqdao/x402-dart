/// x402 protocol version
const kX402Version = 2;

/// Standard header for payment requirements in 402 response
const kPaymentRequiredHeader = 'payment-required';

/// Standard header for payment proof in request
const kPaymentSignatureHeader = 'payment-signature';

/// Legacy header for payment proof (optional)
const kPaymentHeader = 'x-payment';

/// HTTP status code for payment required
const kPaymentRequiredStatus = 402;

/// Default facilitator URL (testnet)
const kDefaultFacilitatorUrl = 'https://www.x402.org/facilitator';

/// Standard header for payment response in 402 response
const kPaymentResponseHeader = 'payment-response';
