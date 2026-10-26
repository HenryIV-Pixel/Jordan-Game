// Deterministic random numbers (mulberry32). The generator's state lives in the
// game state so a saved game replays identically.
import type { GameState } from './types';

export function nextRandom(state: GameState): number {
  let t = (state.rng = (state.rng + 0x6d2b79f5) | 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function chance(state: GameState, p: number): boolean {
  return nextRandom(state) < p;
}

export function pick<T>(state: GameState, items: readonly T[]): T {
  return items[Math.floor(nextRandom(state) * items.length)];
}

export function randInt(state: GameState, min: number, max: number): number {
  return min + Math.floor(nextRandom(state) * (max - min + 1));
}

/** A tiny standalone generator for setup code that runs before a state exists. */
export function seededRandom(seed: number): () => number {
  let a = seed | 0;
  return () => {
    let t = (a = (a + 0x6d2b79f5) | 0);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
