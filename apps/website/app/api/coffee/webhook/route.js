import { NextResponse } from 'next/server';
import { signaturesMatch, webhookSignature } from '../../../../lib/razorpay';

export async function POST(request) {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET?.trim() ?? '';
  if (!secret) {
    return NextResponse.json({ error: 'Webhook is not configured.' }, { status: 503 });
  }

  const raw = await request.text();
  const signature = request.headers.get('x-razorpay-signature') ?? '';
  const expected = webhookSignature(raw, secret);
  if (!signaturesMatch(expected, signature)) {
    return NextResponse.json({ error: 'Invalid signature.' }, { status: 400 });
  }

  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return NextResponse.json({ error: 'Invalid body.' }, { status: 400 });
  }

  if (event?.event !== 'payment.captured') {
    return NextResponse.json({ ok: true, ignored: true });
  }

  return NextResponse.json({ ok: true });
}
