export type SignedAmount = {
  amount: number;
  kind: 'income' | 'expense';
};

export type SummaryTransaction = SignedAmount & {
  categoryId: string;
  categoryName: string;
};

export type CategoryTotal = {
  categoryId: string;
  name: string;
  kind: 'income' | 'expense';
  total: number;
};

export type Summary = {
  balance: number;
  monthIncome: number;
  monthExpense: number;
  categories: CategoryTotal[];
};

function signed(transaction: SignedAmount): number {
  return transaction.kind === 'income'
    ? transaction.amount
    : -transaction.amount;
}

export function buildSummary(
  openingBalance: number,
  all: SignedAmount[],
  month: SummaryTransaction[],
): Summary {
  const balance = all.reduce((sum, transaction) => sum + signed(transaction), openingBalance);
  const monthIncome = month
    .filter((transaction) => transaction.kind === 'income')
    .reduce((sum, transaction) => sum + transaction.amount, 0);
  const monthExpense = month
    .filter((transaction) => transaction.kind === 'expense')
    .reduce((sum, transaction) => sum + transaction.amount, 0);

  const totals = new Map<string, CategoryTotal>();
  for (const transaction of month) {
    const key = `${transaction.categoryId}:${transaction.kind}`;
    const current = totals.get(key);
    if (current) {
      current.total += transaction.amount;
      continue;
    }
    totals.set(key, {
      categoryId: transaction.categoryId,
      name: transaction.categoryName,
      kind: transaction.kind,
      total: transaction.amount,
    });
  }

  return {
    balance,
    monthIncome,
    monthExpense,
    categories: [...totals.values()].sort((a, b) => b.total - a.total),
  };
}
