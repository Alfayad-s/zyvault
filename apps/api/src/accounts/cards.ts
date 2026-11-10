export type CardMove = {
  id?: string;
  amount: number;
  effect: 'spend' | 'payment' | null;
  accountId: string;
  cardId: string | null;
};

export type CardPosition = {
  limit: number;
  used: number;
  available: number;
};

/** Used is card spending minus bill payments, and it never goes below zero. */
export function cardPosition(
  limit: number,
  cardId: string,
  rows: CardMove[],
  exceptId?: string,
): CardPosition {
  let used = 0;
  for (const row of rows) {
    if (exceptId && row.id === exceptId) continue;
    if (row.effect === 'spend' && row.accountId === cardId) used += row.amount;
    else if (row.effect === 'payment' && row.cardId === cardId) used -= row.amount;
  }
  if (used < 0) used = 0;
  return { limit, used, available: Math.max(0, limit - used) };
}

/** The next due date on or after today. Days are 1–28 so every month has one. */
export function nextDueDate(dueDay: number | null, today: string): string | null {
  if (dueDay == null) return null;
  const [year, month, day] = today.split('-').map(Number);
  let dueYear = year;
  let dueMonth = month;
  if (day > dueDay) {
    dueMonth += 1;
    if (dueMonth > 12) {
      dueMonth = 1;
      dueYear += 1;
    }
  }
  return `${dueYear}-${String(dueMonth).padStart(2, '0')}-${String(dueDay).padStart(2, '0')}`;
}
