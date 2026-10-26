// Event engine: decides which events fire each week, and resolves the player's choice.
import { EVENTS } from './eventContent';
import type { Effect, Vars } from './effects';
import { applyEffects, fill } from './effects';
import { log } from './helpers';
import { chance, nextRandom } from './rng';
import type { GameState } from './types';

export type Illustration = 'desk' | 'diwan' | 'street' | 'letter' | 'news' | 'council' | 'home' | 'protest';

export interface EventOption {
  id: string;
  text: string;
  effects: (s: GameState, v: Vars) => Effect[];
  /** Returns a reason string when the option is locked. */
  requires?: (s: GameState, v: Vars) => string | null;
  /** Small note on the right of the option ("suits your nature"). */
  note?: (s: GameState) => string | null;
  /** A gamble: chance of success, and the effects on failure. */
  risk?: { p: (s: GameState) => number; fail: (s: GameState, v: Vars) => Effect[]; failText: string; successText?: string };
}

export interface EventDef {
  id: string;
  title: string;
  tags: { text: string; tone: 'gold' | 'blue' | 'red' | 'green' }[];
  illustration: Illustration;
  text: (s: GameState, v: Vars) => string;
  involved?: (s: GameState, v: Vars) => string[];
  whoKnows?: (s: GameState, v: Vars) => string;
  exposure?: (s: GameState, v: Vars) => 'low' | 'medium' | 'high';
  /** When the event may fire. */
  trigger: {
    week?: number;
    minWeek?: number;
    maxWeek?: number;
    chance?: number; // per week, once eligible
    when?: (s: GameState) => boolean;
    once?: boolean;
    cooldown?: number;
  };
  setup?: (s: GameState) => Vars | null;
  deadline: number; // weeks to decide
  defaultOption: string;
  defaultNote?: string;
  /** News-only events resolve immediately and only post to the inbox. */
  newsOnly?: boolean;
  options: EventOption[];
}

export const EVENT_BY_ID: Record<string, EventDef> = Object.fromEntries(EVENTS.map((e) => [e.id, e]));

function eligible(s: GameState, e: EventDef): boolean {
  const t = e.trigger;
  if (s.events.some((a) => a.eventId === e.id)) return false;
  if ((t.once ?? true) && s.firedOnce.includes(e.id)) return false;
  if (s.cooldowns[e.id] && s.cooldowns[e.id] > s.week) return false;
  const queued = s.flags[`queued_${e.id}`];
  if (typeof queued === 'number') return queued <= s.week;
  if (t.week !== undefined) return s.week === t.week && (!t.when || t.when(s));
  if (t.minWeek !== undefined && s.week < t.minWeek) return false;
  if (t.maxWeek !== undefined && s.week > t.maxWeek) return false;
  if (t.chance === undefined) return false;
  if (t.when && !t.when(s)) return false;
  return true;
}

/** Fire events for the current week. At most two new decisions per week. */
export function checkEvents(s: GameState) {
  let decisions = 0;
  for (const e of EVENTS) {
    if (!eligible(s, e)) continue;
    const queued = typeof s.flags[`queued_${e.id}`] === 'number';
    const scheduled = queued || e.trigger.week !== undefined;
    if (!scheduled && !chance(s, e.trigger.chance ?? 0)) continue;
    if (!e.newsOnly && !scheduled && decisions >= 2) continue;
    const vars = e.setup ? e.setup(s) : {};
    if (vars === null) continue;
    if (queued) delete s.flags[`queued_${e.id}`];
    fire(s, e, vars);
    if (!e.newsOnly) decisions++;
  }
}

export function fire(s: GameState, e: EventDef, vars: Vars = {}) {
  if (e.trigger.once ?? true) s.firedOnce.push(e.id);
  if (e.trigger.cooldown) s.cooldowns[e.id] = s.week + e.trigger.cooldown;
  if (e.newsOnly) {
    s.inbox.unshift({ id: `n${s.week}_${e.id}`, week: s.week, kind: 'news', title: e.title, body: e.text(s, vars) });
    const opt = e.options[0];
    if (opt) applyEffects(s, opt.effects(s, vars), vars);
    return;
  }
  s.events.push({ eventId: e.id, firedWeek: s.week, deadline: s.week + e.deadline, vars });
}

export interface ResolveResult {
  ok: boolean;
  message?: string;
}

export function resolveEvent(s: GameState, eventId: string, optionId: string, auto = false): ResolveResult {
  const idx = s.events.findIndex((a) => a.eventId === eventId);
  if (idx < 0) return { ok: false, message: 'الحدث غير موجود' };
  const active = s.events[idx];
  const def = EVENT_BY_ID[eventId];
  const opt = def.options.find((o) => o.id === optionId);
  if (!opt) return { ok: false, message: 'خيار غير معروف' };
  const lock = opt.requires?.(s, active.vars);
  if (lock && !auto) return { ok: false, message: lock };
  s.events.splice(idx, 1);
  let message: string | undefined;
  if (opt.risk) {
    const p = opt.risk.p(s);
    if (nextRandom(s) < p) {
      applyEffects(s, opt.effects(s, active.vars), active.vars);
      message = opt.risk.successText ? fill(opt.risk.successText, active.vars, s) : undefined;
    } else {
      applyEffects(s, opt.risk.fail(s, active.vars), active.vars);
      message = fill(opt.risk.failText, active.vars, s);
    }
  } else {
    applyEffects(s, opt.effects(s, active.vars), active.vars);
  }
  log(s, `${def.title}: ${fill(opt.text, active.vars, s)}${auto ? ' (انقضت المهلة)' : ''}`);
  if (message) log(s, message);
  return { ok: true, message };
}

/** Auto-resolve events whose deadline has passed. */
export function expireEvents(s: GameState) {
  for (const a of [...s.events]) {
    if (a.deadline <= s.week) {
      const def = EVENT_BY_ID[a.eventId];
      resolveEvent(s, a.eventId, def.defaultOption, true);
    }
  }
}
