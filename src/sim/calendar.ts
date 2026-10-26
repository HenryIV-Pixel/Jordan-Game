// Week 1 is Saturday 2 May 1953, the day King Hussein assumed his constitutional powers.
const START = Date.UTC(1953, 4, 2);
const DAY = 86_400_000;

export const MONTHS_AR = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
];
const DAYS_AR = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

export function weekToDate(week: number): Date {
  return new Date(START + (week - 1) * 7 * DAY);
}

export function formatDate(week: number, withDay = true): string {
  const d = weekToDate(week);
  const s = `${d.getUTCDate()} ${MONTHS_AR[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
  return withDay ? `${DAYS_AR[d.getUTCDay()]} ${s}` : s;
}

export function monthYear(week: number): string {
  const d = weekToDate(week);
  return `${MONTHS_AR[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

export function yearOf(week: number): number {
  return weekToDate(week).getUTCFullYear();
}

/** First week on or after a given calendar date. */
export function weekOf(year: number, month: number, day: number): number {
  const t = Date.UTC(year, month - 1, day);
  return Math.max(1, Math.ceil((t - START) / (7 * DAY)) + 1);
}

export function weeksLabel(n: number): string {
  if (n <= 0) return 'هذا الأسبوع';
  if (n === 1) return 'بعد أسبوع';
  if (n === 2) return 'بعد أسبوعين';
  if (n <= 10) return `بعد ${n} أسابيع`;
  return `بعد ${n} أسبوعاً`;
}

export function durationLabel(n: number): string {
  if (n === 1) return 'أسبوع';
  if (n === 2) return 'أسبوعان';
  if (n <= 10) return `${n} أسابيع`;
  return `${n} أسبوعاً`;
}
