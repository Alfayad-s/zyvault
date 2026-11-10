import { createHmac, timingSafeEqual } from 'crypto';

export const minRupees = 10;
export const maxRupees = 10000;

export function razorpayKeys() {
  const keyId = process.env.RAZORPAY_KEY_ID?.trim() ?? '';
  const keySecret = process.env.RAZORPAY_KEY_SECRET?.trim() ?? '';
  if (!keyId || !keySecret) return null;
  return { keyId, keySecret };
}

export function wholeRupees(value) {
  return Number.isInteger(value) && value >= minRupees && value <= maxRupees;
}

export function signaturesMatch(expected, received) {
  if (typeof expected !== 'string' || typeof received !== 'string') return false;
  const left = Buffer.from(expected);
  const right = Buffer.from(received);
  if (left.length === 0 || left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

export function paymentSignature(orderId, paymentId, secret) {
  return createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
}

export function webhookSignature(rawBody, secret) {
  return createHmac('sha256', secret).update(rawBody).digest('hex');
}
