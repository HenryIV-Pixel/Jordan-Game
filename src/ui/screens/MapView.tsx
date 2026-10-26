import { formatDate, weeksLabel } from '../../sim/calendar';
import { FACTION_LABEL, ISSUE_LABEL, MUNICIPALITY, STAT_SHORT, TRAIT } from '../../sim/data';
import { EVENT_BY_ID } from '../../sim/events';
import { age, OFFICE_LABEL, shortName } from '../../sim/helpers';
import type { FactionKey, GameState, IssueKey } from '../../sim/types';
import { FACTION_KEYS, STAT_KEYS } from '../../sim/types';
import { Bar, Card, Check, Circle, Portrait } from '../components';
import { JordanMap } from '../JordanMap';
import { useApp, useGame } from '../store';

export function ambition(g: GameState): { title: string; items: { text: string; done: boolean }[]; footer?: [string, string] } {
  const p = g.player;
  const m = g.municipality;
  if (p.office === 'clerk' || p.office === 'unemployed') {
    const sponsor = Object.values(g.people).find((x) => x.sponsor);
    return {
      title: 'مقعد في المجلس البلدي',
      items: [
        { text: 'من أهالي البلدية', done: true },
        { text: 'سمعة محلية 30 فأكثر', done: p.reputation.local >= 30 },
        { text: sponsor ? `داعم: ${sponsor.name}` : 'تأييد وجيه أو راعٍ (رأيه فيك +50)', done: !!sponsor },
      ],
      footer: g.week <= m.electionWeek ? ['الانتخابات البلدية', weeksLabel(m.electionWeek - g.week)] : undefined,
    };
  }
  return {
    title: 'رئاسة البلدية',
    items: [
      { text: 'عضو في المجلس البلدي', done: true },
      { text: 'رأي المتصرّف فيك جيد', done: false },
      { text: 'دعم أغلبية المجلس', done: false },
    ],
    footer: ['المرحلة القادمة', 'قريباً'],
  };
}

function issueColor(v: number) {
  return v >= 70 ? 'var(--red)' : v >= 40 ? 'var(--gold)' : 'var(--green)';
}
function issueWord(k: IssueKey, v: number) {
  if (k === 'security') return v >= 60 ? 'متوتّر' : v >= 35 ? 'حذِر' : 'هادئ';
  return v >= 75 ? 'حرجة' : v >= 55 ? 'متوسّطة' : v >= 35 ? 'مقبولة' : 'جيدة';
}

export function MapView() {
  const app = useApp();
  const g = useGame();
  const p = g.player;
  const m = g.municipality;
  const amb = ambition(g);
  const sel = app.selected && MUNICIPALITY[app.selected] ? app.selected : m.id;
  const selDef = MUNICIPALITY[sel];
  const top = g.events[0];
  const topDef = top ? EVENT_BY_ID[top.eventId] : null;
  const moodColor = (v: number) => (v >= 60 ? 'var(--green)' : v >= 40 ? 'var(--gold)' : 'var(--red)');

  return (
    <div class="content">
      <section class="col" style={{ width: '324px', flexShrink: 0 }} aria-label="ملف الشخصية">
        <Card>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <Portrait p={p.portrait} size={76} />
            <div class="col" style={{ gap: '3px', minWidth: 0 }}>
              <span style={{ fontSize: '19px', fontWeight: 700 }}>{shortName(g)}</span>
              <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--gold)' }}>{OFFICE_LABEL[p.office]} · بلدية {m.name}</span>
              <span class="muted" style={{ fontSize: '12px' }}>{age(g)} عاماً</span>
              <span class="tags">{p.traits.map((t) => <span key={t} class={`tag ${TRAIT[t].tone === 'bad' ? 'red' : 'blue'}`}>{TRAIT[t].name}</span>)}</span>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '4px' }}>
            {STAT_KEYS.map((k) => (
              <div key={k} style={{ background: 'var(--raised)', borderRadius: '8px', padding: '6px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <span style={{ fontSize: '17px', fontWeight: 700 }}>{p.stats[k]}</span>
                <span class="muted" style={{ fontSize: '11px' }}>{STAT_SHORT[k]}</span>
              </div>
            ))}
          </div>
        </Card>
        <Card title={`الطموح: ${amb.title}`} right={`${amb.items.filter((i) => i.done).length} من ${amb.items.length}`}>
          <div class="col" style={{ gap: '7px', fontSize: '13px' }}>
            {amb.items.map((i) => <span key={i.text} style={{ display: 'flex', gap: '8px', alignItems: 'center', color: i.done ? 'var(--text)' : 'var(--muted)' }}>{i.done ? <Check /> : <Circle />}{i.text}</span>)}
          </div>
          {amb.footer && <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'var(--muted)', borderTop: '1px solid var(--line)', paddingTop: '8px' }}><span>{amb.footer[0]}</span><b style={{ color: 'var(--text)', fontWeight: 600 }}>{amb.footer[1]}</b></div>}
        </Card>
        <Card title={`مزاج الفئات في ${m.name}`} class="grow" right={<a href="#" onClick={(e) => { e.preventDefault(); app.setTab('municipality'); }}>التفاصيل</a>}>
          <div style={{ display: 'grid', gridTemplateColumns: '98px 1fr 22px', gap: '9px 8px', alignItems: 'center', fontSize: '13px' }}>
            {FACTION_KEYS.map((k: FactionKey) => [
              <span key={`${k}a`}>{FACTION_LABEL[k]}</span>,
              <Bar key={`${k}b`} value={m.mood[k]} color={moodColor(m.mood[k])} />,
              <span key={`${k}c`} class="muted" style={{ textAlign: 'end' }}>{Math.round(m.mood[k])}</span>,
            ])}
          </div>
        </Card>
      </section>

      <section style={{ width: '872px', flexShrink: 0, position: 'relative', background: 'var(--sea)', border: '1px solid var(--line)', borderRadius: '12px', overflow: 'hidden' }} aria-label="الخريطة">
        <JordanMap home={m.id} selected={sel} selectable={Object.keys(MUNICIPALITY)} onSelect={(id) => app.setSelected(id)} />
        <div style={{ position: 'absolute', top: '12px', right: '12px', display: 'flex', gap: '4px', background: 'rgba(20,25,32,0.94)', border: '1px solid var(--line-2)', borderRadius: '10px', padding: '4px' }}>
          <button class="btn sm" style={{ background: 'var(--gold)', color: '#15110a', border: 'none', fontWeight: 700 }}>سياسي</button>
          {['السكان', 'الاقتصاد', 'الولاء', 'الأمن', 'التضاريس'].map((x) => <button key={x} class="btn sm" disabled title="المرحلة القادمة" style={{ background: 'transparent', border: 'none' }}>{x}</button>)}
        </div>
        <div style={{ position: 'absolute', top: '330px', left: '640px', width: '220px', background: 'rgba(20,25,32,0.96)', border: '1px solid var(--gold-line)', borderRadius: '10px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}><span style={{ fontSize: '15px', fontWeight: 700, color: 'var(--gold-light)' }}>بلدية {selDef.name}</span><span class="muted" style={{ fontSize: '11px' }}>{selDef.district}</span></div>
          {sel === m.id ? (
            <div class="col" style={{ gap: '5px', fontSize: '12px' }}>
              <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">رئيس البلدية</span><span>{g.people.mayor.name}</span></span>
              {(['water', 'security', 'refugees'] as IssueKey[]).map((k) => (
                <span key={k} style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">{ISSUE_LABEL[k]}</span><span style={{ color: issueColor(m.issues[k]) }}>{issueWord(k, m.issues[k])}</span></span>
              ))}
              <a href="#" style={{ fontSize: '12px', fontWeight: 600 }} onClick={(e) => { e.preventDefault(); app.setTab('municipality'); }}>فتح ملف البلدية ←</a>
            </div>
          ) : (
            <div class="col" style={{ gap: '5px', fontSize: '12px' }}>
              <span style={{ color: 'var(--text-2)' }}>{selDef.character}</span>
              <span class="muted">لا نفوذ لك هنا بعد. ستفتح المدن الأخرى مع المناصب الأعلى.</span>
            </div>
          )}
        </div>
        <div style={{ position: 'absolute', bottom: '12px', right: '12px', display: 'flex', gap: '14px', alignItems: 'center', background: 'rgba(20,25,32,0.94)', border: '1px solid var(--line-2)', borderRadius: '10px', padding: '8px 12px', fontSize: '12px', color: 'var(--text-2)' }}>
          <span style={{ display: 'flex', gap: '6px', alignItems: 'center' }}><span style={{ width: '16px', borderTop: '2px solid #9cc0cf' }} />حدود المملكة</span>
          <span style={{ display: 'flex', gap: '6px', alignItems: 'center' }}><span style={{ width: '14px', height: '10px', borderRadius: '2px', background: 'repeating-linear-gradient(45deg, #2a4350 0 3px, #4d6b79 3px 5px)' }} />الضفة الغربية</span>
          <span style={{ display: 'flex', gap: '6px', alignItems: 'center' }}><span style={{ width: '16px', borderTop: '1px dashed #6f8a98' }} />حدود الألوية</span>
          <span style={{ display: 'flex', gap: '6px', alignItems: 'center' }}><span style={{ width: '16px', borderTop: '2px dashed #b9a27a' }} />سكة الحجاز</span>
          <span style={{ display: 'flex', gap: '6px', alignItems: 'center', borderInlineStart: '1px solid var(--line-2)', paddingInlineStart: '12px' }}><span style={{ width: '74px', height: '4px', border: '1px solid #c4ccd2', borderTop: 'none' }} />50 كم</span>
        </div>
      </section>

      <section class="col grow" aria-label="أحداث الأسبوع">
        {top && topDef ? (
          <Card gold>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span class="tag" style={{ background: 'var(--gold)', color: '#15110a', fontWeight: 700 }}>قرار مطلوب</span>
              <span class="muted" style={{ fontSize: '12px' }}>يُحسَم تلقائياً {weeksLabel(top.deadline - g.week)}</span>
            </div>
            <h2 style={{ margin: 0, fontSize: '19px' }}>{topDef.title}</h2>
            <p style={{ margin: 0, fontSize: '13.5px', lineHeight: 1.75, color: 'var(--text-2)', display: '-webkit-box', WebkitLineClamp: 4, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
              {topDef.text(g, top.vars).replace(/\{name:(\w+)\}/g, (_, id) => g.people[id]?.name ?? '')}
            </p>
            <button class="btn primary" onClick={() => app.setOpenEvent(top.eventId)}>افتح القرار</button>
            {g.events.length > 1 && <span class="muted" style={{ fontSize: '12px' }}>و{g.events.length - 1} {g.events.length === 2 ? 'قرار آخر' : 'قرارات أخرى'} بانتظارك</span>}
          </Card>
        ) : (
          <Card title="لا قرارات معلّقة">
            <span class="muted" style={{ fontSize: '13px', lineHeight: 1.7 }}>أنجز طلبات المكتب، وقوِّ علاقاتك، ثم أنهِ الأسبوع.</span>
          </Card>
        )}
        <Card title="بريد الأسبوع" class="grow" right={`${g.inbox.length}`}>
          <div class="col scroll" style={{ gap: '6px' }}>
            {g.inbox.slice(0, 12).map((i) => (
              <div key={i.id} style={{ display: 'flex', gap: '10px', alignItems: 'flex-start', borderRadius: '8px', padding: '8px', background: i.week === g.week ? '#222a33' : 'var(--raised)' }}>
                <span style={{ width: '32px', height: '32px', flexShrink: 0, borderRadius: '8px', background: 'var(--blue-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '15px' }} aria-hidden="true">
                  <svg viewBox="0 0 24 24" width="17" height="17">{i.kind === 'news'
                    ? <path d="M5 4 H19 V20 H5 Z M8 8 H16 M8 12 H16 M8 16 H13" fill="none" stroke="var(--blue-light)" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round" />
                    : i.kind === 'result' ? <path d="M12 3 L19 6 V11 C19 15.5 16 19 12 21 C8 19 5 15.5 5 11 V6 Z" fill="none" stroke="var(--blue-light)" stroke-width="1.6" />
                    : <g><rect x="3" y="6" width="18" height="13" rx="2" fill="none" stroke="var(--blue-light)" stroke-width="1.6" /><path d="M3 7.5 L12 13 L21 7.5" fill="none" stroke="var(--blue-light)" stroke-width="1.6" /></g>}</svg>
                </span>
                <span class="col" style={{ gap: '2px', minWidth: 0 }}>
                  <span style={{ fontSize: '13.5px', fontWeight: 600 }}>{i.title}</span>
                  <span class="muted" style={{ fontSize: '12px', lineHeight: 1.6 }}>{i.body}</span>
                  <span class="faint" style={{ fontSize: '11px' }}>{formatDate(i.week, false)}</span>
                </span>
              </div>
            ))}
            {g.inbox.length === 0 && <span class="muted" style={{ fontSize: '13px' }}>لا رسائل بعد.</span>}
          </div>
        </Card>
      </section>
    </div>
  );
}
