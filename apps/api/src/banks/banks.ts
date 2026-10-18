export type Bank = {
  id: string;
  name: string;
  short: string;
  color: string;
  mark?: number;
};

export const logoFolder = 'finance-track/bank-logos';

export const banks: Bank[] = [
  { id: 'sbi', name: 'State Bank of India', short: 'SBI', color: '#22409A', mark: 1 },
  { id: 'hdfc', name: 'HDFC Bank', short: 'HDFC', color: '#004C8F', mark: 1 },
  { id: 'icici', name: 'ICICI Bank', short: 'ICICI', color: '#B02A30', mark: 0.85 },
  { id: 'axis', name: 'Axis Bank', short: 'AXIS', color: '#97144D', mark: 1 },
  { id: 'kotak', name: 'Kotak Mahindra Bank', short: 'KOTAK', color: '#E2231A', mark: 1 },
  { id: 'pnb', name: 'Punjab National Bank', short: 'PNB', color: '#A6192E', mark: 1 },
  { id: 'bob', name: 'Bank of Baroda', short: 'BOB', color: '#F15A29', mark: 1 },
  { id: 'canara', name: 'Canara Bank', short: 'CANARA', color: '#0072BC' },
  { id: 'union', name: 'Union Bank of India', short: 'UBI', color: '#D7282F', mark: 1 },
  { id: 'boi', name: 'Bank of India', short: 'BOI', color: '#E8730C' },
  { id: 'indian', name: 'Indian Bank', short: 'IB', color: '#1D4F91' },
  { id: 'iob', name: 'Indian Overseas Bank', short: 'IOB', color: '#0B5394', mark: 1 },
  { id: 'central', name: 'Central Bank of India', short: 'CBI', color: '#C8102E', mark: 1 },
  { id: 'uco', name: 'UCO Bank', short: 'UCO', color: '#0065B3' },
  { id: 'indusind', name: 'IndusInd Bank', short: 'INDUS', color: '#98272A' },
  { id: 'yes', name: 'Yes Bank', short: 'YES', color: '#0055A5', mark: 1 },
  { id: 'idfc', name: 'IDFC FIRST Bank', short: 'IDFC', color: '#9C1D26', mark: 1 },
  { id: 'federal', name: 'Federal Bank', short: 'FED', color: '#13438C' },
  { id: 'sib', name: 'South Indian Bank', short: 'SIB', color: '#B51F31', mark: 0.62 },
  { id: 'csb', name: 'CSB Bank', short: 'CSB', color: '#0C5AA6', mark: 0.72 },
  { id: 'dhanlaxmi', name: 'Dhanlaxmi Bank', short: 'DLB', color: '#6B2C91' },
  { id: 'kgb', name: 'Kerala Gramin Bank', short: 'KGB', color: '#2E7D32', mark: 0.62 },
  { id: 'au', name: 'AU Small Finance Bank', short: 'AU', color: '#F37021', mark: 1 },
  { id: 'ippb', name: 'India Post Payments Bank', short: 'IPPB', color: '#D91F26', mark: 1 },
  { id: 'paytm', name: 'Paytm Payments Bank', short: 'PAYTM', color: '#00A6E0' },
  { id: 'airtel', name: 'Airtel Payments Bank', short: 'AIRTEL', color: '#E40000', mark: 1 },
  { id: 'other', name: 'Other bank', short: 'BANK', color: '#3A3A3C' },
];

export const bankIds = banks.map((bank) => bank.id);

export function logoUrl(cloudName: string, id: string): string | null {
  if (id === 'other') return null;
  return `https://res.cloudinary.com/${cloudName}/image/upload/e_trim/c_fit,w_320,h_160/f_png/${logoFolder}/${id}`;
}

export function markUrl(cloudName: string, bank: Bank): string | null {
  if (!bank.mark) return null;
  return `https://res.cloudinary.com/${cloudName}/image/upload/e_trim/c_crop,g_west,ar_${bank.mark}/c_pad,w_160,h_160/f_png/${logoFolder}/${bank.id}`;
}
