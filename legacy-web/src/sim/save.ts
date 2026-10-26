// Save slots in browser storage (works the same inside the Tauri window).
import type { GameState } from './types';

const PREFIX = 'jordan-game:save:';
export const AUTOSAVE = 'autosave';

export interface SaveInfo { slot: string; week: number; name: string; savedAt: number }

export function saveGame(state: GameState, slot: string): boolean {
  try {
    const payload = JSON.stringify({ savedAt: Date.now(), state });
    localStorage.setItem(PREFIX + slot, payload);
    return true;
  } catch {
    return false;
  }
}

export function loadGame(slot: string): GameState | null {
  try {
    const raw = localStorage.getItem(PREFIX + slot);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { state: GameState };
    if (parsed.state?.version !== 1) return null;
    return parsed.state;
  } catch {
    return null;
  }
}

export function listSaves(): SaveInfo[] {
  const out: SaveInfo[] = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith(PREFIX)) continue;
      const raw = localStorage.getItem(key);
      if (!raw) continue;
      const parsed = JSON.parse(raw) as { savedAt: number; state: GameState };
      const p = parsed.state.player;
      out.push({ slot: key.slice(PREFIX.length), week: parsed.state.week, name: `${p.firstName} ${p.fatherName}`, savedAt: parsed.savedAt });
    }
  } catch {
    /* storage unavailable */
  }
  return out.sort((a, b) => b.savedAt - a.savedAt);
}

export function deleteSave(slot: string) {
  try { localStorage.removeItem(PREFIX + slot); } catch { /* ignore */ }
}
