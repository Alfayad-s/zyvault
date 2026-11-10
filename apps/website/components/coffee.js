'use client';

import { useState } from 'react';

const presets = [50, 100, 250];

function loadCheckout() {
  if (typeof window !== 'undefined' && window.Razorpay) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-razorpay="checkout"]');
    if (existing) {
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error('checkout')), { once: true });
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.dataset.razorpay = 'checkout';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('checkout'));
    document.body.appendChild(script);
  });
}

export function Coffee() {
  const [preset, setPreset] = useState(100);
  const [custom, setCustom] = useState('');
  const [busy, setBusy] = useState(false);
  const [paid, setPaid] = useState(false);
  const [message, setMessage] = useState('');

  const customRupees = custom.trim() === '' ? null : Number(custom);
  const amountRupees = customRupees === null ? preset : customRupees;
  const amountReady = Number.isInteger(amountRupees) && amountRupees >= 10 && amountRupees <= 10000;

  async function pay() {
    if (!amountReady || busy) return;
    setBusy(true);
    setMessage('');
    try {
      const orderResponse = await fetch('/api/coffee/order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amountRupees }),
      });
      const order = await orderResponse.json().catch(() => null);
      if (!orderResponse.ok) {
        setMessage(order?.error || 'Coffee payments are not turned on yet.');
        return;
      }

      await loadCheckout();
      await new Promise((resolve) => {
        let settled = false;
        const finish = () => {
          if (settled) return;
          settled = true;
          resolve();
        };
        const checkout = new window.Razorpay({
          key: order.keyId,
          amount: order.amount,
          currency: order.currency,
          name: 'zyvault',
          description: 'Buy me a coffee',
          order_id: order.orderId,
          theme: { color: '#1c1e24' },
          handler: async (response) => {
            try {
              const verifyResponse = await fetch('/api/coffee/verify', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  orderId: response.razorpay_order_id,
                  paymentId: response.razorpay_payment_id,
                  signature: response.razorpay_signature,
                }),
              });
              const verified = await verifyResponse.json().catch(() => null);
              if (!verifyResponse.ok) {
                setMessage(verified?.error || 'This payment could not be confirmed.');
              } else {
                setPaid(true);
              }
            } catch {
              setMessage('This payment could not be confirmed.');
            }
            finish();
          },
          modal: { ondismiss: finish },
        });
        checkout.on('payment.failed', () => {
          setMessage('The payment did not go through.');
          finish();
        });
        checkout.open();
      });
    } catch {
      setMessage('Razorpay could not open. Try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="coffee" id="coffee">
      <p className="pill">Coffee</p>
      <h2>Buy me a coffee</h2>
      <p className="coffee-note">
        This pays the maker through Razorpay, by UPI or card. It does not move money in the app.
      </p>
      {paid ? (
        <p className="coffee-thanks">Thank you. The coffee is in.</p>
      ) : (
        <>
          <div className="coffee-amounts">
            {presets.map((rupees) => (
              <button
                key={rupees}
                type="button"
                aria-pressed={custom.trim() === '' && preset === rupees}
                onClick={() => {
                  setPreset(rupees);
                  setCustom('');
                  setMessage('');
                }}
              >
                ₹{rupees}
              </button>
            ))}
          </div>
          <label className="coffee-custom">
            <span>Other amount</span>
            <input
              inputMode="numeric"
              autoComplete="off"
              placeholder="Rupees"
              value={custom}
              onChange={(event) => {
                setCustom(event.target.value.replace(/\D/g, '').slice(0, 5));
                setMessage('');
              }}
            />
          </label>
          <button className="coffee-pay" type="button" disabled={!amountReady || busy} onClick={pay}>
            {busy ? 'Opening Razorpay…' : `Pay ₹${Number.isInteger(amountRupees) ? amountRupees : ''}`}
          </button>
          {message ? <p className="coffee-status">{message}</p> : null}
        </>
      )}
    </section>
  );
}
