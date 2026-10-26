import { useState } from 'preact/hooks';
import { networkAction, networkActions } from '../../sim/actions';
import { TRAIT } from '../../sim/data';
import { opinionOf } from '../../sim/helpers';
import type { GameState, Person } from '../../sim/types';
import { Card, Portrait, signed } from '../components';
import { useApp, useGame } from '../store';

const W = 872, H = 760, CX = 436, CY = 380;
const GOLD = '#d4a94e', GREEN = '#6fbf8a', RED = '#e07a5f', BLUE = '#7fa3b3', GREY = '#6b7580';

const TIE_STYLE: Record<Person['tie'] | 'ally', { stroke: string; width: number; dash?: string; label: string; text: string }> = {
  patron: { stroke: GOLD, width: 2.5, dash: '7 5', label: 'راعٍ أو راعٍ محتمل', text: '#e8c47a' },
  boss: { stroke: BLUE, width: 2, label: 'رئيس في العمل', text: '#b9d3df' },
  friend: { stroke: GREEN, width: 2, label: 'صديق', text: '#8fd6a6' },
  family: { stroke: GREY, width: 1.6, label: 'قرابة', text: '#a3a9b1' },
  rival: { stroke: RED, width: 2.2, dash: '8 5', label: 'خصم', text: '#f0b3a3' },
  acquaintance: { stroke: '#4a5562', width: 1.4, label: 'معرفة', text: '#a3a9b1' },
  pending: { stroke: GOLD, width: 1.6, dash: '3 4', label: 'أمر معلّق', text: '#e8c47a' },
  ally: { stroke: '#5c6c78', width: 1.2, dash: '2 4', label: 'تحالف بين غيرك', text: '#8d98a2' },
};
const FILTERS: { label: string; test: (p: Person) => boolean }[] = [
  { label: 'الكل', test: () => true },
  { label: 'العائلة', test: (p) => p.tie === 'family' || p.id === 'patron' },
  { label: 'العمل', test: (p) => ['mayor', 'member1', 'member2', 'doctor', 'teacher', 'rival', 'police'].includes(p.id) },
  { label: 'الخصوم', test: (p) => p.tie === 'rival' || opinionOf(p) < 0 },
];

function layout(g: GameState, visible: Person[]) {
  const pos: Record<string, [number, number]> = { me: [CX, CY] };
  for (const ring of [1, 2] as const) {
    const ppl = visible.filter((p) => p.ring === ring);
    const r = ring === 1 ? 165 : 300;
    const off = ring === 1 ? -Math.PI / 2 : -Math.PI / 2 + Math.PI / Math.max(ppl.length, 1);
    ppl.forEach((p, i) => {
      const a = off + (i * 2 * Math.PI) / ppl.length;
      pos[p.id] = [CX + r * Math.cos(a) * 1.15, CY + r * Math.sin(a) * 0.95];
    });
  }
  void g;
  return pos;
}

function edgeLabel(g: GameState, p: Person): string {
  if (g.player.favorsIOwe.some((f) => f.personId === p.id)) return 'عليك فضل';
  if (g.player.favorsOwedToMe.some((f) => f.personId === p.id)) return 'لك فضل';
  if (p.tie === 'boss') return 'رئيسك';
  if (p.tie === 'rival') return 'خصم';
  if (p.tie === 'pending') return 'ينتظر ردّك';
  if (p.sponsor) return 'يدعمك';
  return '';
}

export function NetworkScreen() {
  const app = useApp();
  const g = useGame();
  const [filter, setFilter] = useState(0);
  const [selId, setSelId] = useState<string>(app.selected && g.people[app.selected] ? app.selected : 'mayor');
  const [query, setQuery] = useState('');
  const people = Object.values(g.people).filter((p) => !p.dead);
  const visible = people.filter(FILTERS[filter].test).filter((p) => !query || p.name.includes(query) || p.role.includes(query));
  const pos = layout(g, visible);
  const sel = g.people[selId] ?? people[0];
  const acts = networkActions(g, sel.id);
  const op = opinionOf(sel);

  const doAct = (id: Parameters<typeof networkAction>[2]) => {
    const r = app.act((s) => networkAction(s, sel.id, id));
    if (r) app.toast(r.message);
  };

  const edges: preact.JSX.Element[] = [];
  const shorten = (a: [number, number], b: [number, number], ra: number, rb: number) => {
    const dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
    return [a[0] + (dx / d) * (ra + 4), a[1] + (dy / d) * (ra + 4), b[0] - (dx / d) * (rb + 4), b[1] - (dy / d) * (rb + 4)];
  };
  for (const p of visible) {
    for (const ally of p.allies ?? []) {
      if (!pos[ally] || ally < p.id) continue;
      const [x1, y1, x2, y2] = shorten(pos[p.id], pos[ally], 30, 30);
      const st = TIE_STYLE.ally;
      edges.push(<line key={`a${p.id}${ally}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={st.stroke} stroke-width={st.width} stroke-dasharray={st.dash} />);
    }
  }
  for (const p of visible) {
    const st = TIE_STYLE[p.tie];
    const [x1, y1, x2, y2] = shorten(pos.me, pos[p.id], 40, 30);
    edges.push(<line key={`e${p.id}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={st.stroke} stroke-width={st.width} stroke-dasharray={st.dash} stroke-linecap="round" />);
    const label = edgeLabel(g, p);
    if (label) {
      // sit the label nearer the other person so it clears the centre node's name box
      const mx = x1 + (x2 - x1) * 0.64, my = y1 + (y2 - y1) * 0.64, w = 10 + label.length * 6.4;
      edges.push(<g key={`l${p.id}`}><rect x={mx - w / 2} y={my - 11} width={w} height="20" rx="10" fill="#13181e" stroke="#29323c" /><text x={mx} y={my + 3.5} text-anchor="middle" style={{ fontSize: '11px', fontFamily: 'var(--font)' }} fill={st.text}>{label}</text></g>);
    }
  }

  return (
    <div class="content">
      <aside class="col" style={{ width: '300px', flexShrink: 0 }} aria-label="عرض الشبكة">
        <Card title="عرض">
          <div class="tags">
            {FILTERS.map((f, i) => <button key={f.label} class={`btn sm ${filter === i ? 'goldish' : ''}`} aria-pressed={filter === i} onClick={() => setFilter(i)}>{f.label}</button>)}
          </div>
          <input class="inputbox" style={{ height: '38px', fontSize: '13px' }} placeholder="ابحث عن شخص…" aria-label="بحث عن شخص" value={query} onInput={(e) => setQuery((e.target as HTMLInputElement).value)} />
        </Card>
        <Card title="مفتاح الخطوط">
          <div class="col" style={{ gap: '9px', fontSize: '12.5px', color: 'var(--text-2)' }}>
            {(['patron', 'boss', 'friend', 'family', 'rival', 'acquaintance', 'ally'] as const).map((k) => (
              <span key={k} style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <svg viewBox="0 0 40 8" width="40" height="8" aria-hidden="true"><line x1="2" y1="4" x2="38" y2="4" stroke={TIE_STYLE[k].stroke} stroke-width={TIE_STYLE[k].width} stroke-dasharray={TIE_STYLE[k].dash} stroke-linecap="round" /></svg>{TIE_STYLE[k].label}
              </span>
            ))}
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px', borderTop: '1px solid var(--line)', paddingTop: '9px' }}><span class="tag green" style={{ borderRadius: '9px', fontWeight: 700 }}>+25</span>رأيه فيك، من −100 إلى +100</span>
          </div>
        </Card>
        <Card title="دفتر الأفضال" class="grow">
          <div class="col scroll" style={{ gap: '6px', fontSize: '13px' }}>
            <span class="muted" style={{ fontSize: '12px' }}>لك عند الآخرين ({g.player.favorsOwedToMe.length})</span>
            {g.player.favorsOwedToMe.map((f, i) => <span key={i} class="list-row"><span>{g.people[f.personId]?.name}</span><span style={{ color: 'var(--green-light)' }}>فضل {f.size === 'large' ? 'كبير' : 'صغير'}</span></span>)}
            <span class="muted" style={{ fontSize: '12px', paddingTop: '4px' }}>عليك للآخرين ({g.player.favorsIOwe.length})</span>
            {g.player.favorsIOwe.map((f, i) => <span key={i} class="list-row"><span>{g.people[f.personId]?.name}</span><span style={{ color: 'var(--red-light)' }}>فضل {f.size === 'large' ? 'كبير' : 'صغير'}</span></span>)}
          </div>
        </Card>
      </aside>

      <section style={{ width: '872px', flexShrink: 0, position: 'relative', background: '#13181e', border: '1px solid var(--line)', borderRadius: '12px', overflow: 'hidden' }} aria-label="شبكة العلاقات">
        <svg viewBox={`0 0 ${W} ${H}`} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} role="img" aria-label="شبكة علاقات بطلك">
          <defs><pattern id="netGrid" patternUnits="userSpaceOnUse" width="32" height="32"><path d="M32 0 H0 V32" fill="none" stroke="#1a2027" /></pattern></defs>
          <rect width={W} height={H} fill="url(#netGrid)" />
          <ellipse cx={CX} cy={CY} rx={165 * 1.15} ry={165 * 0.95} fill="none" stroke="#1f262e" stroke-width="1.5" stroke-dasharray="2 6" />
          <ellipse cx={CX} cy={CY} rx={300 * 1.15} ry={300 * 0.95} fill="none" stroke="#1f262e" stroke-width="1.5" stroke-dasharray="2 6" />
          {edges}
          {visible.map((p) => {
            const [x, y] = pos[p.id];
            const o = opinionOf(p);
            const ring = TIE_STYLE[p.tie].stroke;
            const isSel = p.id === sel.id;
            const above = y < CY - 60;
            const ny = above ? y - 30 - 28 : y + 30 + 18;
            const bx = x + 30 * 0.72, by = y + 30 * 0.72;
            return (
              <g key={p.id} style={{ cursor: 'pointer' }} onClick={() => setSelId(p.id)} role="button" tabIndex={0} aria-label={`${p.name}، ${p.role}، رأيه ${o}`} onKeyDown={(e) => { if (e.key === 'Enter') setSelId(p.id); }}>
                {isSel && <circle cx={x} cy={y} r="38" fill={GOLD} fill-opacity="0.12" stroke={GOLD} stroke-width="1.5" />}
                <circle cx={x} cy={y} r="30" fill="#222a33" stroke={ring} stroke-width="2.2" />
                <circle cx={x} cy={y - 6} r="9" fill={p.female ? '#7a6a80' : '#56626f'} />
                <path d={`M${x - 16} ${y + 18} Q${x - 15} ${y + 4} ${x} ${y + 4} Q${x + 15} ${y + 4} ${x + 16} ${y + 18} Z`} fill={p.female ? '#7a6a80' : '#56626f'} />
                <rect x={bx - 16} y={by - 9} width="32" height="18" rx="9" fill={o > 10 ? '#1f2f25' : o < 0 ? '#3a2623' : '#29323c'} stroke="#13181e" stroke-width="2" />
                <text x={bx} y={by + 4} text-anchor="middle" style={{ fontSize: '11px', fontWeight: 700, fontFamily: 'var(--font)' }} fill={o > 10 ? '#8fd6a6' : o < 0 ? '#f0b3a3' : '#c4ccd2'}>{signed(o)}</text>
                <text x={x} y={ny} text-anchor="middle" style={{ fontSize: '13px', fontWeight: 700, fontFamily: 'var(--font)' }} fill={isSel ? '#e8c47a' : '#ece6d8'}>{p.name}</text>
                <text x={x} y={ny + 16} text-anchor="middle" style={{ fontSize: '11px', fontFamily: 'var(--font)' }} fill="#a3a9b1">{p.role.length > 26 ? `${p.role.slice(0, 26)}…` : p.role}</text>
              </g>
            );
          })}
          <g>
            <circle cx={CX} cy={CY} r="40" fill="#222a33" stroke={GOLD} stroke-width="3" />
            <circle cx={CX} cy={CY - 8} r="12" fill="#7a6a4a" />
            <path d={`M${CX - 21} ${CY + 24} Q${CX - 20} ${CY + 5} ${CX} ${CY + 5} Q${CX + 20} ${CY + 5} ${CX + 21} ${CY + 24} Z`} fill="#7a6a4a" />
            <rect x={CX - 40} y={CY + 44} width="80" height="38" rx="8" fill="#13181e" stroke="#29323c" />
            <text x={CX} y={CY + 60} text-anchor="middle" style={{ fontSize: '14px', fontWeight: 700, fontFamily: 'var(--font)' }} fill="#e8c47a">{g.player.firstName}</text>
            <text x={CX} y={CY + 76} text-anchor="middle" style={{ fontSize: '11px', fontFamily: 'var(--font)' }} fill="#a3a9b1">أنت</text>
          </g>
        </svg>
        <span style={{ position: 'absolute', bottom: '12px', right: '14px', fontSize: '12px', color: 'var(--muted)' }}>الدائرة الداخلية: من يعرفك جيداً · الخارجية: معارف أبعد · نقاط الفعل هذا الأسبوع: <b style={{ color: 'var(--gold-light)' }}>{g.actionPoints}</b></span>
      </section>

      <aside class="card gold grow" style={{ padding: '16px', gap: '14px' }} aria-label="الشخص المحدّد">
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <Portrait silhouette female={sel.female} size={64} border={TIE_STYLE[sel.tie].stroke} />
          <div class="col" style={{ gap: '2px', minWidth: 0 }}>
            <span style={{ fontSize: '18px', fontWeight: 700 }}>{sel.name}</span>
            <span style={{ fontSize: '13px', color: 'var(--blue-light)', fontWeight: 600 }}>{sel.role}</span>
            <span class="muted" style={{ fontSize: '12px' }}>{sel.age} عاماً{sel.traits.length ? ` · ${sel.traits.map((t) => TRAIT[t].name).join('، ')}` : ''}</span>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '6px' }}>
          <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>رأيه فيك</span><b style={{ fontSize: '16px', color: op > 10 ? 'var(--green-light)' : op < 0 ? 'var(--red-light)' : 'var(--text-2)' }}>{signed(op)}</b></div>
          <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>نفوذه</span><b style={{ fontSize: '14px' }}>{{ weak: 'ضعيف', local: 'محلّي', strong: 'قوي' }[sel.influence]}</b></div>
          <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>يدعمك</span><b style={{ fontSize: '14px', color: sel.sponsor ? 'var(--green-light)' : 'var(--muted)' }}>{sel.sponsor ? 'نعم' : 'لا'}</b></div>
        </div>
        <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
          <span class="muted" style={{ fontSize: '12px' }}>لماذا هذا الرأي</span>
          {sel.opinion.slice(0, 5).map((m, i) => <span key={i} style={{ display: 'flex', justifyContent: 'space-between' }}><span>{m.reason}</span><span style={{ color: m.value >= 0 ? 'var(--green-light)' : 'var(--red-light)' }}>{signed(Math.round(m.value))}</span></span>)}
        </div>
        {(sel.wants || sel.known) && (
          <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
            {sel.wants && <><span class="muted" style={{ fontSize: '12px' }}>ما يريده الآن</span><span class="list-row" style={{ padding: '7px 10px' }}>{sel.wants}</span></>}
            {sel.known && <><span class="muted" style={{ fontSize: '12px' }}>ما تعرفه عنه</span><span class="list-row" style={{ padding: '7px 10px', color: g.player.filesHeld.includes(sel.id) ? 'var(--gold-light)' : 'var(--text-2)' }}>{sel.known}</span></>}
          </div>
        )}
        <div class="col" style={{ marginTop: 'auto', gap: '6px' }}>
          <span class="muted" style={{ fontSize: '12px' }}>أفعال · بقي {g.actionPoints} من 3 هذا الأسبوع</span>
          {acts.map((a) => (
            <button key={a.id} class="btn" disabled={!!a.locked} title={a.locked} onClick={() => doAct(a.id)} style={{ height: '44px', justifyContent: 'space-between', textAlign: 'start' }}>
              <span>{a.label}</span>
              <span style={{ fontSize: '11.5px', color: a.locked ? 'var(--faint)' : a.tone === 'green' ? 'var(--green-light)' : a.tone === 'red' ? 'var(--red-light)' : 'var(--gold-light)' }}>{a.locked ?? a.hint}</span>
            </button>
          ))}
        </div>
      </aside>
    </div>
  );
}
