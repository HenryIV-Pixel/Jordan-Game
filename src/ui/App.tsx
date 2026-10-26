import { useEffect, useMemo, useRef, useState } from 'preact/hooks';
import { AUTOSAVE, saveGame } from '../sim/save';
import type { GameState } from '../sim/types';
import { GameShell } from './screens/GameShell';
import { MainMenu } from './screens/MainMenu';
import { NewGame } from './screens/NewGame';
import { Ctx, type AppCtx, type Screen, type Tab } from './store';

/** Scale the fixed 1600x900 stage to the window. */
function useStageScale() {
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const fit = () => setScale(Math.min(window.innerWidth / 1600, window.innerHeight / 900));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);
  return scale;
}

export function App() {
  const scale = useStageScale();
  const [screen, setScreen] = useState<Screen>('menu');
  const [game, setGameState] = useState<GameState | null>(null);
  const [tab, setTab] = useState<Tab>('map');
  const [toastMsg, setToastMsg] = useState<string | null>(null);
  const [openEvent, setOpenEvent] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const gameRef = useRef<GameState | null>(null);
  const toastTimer = useRef<number | undefined>(undefined);

  const setGame = (g: GameState | null) => {
    gameRef.current = g;
    setGameState(g);
  };

  // Autosave whenever a new week starts.
  useEffect(() => {
    if (game) saveGame(game, AUTOSAVE);
  }, [game?.week]);

  const ctx: AppCtx = useMemo(() => ({
    screen, setScreen, game, setGame, tab, setTab, openEvent, setOpenEvent, selected, setSelected,
    act: <T,>(fn: (g: GameState) => T) => {
      const current = gameRef.current;
      if (!current) return undefined;
      const next = structuredClone(current);
      const result = fn(next);
      setGame(next);
      return result;
    },
    toast: (msg: string) => {
      setToastMsg(msg);
      window.clearTimeout(toastTimer.current);
      toastTimer.current = window.setTimeout(() => setToastMsg(null), 3200);
    },
  }), [screen, game, tab, openEvent, selected]);

  return (
    <Ctx.Provider value={ctx}>
      <div class="viewport">
        <div class="stage" style={{ transform: `scale(${scale})` }} dir="rtl" lang="ar">
          {screen === 'menu' && <MainMenu />}
          {screen === 'newgame' && <NewGame />}
          {screen === 'game' && game && <GameShell />}
          {toastMsg && <div class="toast" role="status">{toastMsg}</div>}
        </div>
      </div>
    </Ctx.Provider>
  );
}
