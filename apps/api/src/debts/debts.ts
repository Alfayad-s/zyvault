export const debtTypes = ['lent', 'borrowed', 'got_back', 'paid_back'] as const;

export type DebtType = (typeof debtTypes)[number];

export type DebtEntry = {
  id: string;
  person: string;
  type: DebtType;
  amount: number;
  accountId: string | null;
  accountName: string | null;
  occurredOn: string;
  note: string | null;
};

export type Person = {
  name: string;
  /** Positive when they owe the user, negative when the user owes them. */
  balance: number;
  lastOn: string;
  entries: number;
};

export function missingDebtsTable(error: { message: string } | null): boolean {
  return Boolean(
    error && /debts/.test(error.message) && /(does not exist|schema cache)/.test(error.message),
  );
}

export function isDebtType(value: unknown): value is DebtType {
  return typeof value === 'string' && (debtTypes as readonly string[]).includes(value);
}

/** Money into (+) or out of (−) the user's account. */
export function accountEffect(type: DebtType, amount: number): number {
  return type === 'borrowed' || type === 'got_back' ? amount : -amount;
}

/** Change in what the person owes the user. */
export function owedEffect(type: DebtType, amount: number): number {
  return type === 'lent' || type === 'paid_back' ? amount : -amount;
}

export function personKey(name: string): string {
  return name.trim().replace(/\s+/g, ' ').toLowerCase();
}

export function peopleFrom(entries: DebtEntry[]): Person[] {
  const people = new Map<string, Person>();
  const byDate = [...entries].sort((a, b) => a.occurredOn.localeCompare(b.occurredOn));
  for (const entry of byDate) {
    const key = personKey(entry.person);
    const person = people.get(key) ?? { name: entry.person, balance: 0, lastOn: entry.occurredOn, entries: 0 };
    person.name = entry.person.trim();
    person.balance += owedEffect(entry.type, entry.amount);
    person.lastOn = entry.occurredOn;
    person.entries += 1;
    people.set(key, person);
  }
  return [...people.values()].sort(
    (a, b) =>
      Number(b.balance !== 0) - Number(a.balance !== 0) || b.lastOn.localeCompare(a.lastOn),
  );
}

export function debtLabel(type: DebtType, person: string): string {
  switch (type) {
    case 'lent':
      return `Lent to ${person}`;
    case 'borrowed':
      return `Borrowed from ${person}`;
    case 'got_back':
      return `${person} paid back`;
    case 'paid_back':
      return `Paid back ${person}`;
  }
}
