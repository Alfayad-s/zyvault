import { NextResponse } from 'next/server';
import { maxRupees, minRupees, razorpayKeys, wholeRupees } from '../../../../lib/razorpay';

export async function POST(request) {
  const keys = razorpayKeys();
  if (!keys) {
    return NextResponse.json({ error: 'Coffee payments are not turned on yet.' }, { status: 503 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: `Choose a whole amount from ₹${minRupees} to ₹${maxRupees}.` }, { status: 400 });
  }

  const amountRupees = body?.amountRupees;
  if (!wholeRupees(amountRupees)) {
    return NextResponse.json({ error: `Choose a whole amount from ₹${minRupees} to ₹${maxRupees}.` }, { status: 400 });
  }

  const receipt = `coffee_${Date.now()}`.slice(0, 40);
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(`${keys.keyId}:${keys.keySecret}`).toString('base64')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: amountRupees * 100,
      currency: 'INR',
      receipt,
    }),
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.id) {
    return NextResponse.json({ error: 'Razorpay could not start this payment.' }, { status: 502 });
  }

  return NextResponse.json({
    orderId: payload.id,
    amount: payload.amount,
    currency: payload.currency,
    keyId: keys.keyId,
  });
}
