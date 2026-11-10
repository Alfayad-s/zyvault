import { NextResponse } from 'next/server';
import { paymentSignature, razorpayKeys, signaturesMatch } from '../../../../lib/razorpay';

const orderIdPattern = /^order_[A-Za-z0-9]+$/;
const paymentIdPattern = /^pay_[A-Za-z0-9]+$/;
const signaturePattern = /^[a-f0-9]{64}$/;

export async function POST(request) {
  const keys = razorpayKeys();
  if (!keys) {
    return NextResponse.json({ error: 'Coffee payments are not turned on yet.' }, { status: 503 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Payment details are missing.' }, { status: 400 });
  }

  const orderId = body?.orderId;
  const paymentId = body?.paymentId;
  const signature = body?.signature;
  if (
    typeof orderId !== 'string' ||
    typeof paymentId !== 'string' ||
    typeof signature !== 'string' ||
    !orderIdPattern.test(orderId) ||
    !paymentIdPattern.test(paymentId) ||
    !signaturePattern.test(signature)
  ) {
    return NextResponse.json({ error: 'Payment details are not valid.' }, { status: 400 });
  }

  const expected = paymentSignature(orderId, paymentId, keys.keySecret);
  if (!signaturesMatch(expected, signature)) {
    return NextResponse.json({ error: 'This payment could not be confirmed.' }, { status: 400 });
  }

  return NextResponse.json({ ok: true });
}
