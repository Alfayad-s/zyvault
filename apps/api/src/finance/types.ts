export type MoneyKind = 'income' | 'expense';
export type Certainty = 'confirmed' | 'estimated';

export type LedgerTxn = {
  id: string;
  amount: number;
  kind: MoneyKind;
  occurredOn: string;
  categoryId: string;
  categoryName: string;
  accountId: string;
  note: string | null;
  cardEffect?: 'spend' | 'payment' | null;
};

export type ScheduleItem = {
  id: string;
  amount: number;
  kind: MoneyKind;
  categoryName: string;
  note: string | null;
  repeat: 'once' | 'monthly';
  nextOn: string;
  dayOfMonth: number;
};

export type GoalItem = {
  id: string;
  name: string;
  targetAmount: number;
  saved: number;
  targetDate: string | null;
};

export type PersonBalance = {
  name: string;
  balance: number;
};

export type BudgetLimit = {
  categoryId: string;
  categoryName: string;
  limitAmount: number;
};

export type MonthTotals = {
  month: string;
  income: number;
  expense: number;
};

export type ProfileInput = {
  emergencyReserve: number;
  monthlyDiscretionaryLimit: number | null;
  essentialCategories: string[];
};

export const defaultEssentials = ['rent', 'bills', 'emi', 'insurance', 'recharge'];

export function essentialName(name: string, essentials: string[]): boolean {
  const key = name.trim().toLowerCase();
  return essentials.some((item) => item.trim().toLowerCase() === key);
}
