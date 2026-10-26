// Small read/write helpers over the game state.
import { yearOf } from './calendar';
import { BASE_STATS, TRAIT } from './data';
import type { GameState, Person, StatKey } from './types';

export const clamp = (v: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, v));

export function opinionOf(p: Person): number {
  return clamp(Math.round(p.opinion.reduce((s, m) => s + m.value, 0)), -100, 100);
}

export function addOpinion(p: Person, value: number, reason: string, weeks?: number) {
  const existing = p.opinion.find((m) => m.reason === reason && m.weeks !== undefined && weeks !== undefined);
  if (existing) {
    existing.value += value;
    existing.weeks = Math.max(existing.weeks ?? 0, weeks ?? 0);
  } else {
    p.opinion.push({ reason, value, weeks });
  }
}

/** Effective stat = stored value (already includes background and trait mods). */
export function stat(state: GameState, k: StatKey): number {
  return state.player.stats[k];
}

export function statBreakdown(state: GameState, k: StatKey): { label: string; value: number }[] {
  const out: { label: string; value: number }[] = [];
  const p = state.player;
  out.push({ label: 'أساس', value: BASE_STATS[k] });
  const bgMod = (state.flags[`bgmod_${k}`] as number) || 0;
  if (bgMod) out.push({ label: 'العائلة', value: bgMod });
  for (const t of p.traits) {
    const m = TRAIT[t].statMods?.[k];
    if (m) out.push({ label: TRAIT[t].name, value: m });
  }
  const learned = p.stats[k] - out.reduce((s, x) => s + x.value, 0);
  if (learned) out.push({ label: 'الخبرة والأحداث', value: learned });
  return out;
}

export function gainXp(state: GameState, k: StatKey, amount: number) {
  const p = state.player;
  p.xp[k] += amount;
  while (p.xp[k] >= 100) {
    p.xp[k] -= 100;
    p.stats[k] = clamp(p.stats[k] + 1, 0, 20);
    log(state, `تحسّنت ${statName(k)} إلى ${p.stats[k]}.`);
  }
  while (p.xp[k] < 0) {
    p.xp[k] += 100;
    p.stats[k] = clamp(p.stats[k] - 1, 0, 20);
  }
}

function statName(k: StatKey) {
  return { charisma: 'الكاريزما', intrigue: 'الدهاء', administration: 'الإدارة', diplomacy: 'الدبلوماسية', integrity: 'النزاهة' }[k];
}

export function log(state: GameState, text: string, important = false) {
  state.log.unshift({ week: state.week, text, important });
  if (state.log.length > 300) state.log.length = 300;
}

export function inbox(state: GameState, kind: 'letter' | 'report' | 'news' | 'result', title: string, body: string) {
  state.inbox.unshift({ id: `in${state.week}_${state.inbox.length}_${Math.floor(state.rng % 9973)}`, week: state.week, kind, title, body });
  if (state.inbox.length > 60) state.inbox.length = 60;
}

export function age(state: GameState): number {
  // Birthdays are treated as 1 January for simplicity.
  return yearOf(state.week) - state.player.birthYear;
}

export function fullName(state: GameState): string {
  const p = state.player;
  return [p.firstName, p.fatherName, p.familyName].filter(Boolean).join(' ');
}

export function shortName(state: GameState): string {
  const p = state.player;
  return `${p.firstName} ${p.fatherName}`;
}

export function hasTrait(state: GameState, t: string): boolean {
  return state.player.traits.includes(t as never);
}

export function scandalLevel(scandal: number): { level: number; label: string; color: string } {
  const level = scandal < 15 ? 1 : scandal < 35 ? 2 : scandal < 55 ? 3 : scandal < 75 ? 4 : 5;
  const label = ['منخفض', 'منخفض', 'متوسط', 'مرتفع', 'خطير', 'وشيك'][level];
  const color = level <= 1 ? '#6fbf8a' : level === 2 ? '#d4a94e' : '#e07a5f';
  return { level, label, color };
}

export const OFFICE_LABEL: Record<string, string> = {
  unemployed: 'بلا عمل',
  clerk: 'كاتب',
  councilMember: 'عضو المجلس البلدي',
  mayor: 'رئيس البلدية',
};
