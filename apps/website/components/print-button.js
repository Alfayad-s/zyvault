'use client';

export function PrintButton() {
  return (
    <button className="cta ghost no-print" type="button" onClick={() => window.print()}>
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 2h12v6H6V2zm12 8H6a3 3 0 0 0-3 3v5h4v4h10v-4h4v-5a3 3 0 0 0-3-3zm-2 10H8v-4h8v4zm2-6.5a1 1 0 1 1 0-2 1 1 0 0 1 0 2z" />
      </svg>
      Print these steps
    </button>
  );
}
