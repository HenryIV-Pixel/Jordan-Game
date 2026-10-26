import { useState } from 'preact/hooks';
import { formatDate } from '../../sim/calendar';
import { AUTOSAVE, deleteSave, listSaves, loadGame } from '../../sim/save';
import { Crown } from '../components';
import { JordanMap } from '../JordanMap';
import { useApp } from '../store';

export function MainMenu() {
  const app = useApp();
  const [showLoad, setShowLoad] = useState(false);
  const [saves, setSaves] = useState(listSaves());
  const auto = saves.find((s) => s.slot === AUTOSAVE);

  const open = (slot: string) => {
    const g = loadGame(slot);
    if (!g) { app.toast('تعذّر تحميل هذه اللعبة'); return; }
    app.setGame(g);
    app.setTab('map');
    app.setScreen('game');
  };

  return (
    <div style={{ position: 'relative', flex: 1, display: 'flex' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.35 }} aria-hidden="true"><JordanMap /></div>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(90deg, rgba(15,19,24,0.2) 0%, rgba(15,19,24,0.92) 55%)' }} aria-hidden="true" />
      <div style={{ position: 'relative', width: '520px', padding: '90px 80px', display: 'flex', flexDirection: 'column', gap: '28px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <div style={{ width: '64px', height: '64px', borderRadius: '14px', background: '#221e16', border: '1px solid var(--gold-line)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Crown size={40} /></div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <h1 style={{ margin: 0, fontSize: '48px', lineHeight: 1.1 }}>المملكة</h1>
            <span class="muted" style={{ fontSize: '16px' }}>من كاتب في البلدية إلى رئاسة الحكومة · 1953</span>
          </div>
        </div>
        {!showLoad ? (
          <div class="col" style={{ gap: '10px', maxWidth: '340px' }}>
            {auto && (
              <button class="btn primary" style={{ height: '52px', justifyContent: 'space-between' }} onClick={() => open(AUTOSAVE)}>
                <span>متابعة</span><span style={{ fontSize: '12.5px', fontWeight: 600 }}>{auto.name} · {formatDate(auto.week, false)}</span>
              </button>
            )}
            <button class={auto ? 'btn' : 'btn primary'} style={{ height: '52px', fontSize: '16px' }} onClick={() => app.setScreen('newgame')}>لعبة جديدة</button>
            <button class="btn" style={{ height: '52px', fontSize: '16px' }} onClick={() => { setSaves(listSaves()); setShowLoad(true); }} disabled={saves.length === 0}>تحميل لعبة</button>
            <button class="btn" style={{ height: '52px', fontSize: '16px' }} disabled title="المرحلة القادمة">الإعدادات</button>
          </div>
        ) : (
          <div class="card" style={{ maxWidth: '420px' }}>
            <div class="card-title"><span>الألعاب المحفوظة</span><span>{saves.length}</span></div>
            {saves.map((s) => (
              <div class="list-row" key={s.slot}>
                <span style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{ fontWeight: 600 }}>{s.slot === AUTOSAVE ? 'حفظ تلقائي' : s.slot} · {s.name}</span>
                  <span class="muted" style={{ fontSize: '12px' }}>{formatDate(s.week, false)}</span>
                </span>
                <span style={{ display: 'flex', gap: '6px' }}>
                  <button class="btn sm goldish" onClick={() => open(s.slot)}>تحميل</button>
                  <button class="btn sm" aria-label={`حذف ${s.slot}`} onClick={() => { deleteSave(s.slot); setSaves(listSaves()); }}>حذف</button>
                </span>
              </div>
            ))}
            <button class="btn" onClick={() => setShowLoad(false)}>رجوع</button>
          </div>
        )}
        <span class="faint" style={{ fontSize: '12px', marginTop: 'auto' }}>المرحلة الأولى · نسخة تجريبية</span>
      </div>
    </div>
  );
}
