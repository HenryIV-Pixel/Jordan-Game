import { describe, expect, it } from 'vitest';
import { deskAction, networkAction, networkActions } from '../src/sim/actions';
import { formatDate, weekOf } from '../src/sim/calendar';
import { BACKGROUNDS, MUNICIPALITIES } from '../src/sim/data';
import { EVENT_BY_ID, resolveEvent } from '../src/sim/events';
import { opinionOf } from '../src/sim/helpers';
import { createGame, type NewGameChoices } from '../src/sim/newGame';
import { availableActions } from '../src/sim/permits';
import { nextRandom } from '../src/sim/rng';
import { endTurn } from '../src/sim/turn';
import type { GameState } from '../src/sim/types';
import { STAT_KEYS } from '../src/sim/types';

const base: NewGameChoices = {
  background: 'tribal', municipalityId: 'salt', firstName: 'سليم', fatherName: 'ناصر', familyName: '', age: 24,
  traits: ['ambitious', 'patient', 'hotTempered'], portrait: { headwear: 0, face: 2, beard: 0, skin: 1 }, seed: 1234,
};

/** A crude automatic player: works the desk, lobbies, picks event options at random. */
function autoplay(s: GameState, weeks: number, pickRandom = true): GameState {
  for (let w = 0; w < weeks; w++) {
    for (const permit of [...s.municipality.permits]) {
      if (s.permitsLeft <= 0) break;
      const acts = availableActions(permit);
      deskAction(s, permit.id, pickRandom && nextRandom(s) < 0.2 ? acts[Math.floor(nextRandom(s) * acts.length)] : 'approve');
    }
    for (const id of Object.keys(s.people)) {
      const acts = networkActions(s, id).filter((a) => !a.locked);
      if (acts.length && s.actionPoints > 0) networkAction(s, id, acts[Math.floor(nextRandom(s) * acts.length)].id);
    }
    for (const ev of [...s.events]) {
      const def = EVENT_BY_ID[ev.eventId];
      const open = def.options.filter((o) => !o.requires?.(s, ev.vars));
      if (open.length) resolveEvent(s, ev.eventId, open[Math.floor(nextRandom(s) * open.length)].id);
    }
    s = endTurn(s);
    if (s.gameOver) break;
  }
  return s;
}

function checkInvariants(s: GameState) {
  const p = s.player;
  for (const k of STAT_KEYS) {
    expect(Number.isFinite(p.stats[k])).toBe(true);
    expect(p.stats[k]).toBeGreaterThanOrEqual(0);
    expect(p.stats[k]).toBeLessThanOrEqual(20);
  }
  for (const v of [p.wealth, p.health, p.stress, p.scandal, p.reputation.local]) expect(Number.isFinite(v)).toBe(true);
  for (const person of Object.values(s.people)) expect(Number.isFinite(opinionOf(person))).toBe(true);
  for (const e of s.events) expect(EVENT_BY_ID[e.eventId]).toBeDefined();
  expect(s.municipality.permits.length).toBeLessThanOrEqual(12);
}

describe('calendar', () => {
  it('starts on 2 May 1953', () => {
    expect(formatDate(1)).toBe('السبت 2 أيار 1953');
    expect(weekOf(1953, 5, 2)).toBe(1);
    expect(weekOf(1953, 5, 9)).toBe(2);
  });
});

describe('new game', () => {
  it('builds a valid opening state for every background and town', () => {
    for (const bg of BACKGROUNDS) {
      for (const m of MUNICIPALITIES) {
        const s = createGame({ ...base, background: bg.id, municipalityId: m.id });
        checkInvariants(s);
        expect(s.municipality.permits.length).toBe(6);
        expect(s.player.office).toBe('clerk');
      }
    }
  });

  it('opens with the envelope decision and the news of the King', () => {
    const s = createGame(base);
    expect(s.events.map((e) => e.eventId)).toContain('envelope');
    expect(s.inbox.some((i) => i.title.includes('الملك'))).toBe(true);
  });
});

describe('turns', () => {
  it('is deterministic for the same seed and choices', () => {
    const a = autoplay(createGame(base), 60);
    const b = autoplay(createGame(base), 60);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
  });

  it('survives four simulated years without breaking any rule', () => {
    for (let seed = 1; seed <= 12; seed++) {
      const s = autoplay(createGame({ ...base, seed, background: BACKGROUNDS[seed % 5].id }), 210);
      checkInvariants(s);
      expect(s.week).toBeGreaterThan(19);
    }
  });

  it('resolves the water vote in week 4', () => {
    const s = autoplay(createGame(base), 5, false);
    expect(s.municipality.vote?.resolved).toBeDefined();
  });

  it('holds the council election when the player runs', () => {
    let won = 0, lost = 0;
    for (let seed = 1; seed <= 30; seed++) {
      let s = createGame({ ...base, seed });
      s.flags.running = true;
      s = autoplay(s, 20, false);
      if (s.player.office === 'councilMember') won++;
      else lost++;
    }
    // The election should be winnable but not certain.
    expect(won).toBeGreaterThan(0);
    expect(lost).toBeGreaterThan(0);
  });
});
