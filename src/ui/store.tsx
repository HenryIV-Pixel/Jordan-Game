// App-wide state: which screen is showing, the running game, and toasts.
import { createContext } from 'preact';
import { useContext } from 'preact/hooks';
import type { GameState } from '../sim/types';

export type Screen = 'menu' | 'newgame' | 'game';
export type Tab = 'map' | 'character' | 'network' | 'municipality';

export interface AppCtx {
  screen: Screen;
  setScreen: (s: Screen) => void;
  game: GameState | null;
  /** Replace the game state. */
  setGame: (g: GameState | null) => void;
  /** Clone the game, let `fn` mutate the clone, then commit it. Returns fn's result. */
  act: <T>(fn: (g: GameState) => T) => T | undefined;
  tab: Tab;
  setTab: (t: Tab) => void;
  toast: (msg: string) => void;
  openEvent: string | null;
  setOpenEvent: (id: string | null) => void;
  selected: string | null;
  setSelected: (id: string | null) => void;
}

export const Ctx = createContext<AppCtx>(null as unknown as AppCtx);
export const useApp = () => useContext(Ctx);
export const useGame = () => {
  const ctx = useContext(Ctx);
  return ctx.game as GameState;
};
