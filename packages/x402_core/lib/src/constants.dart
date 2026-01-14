/// x402 protocol version
const kX402Version = 2;

/// Standard header for payment requirements in 402 response
const kPaymentRequiredHeader = 'payment-required';

/// Standard header for payment proof in request
const kPaymentSignatureHeader = 'payment-signature';

/// Legacy header for payment proof (optional)
const kPaymentHeader = 'X-PAYMENT';

/// HTTP status code for payment required
const kPaymentRequiredStatus = 402;
