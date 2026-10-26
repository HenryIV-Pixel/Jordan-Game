import { useState } from 'preact/hooks';
import { formatDate, monthYear } from '../../sim/calendar';
import { BACKGROUNDS, MUNICIPALITY, STAT_GROWTH, STAT_LABEL, TRAIT } from '../../sim/data';
import { age, fullName, OFFICE_LABEL, opinionOf, statBreakdown } from '../../sim/helpers';
import { STAT_KEYS } from '../../sim/types';
import { Bar, Card, Portrait } from '../components';
import { useApp, useGame } from '../store';
import { ambition } from './MapView';

function TreeBox(props: { x: number; y: number; w: number; name: string; sub: string; me?: boolean; gold?: boolean }) {
  return (
    <div dir="rtl" style={{ position: 'absolute', left: `${props.x}px`, top: `${props.y}px`, width: `${props.w}px`, height: '40px', boxSizing: 'border-box', borderRadius: '8px', padding: '4px 10px', display: 'flex', flexDirection: 'column', justifyContent: 'center',
      background: props.me ? 'var(--gold-bg)' : props.gold ? '#221e16' : 'var(--raised)', border: props.me ? '2px solid var(--gold)' : props.gold ? '1px solid var(--gold-line)' : '1px solid var(--line-3)' }}>
      <span style={{ fontSize: '13px', fontWeight: props.me ? 700 : 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{props.name}</span>
      <span style={{ fontSize: '11px', color: props.me || props.gold ? 'var(--gold-light)' : 'var(--muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{props.sub}</span>
    </div>
  );
}

export function CharacterScreen() {
  const app = useApp();
  const g = useGame();
  const p = g.player;
  const pe = g.people;
  const [tab, setTab] = useState(0);
  const amb = ambition(g);
  const bg = BACKGROUNDS.find((b) => b.id === p.background)!;
  const net = p.income.reduce((a, l) => a + l.amount, 0);
  const line = { position: 'absolute', background: '#4a5562' } as const;

  const abilities = (
    <Card title="القدرات" right="الشريط: التقدّم نحو النقطة التالية">
      <div class="col" style={{ gap: '10px', fontSize: '13px' }}>
        {STAT_KEYS.map((k) => (
          <div key={k} style={{ display: 'grid', gridTemplateColumns: '82px 30px 1fr', gap: '10px', alignItems: 'center' }}>
            <span>{STAT_LABEL[k]}</span>
            <span style={{ fontSize: '17px', fontWeight: 700 }}>{p.stats[k]}</span>
            <span class="col" style={{ gap: '4px' }}>
              <Bar value={p.xp[k]} height={5} color={k === 'integrity' ? 'var(--green)' : 'var(--gold)'} />
              <span class="muted" style={{ fontSize: '11px' }}>{statBreakdown(g, k).map((b) => `${b.label} ${b.label === 'أساس' ? b.value : (b.value > 0 ? '+' : '') + b.value}`).join(' · ')} · {STAT_GROWTH[k]}</span>
            </span>
          </div>
        ))}
      </div>
    </Card>
  );

  const family = (
    <Card title="العائلة" right={<a href="#" onClick={(e) => { e.preventDefault(); app.setTab('network'); }}>في شبكة العلاقات</a>}>
      <div class="grow" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div dir="ltr" style={{ position: 'relative', width: '408px', height: '166px' }}>
          <TreeBox x={272} y={0} w={136} name={pe.patron.name} sub={pe.patron.role} gold />
          <span aria-hidden="true" style={{ position: 'absolute', left: '339px', top: '40px', height: '16px', borderLeft: '2px dashed var(--gold-line)' }} />
          <TreeBox x={272} y={56} w={136} name={`${pe.father.name} · الأب`} sub={`${pe.father.age + (g.week > 35 ? 1 : 0)} عاماً`} />
          <TreeBox x={120} y={56} w={136} name={`${pe.mother.name} · الأم`} sub={`رأيها فيك ${opinionOf(pe.mother)}`} />
          <span aria-hidden="true" style={{ ...line, left: '256px', top: '75px', width: '16px', height: '2px' }} />
          <span aria-hidden="true" style={{ ...line, left: '263px', top: '77px', width: '2px', height: '29px' }} />
          <span aria-hidden="true" style={{ ...line, left: '58px', top: '106px', width: '292px', height: '2px' }} />
          <span aria-hidden="true" style={{ ...line, left: '349px', top: '106px', width: '2px', height: '20px' }} />
          <span aria-hidden="true" style={{ ...line, left: '203px', top: '106px', width: '2px', height: '20px' }} />
          <span aria-hidden="true" style={{ ...line, left: '57px', top: '106px', width: '2px', height: '20px' }} />
          <TreeBox x={292} y={126} w={116} name={p.firstName} sub={`أنت · ${age(g)}`} me />
          <TreeBox x={146} y={126} w={116} name={pe.sister.name} sub={pe.sister.role.replace('الأخت · ', '')} />
          <TreeBox x={0} y={126} w={116} name={pe.brother.name} sub={pe.brother.role.replace('الأخ الأصغر · ', '')} />
        </div>
      </div>
      <div class="list-row" style={{ padding: '8px 12px' }}>
        <span style={{ color: 'var(--text-2)' }}>{p.married ? 'متزوّج · النسب يفتح أبواب الوجهاء' : 'لا زوجة بعد — الزواج تحالف بين عائلتين'}</span>
      </div>
    </Card>
  );

  const wealth = (
    <Card title="الثروة" right={<span>في اليد <b style={{ color: 'var(--text)' }}>{Math.round(p.wealth)} د.</b></span>}>
      <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
        <span class="muted" style={{ fontSize: '12px' }}>الدخل والنفقات الأسبوعية</span>
        {p.income.map((l) => <span key={l.label} style={{ display: 'flex', justifyContent: 'space-between' }}><span>{l.label}</span><span style={{ color: l.amount >= 0 ? 'var(--green-light)' : 'var(--red-light)' }}>{l.amount > 0 ? '+' : ''}{l.amount} د.</span></span>)}
        <span style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--line)', paddingTop: '6px', fontWeight: 700 }}><span>الصافي</span><span style={{ color: net >= 0 ? 'var(--green-light)' : 'var(--red-light)' }}>{net > 0 ? '+' : ''}{net} د. أسبوعياً</span></span>
      </div>
      <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
        <span class="muted" style={{ fontSize: '12px' }}>الأملاك</span>
        <span class="list-row"><span>أملاك العائلة</span><span class="muted">باسم الأب</span></span>
        <span class="list-row"><span>ديون</span><span class="muted">{p.wealth < 0 ? `${Math.round(-p.wealth)} د.` : 'لا شيء'}</span></span>
      </div>
    </Card>
  );

  const life = (
    <Card title="السيرة" right={`${g.log.length} حدثاً`}>
      <ol class="scroll" style={{ margin: 0, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', fontSize: '13px' }}>
        {[...g.log.filter((l) => l.important), ...(tab === 3 ? g.log.filter((l) => !l.important) : [])].slice(0, tab === 3 ? 200 : 6).map((l, i) => (
          <li key={i} style={{ display: 'grid', gridTemplateColumns: '92px 14px 1fr', gap: '8px', alignItems: 'start' }}>
            <span style={{ color: l.important ? 'var(--gold-light)' : 'var(--muted)', fontWeight: l.important ? 600 : 400 }}>{monthYear(l.week)}</span>
            <span aria-hidden="true" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', height: '100%' }}><span style={{ width: '10px', height: '10px', borderRadius: '5px', background: l.important ? 'var(--gold)' : '#6b7580', marginTop: '5px' }} /><span style={{ width: '2px', flex: 1, minHeight: '18px', background: 'var(--line-3)' }} /></span>
            <span style={{ paddingBottom: '10px' }}>{l.text}</span>
          </li>
        ))}
        <li style={{ display: 'grid', gridTemplateColumns: '92px 14px 1fr', gap: '8px' }}><span class="muted">{p.birthYear}</span><span aria-hidden="true" style={{ width: '10px', height: '10px', borderRadius: '5px', background: '#6b7580', marginTop: '5px' }} /><span>وُلد في {MUNICIPALITY[p.municipalityId].name} لعائلة {bg.short}.</span></li>
      </ol>
    </Card>
  );

  return (
    <div class="content">
      <section class="card" style={{ width: '340px', flexShrink: 0, padding: '18px', gap: '14px' }} aria-label="الهوية">
        <div style={{ alignSelf: 'center' }}><Portrait p={p.portrait} size={180} border="var(--gold)" /></div>
        <div class="col" style={{ gap: '2px', alignItems: 'center', textAlign: 'center' }}>
          <h1 style={{ margin: 0, fontSize: '22px' }}>{fullName(g)}</h1>
          <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--gold)' }}>{OFFICE_LABEL[p.office]} · بلدية {g.municipality.name}</span>
          <span class="muted" style={{ fontSize: '12px' }}>{age(g)} عاماً</span>
        </div>
        <div class="col" style={{ gap: '6px', fontSize: '13px', borderTop: '1px solid var(--line)', paddingTop: '12px' }}>
          <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">مكان الولادة</span><span>{MUNICIPALITY[p.municipalityId].name}، {p.birthYear}</span></span>
          <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">العائلة</span><span>{bg.short}</span></span>
          <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">الحالة</span><span>{p.married ? 'متزوّج' : 'أعزب'}</span></span>
        </div>
        <div class="col" style={{ gap: '8px' }}>
          <span class="muted" style={{ fontSize: '13px' }}>السمات</span>
          <div class="tags">{p.traits.map((t) => <span key={t} class={`tag ${TRAIT[t].tone === 'bad' ? 'red' : 'blue'}`} style={{ fontSize: '12.5px', padding: '3px 10px', borderRadius: '6px' }} title={TRAIT[t].effect}>{TRAIT[t].name}</span>)}</div>
        </div>
        <div class="col" style={{ marginTop: 'auto', background: 'var(--raised)', borderRadius: '10px', padding: '12px', gap: '6px' }}>
          <span class="muted" style={{ fontSize: '12px' }}>الطموح الحالي</span>
          <span style={{ fontSize: '15px', fontWeight: 700 }}>{amb.title}</span>
          <Bar value={(amb.items.filter((i) => i.done).length / amb.items.length) * 100} />
          <span class="muted" style={{ fontSize: '12px' }}>{amb.items.find((i) => !i.done) ? `ينقصك: ${amb.items.find((i) => !i.done)!.text}` : 'الشروط مكتملة'}</span>
        </div>
      </section>

      <section class="col grow" aria-label="ملف الشخصية">
        <div class="tabs" role="tablist" aria-label="أقسام الملف">
          {['نظرة عامة', 'شجرة العائلة', 'الثروة', 'السيرة'].map((t, i) => <button key={t} role="tab" aria-selected={tab === i} onClick={() => setTab(i)}>{t}</button>)}
        </div>
        {tab === 0 && (
          <div class="grow" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gridTemplateRows: 'repeat(2, minmax(0, 1fr))', gap: '12px' }}>
            {abilities}{family}{wealth}{life}
          </div>
        )}
        {tab === 1 && <div class="grow col">{family}</div>}
        {tab === 2 && <div class="grow col">{wealth}</div>}
        {tab === 3 && <div class="grow col" style={{ minHeight: 0 }}>{life}</div>}
      </section>

      <aside class="col" style={{ width: '320px', flexShrink: 0 }} aria-label="الحالة">
        <Card title="الحال">
          <div class="col" style={{ gap: '4px', fontSize: '13px' }}>
            <span style={{ display: 'flex', justifyContent: 'space-between' }}><span>الصحّة</span><span style={{ color: p.health > 60 ? 'var(--green-light)' : 'var(--red-light)' }}>{p.health > 75 ? 'جيّدة' : p.health > 45 ? 'متعبة' : 'سيّئة'}</span></span>
            <Bar value={p.health} color={p.health > 60 ? 'var(--green)' : 'var(--red)'} />
          </div>
          <div class="col" style={{ gap: '4px', fontSize: '13px' }}>
            <span style={{ display: 'flex', justifyContent: 'space-between' }}><span>الضغط النفسي</span><span style={{ color: 'var(--text-2)' }}>{Math.round(p.stress)} / 100</span></span>
            <Bar value={p.stress} color={p.stress > 70 ? 'var(--red)' : 'var(--gold)'} />
            <span class="muted" style={{ fontSize: '11.5px' }}>يرتفع حين تتصرّف ضدّ طبعك، وفوق 75 يضرّ صحّتك.</span>
          </div>
        </Card>
        <Card title="السمعة">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 72px 28px', gap: '8px 10px', alignItems: 'center', fontSize: '13px' }}>
            <span>عند أهل {g.municipality.name}</span><Bar value={p.reputation.local} /><span style={{ textAlign: 'end' }}>{Math.round(p.reputation.local)}</span>
            <span>عند الأعيان</span><Bar value={p.reputation.notables} /><span style={{ textAlign: 'end' }}>{Math.round(p.reputation.notables)}</span>
            <span>في عمّان</span><Bar value={p.reputation.amman} /><span style={{ textAlign: 'end' }}>{Math.round(p.reputation.amman)}</span>
            <span>عند القصر</span>{p.reputation.palace === null ? [<span key="a" class="muted" style={{ fontSize: '12px' }}>لم يسمع بك</span>, <span key="b" />] : [<Bar key="a" value={p.reputation.palace} />, <span key="b" style={{ textAlign: 'end' }}>{Math.round(p.reputation.palace)}</span>]}
          </div>
        </Card>
        <Card title="الأفضال والأسرار" class="grow">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '8px' }}>
            {[['أفضال لك', p.favorsOwedToMe.length, 'var(--green-light)'], ['أفضال عليك', p.favorsIOwe.length, 'var(--red-light)'], ['ملفّات تملكها', p.filesHeld.length, 'var(--text)'], ['خطر الفضيحة', Math.round(p.scandal), p.scandal > 40 ? 'var(--red-light)' : 'var(--text)']].map(([l, v, c]) => (
              <div key={l as string} style={{ background: 'var(--raised)', borderRadius: '8px', padding: '8px 10px', display: 'flex', flexDirection: 'column' }}><span class="muted" style={{ fontSize: '11.5px' }}>{l}</span><span style={{ fontSize: '18px', fontWeight: 700, color: c as string }}>{v}</span></div>
            ))}
          </div>
          <div class="col scroll" style={{ gap: '4px', fontSize: '12px', color: 'var(--muted)', lineHeight: 1.6 }}>
            {p.favorsIOwe.map((f, i) => <span key={`o${i}`}>عليك فضل {f.size === 'large' ? 'كبير' : 'صغير'} لـ{pe[f.personId]?.name}: {f.reason}.</span>)}
            {p.favorsOwedToMe.map((f, i) => <span key={`m${i}`}>لك فضل {f.size === 'large' ? 'كبير' : 'صغير'} عند {pe[f.personId]?.name}: {f.reason}.</span>)}
          </div>
        </Card>
        <span class="faint" style={{ fontSize: '11px' }}>منذ {formatDate(1, false)}</span>
      </aside>
    </div>
  );
}
