export const iconFolder = 'finance-track/category-icons';

export const categoryIcons = [
  'food',
  'groceries',
  'coffee',
  'transport',
  'fuel',
  'travel',
  'rent',
  'home',
  'bills',
  'recharge',
  'subscriptions',
  'shopping',
  'personal-care',
  'health',
  'insurance',
  'education',
  'kids',
  'pets',
  'entertainment',
  'gifts',
  'emi',
  'investments',
  'other',
  'salary',
  'business',
  'freelance',
  'interest',
  'refund',
  'gift-received',
  'rental',
  'other-income',
  'lent',
  'borrowed',
  'goal-target',
  'goal-phone',
  'goal-bike',
  'goal-car',
  'goal-wedding',
  'goal-emergency',
] as const;

export const goalIcons = [
  'goal-target',
  'travel',
  'goal-phone',
  'goal-bike',
  'goal-car',
  'home',
  'goal-wedding',
  'goal-emergency',
  'education',
  'kids',
  'gifts',
  'freelance',
  'investments',
  'shopping',
  'health',
  'pets',
  'entertainment',
] as const satisfies readonly (typeof categoryIcons)[number][];

export type CategoryIconKey = (typeof categoryIcons)[number];

const defaultIcons: Record<string, CategoryIconKey> = {
  'expense:food': 'food',
  'expense:groceries': 'groceries',
  'expense:chai & coffee': 'coffee',
  'expense:transport': 'transport',
  'expense:fuel': 'fuel',
  'expense:travel': 'travel',
  'expense:rent': 'rent',
  'expense:home': 'home',
  'expense:bills': 'bills',
  'expense:recharge': 'recharge',
  'expense:subscriptions': 'subscriptions',
  'expense:shopping': 'shopping',
  'expense:personal care': 'personal-care',
  'expense:health': 'health',
  'expense:insurance': 'insurance',
  'expense:education': 'education',
  'expense:kids': 'kids',
  'expense:pets': 'pets',
  'expense:entertainment': 'entertainment',
  'expense:gifts': 'gifts',
  'expense:emi': 'emi',
  'expense:investments': 'investments',
  'expense:other': 'other',
  'income:salary': 'salary',
  'income:business': 'business',
  'income:freelance': 'freelance',
  'income:interest': 'interest',
  'income:refund': 'refund',
  'income:gift received': 'gift-received',
  'income:rental income': 'rental',
  'income:other income': 'other-income',
};

export function defaultIconFor(name: string, kind: string): CategoryIconKey | null {
  return defaultIcons[`${kind}:${name.trim().toLowerCase()}`] ?? null;
}

export function isCategoryIcon(value: unknown): value is CategoryIconKey {
  return typeof value === 'string' && (categoryIcons as readonly string[]).includes(value);
}

export function iconUrl(cloud: string | undefined, icon: string | null): string | null {
  if (!cloud || !isCategoryIcon(icon)) return null;
  return `https://res.cloudinary.com/${cloud}/image/upload/c_fit,w_160,h_160/f_png/${iconFolder}/${icon}`;
}
