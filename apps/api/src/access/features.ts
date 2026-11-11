export const featureKeys = [
  'chat',
  'intelligence',
  'voice',
  'bankSms',
  'upiAlerts',
  'creditCards',
  'goals',
  'people',
  'budgets',
  'plans',
] as const;

export type FeatureKey = (typeof featureKeys)[number];

export const featureLabels: Record<FeatureKey, string> = {
  chat: 'Chat',
  intelligence: 'Intelligence',
  voice: 'Voice',
  bankSms: 'Bank SMS',
  upiAlerts: 'UPI alerts',
  creditCards: 'Credit cards',
  goals: 'Goals',
  people: 'People',
  budgets: 'Budgets',
  plans: 'Plans',
};

export type AppRole = 'admin' | 'member';

export function adminEmails(raw: string | undefined): Set<string> {
  return new Set(
    (raw ?? '')
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .filter((email) => email !== ''),
  );
}

/** An address in ADMIN_EMAILS is admin. A stored admin stays admin. Everyone else is a member. */
export function roleFor(email: string, stored: string | null, admins: Set<string>): AppRole {
  if (admins.has(email.trim().toLowerCase())) return 'admin';
  return stored === 'admin' ? 'admin' : 'member';
}

export function isFeatureKey(value: string): value is FeatureKey {
  return (featureKeys as readonly string[]).includes(value);
}
