import { useState } from 'preact/hooks';
import { formatDate, weeksLabel } from '../../sim/calendar';
import { effectTags, fill } from '../../sim/effects';
import { EVENT_BY_ID, resolveEvent, type Illustration } from '../../sim/events';
import { opinionOf } from '../../sim/helpers';
import { PersonIcon, signed, Tags } from '../components';
import { useApp, useGame } from '../store';

/** Placeholder scene drawings until the final 1950s-style paintings exist. */
function Scene(props: { kind: Illustration }) {
  const k = props.kind;
  const warm = k === 'desk' || k === 'diwan' || k === 'home';
  const bg = warm ? '#1a1712' : k === 'protest' ? '#1c1414' : '#141b21';
  const ink = warm ? '#3a3122' : '#2c3a44';
  const hi = warm ? '#c9b07a' : k === 'protest' ? '#c0453a' : '#7fa3b3';
  return (
    <svg viewBox="0 0 380 800" width="380" height="800" preserveAspectRatio="xMidYMid slice" role="img" aria-label="رسم توضيحي مؤقت" style={{ position: 'absolute', inset: 0 }}>
      <rect width="380" height="800" fill={bg} />
      {k === 'desk' && (<g>
        <rect x="40" y="70" width="140" height="190" rx="4" fill="#221d15" stroke={ink} stroke-width="2" />
        <line x1="110" y1="70" x2="110" y2="260" stroke={ink} stroke-width="2" /><line x1="40" y1="165" x2="180" y2="165" stroke={ink} stroke-width="2" />
        <rect x="230" y="110" width="110" height="140" rx="3" fill="#2a2318" stroke="#4a3d27" stroke-width="2" />
        <path d="M0 470 L380 430 L380 800 L0 800 Z" fill="#2b2216" />
        <rect x="60" y="500" width="150" height="190" rx="3" transform="rotate(-8 135 595)" fill="#d9cfb8" opacity="0.85" />
        <rect x="200" y="540" width="140" height="86" rx="3" transform="rotate(6 270 583)" fill={hi} stroke="#8f7440" stroke-width="2" />
        <circle cx="300" cy="470" r="22" fill="#3a2f1f" stroke="#5a4a30" stroke-width="2" />
      </g>)}
      {k === 'diwan' && (<g>
        <path d="M0 520 L380 520 L380 800 L0 800 Z" fill="#2b2216" />
        <rect x="20" y="460" width="340" height="60" rx="6" fill="#5a2a22" />
        {[60, 140, 220, 300].map((x) => <circle key={x} cx={x} cy="420" r="26" fill="#3a3122" />)}
        {[60, 140, 220, 300].map((x) => <path key={x} d={`M${x - 36} 470 Q${x} 430 ${x + 36} 470 Z`} fill="#3a3122" />)}
        <path d="M170 600 L210 600 L200 660 L180 660 Z" fill={hi} />
        <path d="M120 120 Q190 40 260 120" fill="none" stroke={ink} stroke-width="3" />
      </g>)}
      {(k === 'street' || k === 'protest') && (<g>
        <path d="M0 300 L60 300 L60 200 L120 200 L120 260 L200 260 L200 160 L260 160 L260 280 L380 280 L380 800 L0 800 Z" fill={ink} />
        {[40, 140, 230, 320].map((x) => <rect key={x} x={x} y={320} width="30" height="40" fill={bg} opacity="0.6" />)}
        <path d="M0 600 L380 560 L380 800 L0 800 Z" fill={warm ? '#2b2216' : '#1d262d'} />
        {[50, 100, 150, 200, 250, 300].map((x, i) => <g key={x}><circle cx={x} cy={520 + (i % 2) * 14} r="14" fill="#0d1115" /><rect x={x - 14} y={534 + (i % 2) * 14} width="28" height="60" rx="10" fill="#0d1115" /></g>)}
        {k === 'protest' && <rect x="120" y="440" width="140" height="50" fill={hi} opacity="0.8" />}
      </g>)}
      {(k === 'news' || k === 'letter') && (<g>
        <rect x="50" y="170" width="280" height="380" rx="4" fill="#d9cfb8" transform="rotate(-4 190 360)" />
        <rect x="80" y="210" width="210" height="26" fill="#2a2116" transform="rotate(-4 190 360)" />
        {[260, 290, 320, 350, 380, 410, 440, 470].map((y) => <line key={y} x1="80" y1={y} x2="300" y2={y - 16} stroke="#8a7f6a" stroke-width="3" />)}
      </g>)}
      {k === 'council' && (<g>
        <rect x="30" y="420" width="320" height="40" rx="6" fill="#3a3122" />
        {[70, 150, 230, 310].map((x) => <g key={x}><circle cx={x} cy="370" r="22" fill={ink} /><path d={`M${x - 30} 420 Q${x} 385 ${x + 30} 420 Z`} fill={ink} /></g>)}
        <rect x="120" y="120" width="140" height="180" rx="4" fill="#221d15" stroke={hi} stroke-width="2" />
        <path d="M150 170 H230 M150 200 H230 M150 230 H200" stroke={hi} stroke-width="3" />
      </g>)}
      {k === 'home' && (<g>
        <rect x="60" y="140" width="120" height="160" rx="60" fill="#2c3a40" opacity="0.5" />
        <path d="M0 520 L380 520 L380 800 L0 800 Z" fill="#2b2216" />
        <rect x="70" y="480" width="240" height="30" rx="4" fill="#5a4a30" />
        <circle cx="130" cy="430" r="26" fill="#3a3122" /><circle cx="250" cy="430" r="26" fill="#3a3122" />
        <circle cx="190" cy="470" r="10" fill={hi} />
      </g>)}
    </svg>
  );
}

export function EventModal(props: { eventId: string }) {
  const app = useApp();
  const g = useGame();
  const active = g.events.find((e) => e.eventId === props.eventId)!;
  const def = EVENT_BY_ID[props.eventId];
  const [choice, setChoice] = useState<string | null>(null);
  const vars = active.vars;
  const left = active.deadline - g.week;
  const paragraphs = fill(def.text(g, vars), vars, g).split('\n\n');
  const involved = def.involved?.(g, vars) ?? [];
  const exposure = def.exposure?.(g, vars);
  const expLabel = exposure === 'high' ? ['مرتفع', 'var(--red-light)'] : exposure === 'medium' ? ['متوسط', 'var(--gold-light)'] : exposure === 'low' ? ['منخفض', 'var(--green-light)'] : null;
  const visibleOptions = def.options.filter((o) => o.id !== def.defaultOption || !o.requires);

  const confirm = () => {
    if (!choice) return;
    let message: string | undefined;
    let next: string | null = null;
    app.act((s) => {
      const r = resolveEvent(s, props.eventId, choice);
      message = r.ok ? r.message : r.message;
      next = s.events[0]?.eventId ?? null;
    });
    if (message) app.toast(message);
    app.setOpenEvent(next);
  };

  return (
    <div class="modal-backdrop">
      <div role="dialog" aria-modal="true" aria-labelledby="ev-title" style={{ width: '1080px', height: '800px', background: 'var(--panel)', border: '1px solid var(--gold-line)', borderRadius: '16px', overflow: 'hidden', display: 'flex', boxShadow: '0 24px 60px rgba(0,0,0,0.5)' }}>
        <div style={{ width: '380px', flexShrink: 0, position: 'relative', borderInlineEnd: '1px solid #2c2618' }}>
          <Scene kind={def.illustration} />
          <span style={{ position: 'absolute', bottom: '14px', insetInline: '16px', fontSize: '11.5px', color: '#8a7f6a', lineHeight: 1.5 }}>رسم مؤقت. الرسوم النهائية لوحات بأسلوب صور الخمسينيات.</span>
        </div>
        <div class="col grow" style={{ padding: '24px 28px', gap: '14px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span class="tags">{def.tags.map((t) => <span key={t.text} class={`tag ${t.tone}`} style={t.tone === 'gold' ? { background: 'var(--gold)', color: '#15110a', fontWeight: 700 } : undefined}>{t.text}</span>)}</span>
            <span style={{ fontSize: '12.5px', color: 'var(--text-2)' }}>يُحسَم تلقائياً {weeksLabel(left)}</span>
          </div>
          <div class="col" style={{ gap: '4px' }}>
            <h1 id="ev-title" style={{ margin: 0, fontSize: '30px', lineHeight: 1.3 }}>{def.title}</h1>
            <span class="muted" style={{ fontSize: '13px' }}>الأسبوع {active.firedWeek} · {formatDate(active.firedWeek)} · {g.municipality.name}</span>
          </div>
          <div class="col" style={{ gap: '10px', fontSize: '14.5px', lineHeight: 1.75, color: '#d6dbe0' }}>
            {paragraphs.map((t, i) => <p key={i} style={{ margin: 0 }}>{t}</p>)}
          </div>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', fontSize: '12.5px' }}>
            {involved.map((id) => g.people[id] && (
              <span key={id} style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'var(--raised)', borderRadius: '20px', padding: '4px 12px 4px 4px' }}>
                <PersonIcon size={26} />{g.people[id].name} <span style={{ color: 'var(--text-2)' }}>رأيه {signed(opinionOf(g.people[id]))}</span>
              </span>
            ))}
            {def.whoKnows && <span style={{ background: 'var(--raised)', borderRadius: '20px', padding: '4px 12px', color: 'var(--text-2)' }}>يعلم بالأمر: {def.whoKnows(g, vars)}</span>}
            {expLabel && <span style={{ background: 'var(--raised)', borderRadius: '20px', padding: '4px 12px', color: 'var(--text-2)' }}>خطر الانكشاف: <span style={{ color: expLabel[1] }}>{expLabel[0]}</span></span>}
          </div>
          <div class="col scroll" style={{ gap: '8px', marginTop: '4px' }} role="radiogroup" aria-label="الخيارات">
            {visibleOptions.map((o) => {
              const lock = o.requires?.(g, vars);
              const on = choice === o.id;
              const tags = effectTags(g, o.effects(g, vars), vars);
              const note = o.note?.(g);
              const risk = o.risk ? Math.round(o.risk.p(g) * 100) : null;
              if (lock) {
                return (
                  <button key={o.id} disabled title={lock} style={{ textAlign: 'start', background: '#14191e', border: '1px dashed var(--line-3)', borderRadius: '10px', padding: '12px 14px', color: 'var(--faint)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                    <span style={{ fontSize: '15px', fontWeight: 600 }}>{fill(o.text, vars, g)}</span>
                    <span style={{ fontSize: '12px' }}>{lock}</span>
                  </button>
                );
              }
              return (
                <button key={o.id} role="radio" aria-checked={on} onClick={() => setChoice(o.id)} onDblClick={() => { setChoice(o.id); }} style={{ textAlign: 'start', background: on ? 'var(--gold-bg)' : 'var(--raised)', border: on ? '2px solid var(--gold)' : '1px solid var(--line-3)', borderRadius: '10px', padding: on ? '11px 13px' : '12px 14px', color: 'var(--text)', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '16px' }}>
                  <span class="col" style={{ gap: '6px' }}>
                    <span style={{ fontSize: '15px', fontWeight: 700 }}>{fill(o.text, vars, g)}</span>
                    <Tags items={tags} />
                  </span>
                  <span style={{ fontSize: '12px', whiteSpace: 'nowrap', color: note?.includes('ضدّ') ? 'var(--red-light)' : 'var(--gold-light)' }}>
                    {risk !== null ? `فرصة النجاح ~${risk}%` : note ?? ''}
                  </span>
                </button>
              );
            })}
          </div>
          <div style={{ marginTop: 'auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--line)', paddingTop: '14px', gap: '12px' }}>
            <span class="muted" style={{ fontSize: '12.5px' }}>{def.defaultNote ?? 'إن لم تقرّر قبل انقضاء المهلة، يُختار عنك.'}</span>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button class="btn" style={{ height: '44px', padding: '0 18px' }} onClick={() => app.setOpenEvent(null)}>قرّر لاحقاً</button>
              <button class="btn primary" disabled={!choice} onClick={confirm}>تأكيد الاختيار</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
