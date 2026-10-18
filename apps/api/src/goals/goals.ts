export type Goal = {
  id: string;
  name: string;
  icon: string | null;
  iconUrl: string | null;
  targetAmount: number;
  targetDate: string | null;
  saved: number;
  createdAt: string;
};

export type GoalEntry = {
  id: string;
  goalId: string;
  amount: number;
  occurredOn: string;
  note: string | null;
};

export function missingGoalTables(error: { message: string } | null): boolean {
  return Boolean(
    error && /goal/.test(error.message) && /(does not exist|schema cache)/.test(error.message),
  );
}

export function savedByGoal(entries: { goal_id: string; amount: number }[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const entry of entries) {
    totals.set(entry.goal_id, (totals.get(entry.goal_id) ?? 0) + entry.amount);
  }
  return totals;
}

function words(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

/** Exact name first, then a goal whose name contains the words or is contained in them. */
export function matchGoal<T extends { name: string }>(name: string | null, goals: T[]): T | null {
  if (!name) return null;
  const wanted = words(name);
  if (!wanted) return null;
  return (
    goals.find((goal) => words(goal.name) === wanted) ??
    goals.find((goal) => words(goal.name).includes(wanted) || wanted.includes(words(goal.name))) ??
    null
  );
}
