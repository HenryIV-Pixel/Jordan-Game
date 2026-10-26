import { useState } from 'preact/hooks';
import { formatDate } from '../../sim/calendar';
import { scandalLevel, shortName, OFFICE_LABEL } from '../../sim/helpers';
import { saveGame } from '../../sim/save';
import { endTurn } from '../../sim/turn';
import { Chip, Crown, Lock } from '../components';
import { useApp, useGame, type Tab } from '../store';
import { CharacterScreen } from './CharacterScreen';
import { EventModal } from './EventModal';
import { MapView } from './MapView';
import { MunicipalityScreen } from './MunicipalityScreen';
import { NetworkScreen } from './NetworkScreen';

function TopBar(props: { onMenu: () => void }) {
  const app = useApp();
  const g = useGame();
  const p = g.player;
  const net = p.income.reduce((a, l) => a + l.amount, 0);
  const sc = scandalLevel(p.scandal);
  const pending = g.events.length;

  const end = () => {
    const before = new Set(g.events.map((e) => e.eventId));
    const next = endTurn(g);
    app.setGame(next);
    const fresh = next.events.find((e) => !before.has(e.eventId));
    if (fresh) app.setOpenEvent(fresh.eventId);
    const news = next.inbox.filter((i) => i.week === next.week).length;
    app.toast(`${formatDate(next.week, false)}${news ? ` · ${news} رسالة جديدة` : ''}`);
  };

  return (
    <header class="topbar">
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', paddingInlineEnd: '14px', borderInlineEnd: '1px solid var(--line)', height: '36px' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: '#221e16', border: '1px solid var(--gold-line)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Crown /></div>
        <div class="col" style={{ gap: 0, lineHeight: 1.25 }}>
          <span style={{ fontSize: '15px', fontWeight: 700 }}>{formatDate(g.week)}</span>
          <span class="muted" style={{ fontSize: '12px' }}>الأسبوع {g.week} · المملكة الأردنية الهاشمية</span>
        </div>
      </div>
      <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
        <Chip label="الثروة" value={<>{Math.round(p.wealth)} د. <span style={{ fontSize: '12px', color: net >= 0 ? 'var(--green-light)' : 'var(--red-light)', fontWeight: 600 }}>{net >= 0 ? '+' : ''}{net}</span></>} title="الدخل الصافي الأسبوعي بجانب الرصيد" />
        <Chip label="السمعة" value={<>{Math.round(p.reputation.local)} <span class="muted" style={{ fontSize: '12px', fontWeight: 400 }}>/ 100</span></>} />
        <Chip label="أفضال مستحقّة" value={p.favorsOwedToMe.length} />
        <Chip label="ثقة القصر" value={p.reputation.palace === null ? 'غير معروف' : Math.round(p.reputation.palace)} color={p.reputation.palace === null ? 'var(--muted)' : 'var(--gold-light)'} />
        <div class="chip" title="خطر الفضيحة">
          <span class="label">خطر الفضيحة</span>
          <span style={{ display: 'flex', gap: '3px' }} aria-label={`${sc.level} من 5: ${sc.label}`}>
            {[1, 2, 3, 4, 5].map((i) => <span key={i} style={{ width: '8px', height: '14px', borderRadius: '2px', background: i <= sc.level ? sc.color : '#333d48' }} />)}
          </span>
        </div>
      </div>
      <div style={{ marginInlineStart: 'auto', display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span style={{ fontSize: '12.5px', color: 'var(--text-2)' }}>{shortName(g)} · {OFFICE_LABEL[p.office]}</span>
        <button class="btn icon" aria-label="القائمة: حفظ وتحميل" onClick={props.onMenu}>
          <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M5 7 h14 M5 12 h14 M5 17 h14" stroke="var(--text)" stroke-width="1.8" stroke-linecap="round" /></svg>
        </button>
        {pending > 0 && (
          <button class="btn goldish" style={{ height: '44px' }} onClick={() => app.setOpenEvent(g.events[0].eventId)}>
            قرارات معلّقة <span style={{ background: 'var(--gold)', color: '#15110a', borderRadius: '9px', padding: '0 7px', fontSize: '12px' }}>{pending}</span>
          </button>
        )}
        <button class="btn primary" onClick={end} disabled={!!g.gameOver}>إنهاء الأسبوع</button>
      </div>
    </header>
  );
}

const TABS: { id: Tab; label: string }[] = [
  { id: 'map', label: 'الخريطة' },
  { id: 'character', label: 'الشخصية' },
  { id: 'network', label: 'شبكة العلاقات' },
  { id: 'municipality', label: 'البلدية' },
];
const LOCKED = [
  { label: 'البرلمان', why: 'يُفتح حين تدخل البرلمان (المرحلة القادمة)' },
  { label: 'الاقتصاد', why: 'يُفتح بمنصب وزاري (المرحلة القادمة)' },
  { label: 'الأمن', why: 'يُفتح بوزارة الداخلية (المرحلة القادمة)' },
  { label: 'الجيش', why: 'يُفتح بوزارة الدفاع أو رئاسة الأركان (المرحلة القادمة)' },
  { label: 'الخارجية', why: 'يُفتح بوزارة الخارجية (المرحلة القادمة)' },
];

function NavBar() {
  const app = useApp();
  return (
    <nav class="navbar" aria-label="الشاشات">
      {TABS.map((t) => (
        <button key={t.id} aria-current={app.tab === t.id ? 'page' : undefined} onClick={() => app.setTab(t.id)}>{t.label}</button>
      ))}
      {LOCKED.map((l) => (
        <button key={l.label} disabled title={l.why} aria-label={`${l.label} — مقفل`}><Lock />{l.label}</button>
      ))}
    </nav>
  );
}

function GameMenu(props: { onClose: () => void }) {
  const app = useApp();
  const g = useGame();
  const [slot, setSlot] = useState(`لعبة ${g.player.firstName}`);
  return (
    <div class="modal-backdrop" onClick={props.onClose}>
      <div class="card" style={{ width: '420px', padding: '20px', gap: '12px' }} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label="القائمة">
        <div class="card-title"><span>القائمة</span><button class="btn sm" onClick={props.onClose} aria-label="إغلاق">✕</button></div>
        <label class="col" style={{ gap: '6px', fontSize: '12px', color: 'var(--muted)' }}>اسم الحفظ<input class="inputbox" value={slot} onInput={(e) => setSlot((e.target as HTMLInputElement).value)} /></label>
        <button class="btn primary" onClick={() => { app.toast(saveGame(g, slot.trim() || 'حفظ') ? 'تم الحفظ' : 'تعذّر الحفظ'); props.onClose(); }}>احفظ اللعبة</button>
        <button class="btn" style={{ height: '44px' }} onClick={() => { saveGame(g, 'autosave'); app.setGame(null); app.setScreen('menu'); }}>القائمة الرئيسية (مع حفظ تلقائي)</button>
      </div>
    </div>
  );
}

export function GameShell() {
  const app = useApp();
  const g = useGame();
  const [menu, setMenu] = useState(false);
  return (
    <>
      <TopBar onMenu={() => setMenu(true)} />
      {g.gameOver ? (
        <div class="content" style={{ alignItems: 'center', justifyContent: 'center' }}>
          <div class="card gold" style={{ width: '520px', padding: '28px', gap: '14px', alignItems: 'center', textAlign: 'center' }}>
            <h1 style={{ margin: 0, fontSize: '26px' }}>انتهت الحكاية</h1>
            <p style={{ margin: 0, color: 'var(--text-2)', lineHeight: 1.8 }}>{g.gameOver}</p>
            <button class="btn primary" onClick={() => { app.setGame(null); app.setScreen('menu'); }}>القائمة الرئيسية</button>
          </div>
        </div>
      ) : (
        <>
          {app.tab === 'map' && <MapView />}
          {app.tab === 'character' && <CharacterScreen />}
          {app.tab === 'network' && <NetworkScreen />}
          {app.tab === 'municipality' && <MunicipalityScreen />}
        </>
      )}
      <NavBar />
      {app.openEvent && g.events.some((e) => e.eventId === app.openEvent) && <EventModal eventId={app.openEvent} />}
      {menu && <GameMenu onClose={() => setMenu(false)} />}
    </>
  );
}
