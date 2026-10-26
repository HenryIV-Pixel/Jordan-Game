import { useMemo, useState } from 'preact/hooks';
import { BACKGROUNDS, FACTION_LABEL, MALE_NAMES, MUNICIPALITIES, MUNICIPALITY, STAT_LABEL, TRAIT, TRAITS, type Background } from '../../sim/data';
import { createGame } from '../../sim/newGame';
import type { BackgroundId, FactionKey, Portrait as PortraitData, StatKey, TraitId } from '../../sim/types';
import { FACTION_KEYS, STAT_KEYS } from '../../sim/types';
import { BASE_STATS } from '../../sim/data';
import { Bar, Crown, Portrait, Tag } from '../components';
import { JordanMap } from '../JordanMap';
import { useApp } from '../store';

const HEADWEAR = ['شماغ وعقال', 'طربوش', 'حاسر الرأس'];
const BEARD = ['شارب كثّ', 'شارب خفيف', 'بلا شارب'];
const SKINS = [['#d9b08c', 'فاتح'], ['#b98a63', 'حنطي'], ['#8a5f3e', 'أسمر'], ['#5e3f29', 'داكن']];

function BgIcon(props: { icon: Background['icon']; color: string }) {
  const c = props.color;
  const d: Record<string, string> = {
    tent: 'M4 30 L20 10 L36 30 Z M20 10 V30 M14 30 L20 22 L26 30 M2 32 H38',
    olive: 'M20 36 V8 M20 14 Q11 12 9 6 Q16 6 20 12 M20 22 Q29 20 31 14 Q24 14 20 20 M20 30 Q11 28 9 22 Q16 22 20 28',
    mountain: 'M3 32 L14 14 L20 22 L27 10 L37 32 Z M24 15 L27 10 L30 15',
    scales: 'M20 6 V34 M12 34 H28 M8 12 H32 M8 12 L3 24 H13 Z M32 12 L27 24 H37 Z',
    star: 'M20 5 L23.5 13 L32 13.5 L25.5 19 L27.5 27.5 L20 23 L12.5 27.5 L14.5 19 L8 13.5 L16.5 13 Z M10 33 H30 M13 37 H27',
  };
  return <svg viewBox="0 0 40 40" width="34" height="34" aria-hidden="true"><path d={d[props.icon]} fill="none" stroke={c} stroke-width="2" stroke-linejoin="round" stroke-linecap="round" /></svg>;
}

function Steps(props: { step: number; bg?: Background; town?: string }) {
  const item = (n: number, label: string, done: boolean) => (
    <li style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      {done ? (
        <span style={{ width: '28px', height: '28px', borderRadius: '14px', background: 'var(--gold-bg)', border: '1px solid var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--gold)', fontSize: '14px' }}>✓</span>
      ) : (
        <span style={{ width: '28px', height: '28px', borderRadius: '14px', background: props.step === n ? 'var(--gold)' : 'transparent', border: props.step === n ? 'none' : '1px solid #4a5562', color: props.step === n ? '#15110a' : 'var(--muted)', fontWeight: 700, fontSize: '14px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{n}</span>
      )}
      <span style={{ fontSize: '14px', fontWeight: props.step === n ? 700 : 400, color: props.step === n ? 'var(--text)' : done ? 'var(--text-2)' : 'var(--muted)' }}>{label}</span>
    </li>
  );
  const line = (done: boolean) => <li aria-hidden="true" style={{ width: '48px', height: '1px', background: done ? 'var(--gold-line)' : 'var(--line-3)' }} />;
  return (
    <ol aria-label="خطوات البداية" style={{ margin: '0 auto', padding: 0, listStyle: 'none', display: 'flex', alignItems: 'center', gap: '12px' }}>
      {item(1, props.step > 1 && props.bg ? `العائلة: ${props.bg.short}` : 'العائلة', props.step > 1)}
      {line(props.step > 1)}
      {item(2, props.step > 2 && props.town ? `البلدية: ${props.town}` : 'البلدية', props.step > 2)}
      {line(props.step > 2)}
      {item(3, 'الاسم والسمات', false)}
    </ol>
  );
}

export function NewGame() {
  const app = useApp();
  const [step, setStep] = useState(1);
  const [bgId, setBgId] = useState<BackgroundId>('tribal');
  const [town, setTown] = useState('salt');
  const [first, setFirst] = useState('سليم');
  const [father, setFather] = useState('ناصر');
  const [family, setFamily] = useState('');
  const [age, setAge] = useState(24);
  const [traits, setTraits] = useState<TraitId[]>(['ambitious', 'patient', 'hotTempered']);
  const [portrait, setPortrait] = useState<PortraitData>({ headwear: 0, face: 2, beard: 0, skin: 1 });
  const bg = BACKGROUNDS.find((b) => b.id === bgId)!;

  const stats = useMemo(() => {
    const out = {} as Record<StatKey, { value: number; notes: string[] }>;
    for (const k of STAT_KEYS) {
      let v = BASE_STATS[k];
      const notes: string[] = [];
      const b = bg.statMods[k];
      if (b) { v += b; notes.push(`العائلة ${b > 0 ? '+' : ''}${b}`); }
      for (const t of traits) {
        const m = TRAIT[t].statMods?.[k];
        if (m) { v += m; notes.push(`${TRAIT[t].name} ${m > 0 ? '+' : ''}${m}`); }
      }
      out[k] = { value: Math.max(0, Math.min(20, v)), notes };
    }
    return out;
  }, [bgId, traits]);

  const toggleTrait = (t: TraitId) => {
    if (traits.includes(t)) setTraits(traits.filter((x) => x !== t));
    else if (traits.length < 3) setTraits([...traits, t]);
  };
  const blocked = (t: TraitId) => !traits.includes(t) && traits.some((x) => TRAIT[x].conflicts?.includes(t) || TRAIT[t].conflicts?.includes(x));

  const start = () => {
    const g = createGame({ background: bgId, municipalityId: town, firstName: first.trim() || 'سليم', fatherName: father.trim() || 'ناصر', familyName: family.trim(), age, traits, portrait });
    app.setGame(g);
    app.setTab('map');
    app.setOpenEvent('envelope');
    app.setScreen('game');
  };

  const header = (
    <header class="topbar" style={{ height: '72px', padding: '0 24px', gap: '24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: '#221e16', border: '1px solid var(--gold-line)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Crown /></div>
        <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.25 }}><span style={{ fontSize: '18px', fontWeight: 700 }}>لعبة جديدة</span><span class="muted" style={{ fontSize: '12px' }}>تبدأ في 2 أيار 1953</span></div>
      </div>
      <Steps step={step} bg={bg} town={MUNICIPALITY[town].name} />
      <button class="btn icon" aria-label="العودة إلى القائمة الرئيسية" onClick={() => app.setScreen('menu')}>✕</button>
    </header>
  );

  // ---------------------------------------------------------------- step 1
  if (step === 1) {
    const attitude = (k: FactionKey) => {
      const v = bg.factions[k];
      return v >= 60 ? ['ودود', 'var(--green-light)', 'var(--green)'] : v >= 40 ? ['محايد', 'var(--muted)', 'var(--muted)'] : ['حذِر', 'var(--red-light)', 'var(--red)'];
    };
    const sortedF = [...FACTION_KEYS].sort((a, b) => bg.factions[b] - bg.factions[a]);
    return (
      <>
        {header}
        <div class="content" style={{ padding: '20px 24px', gap: '16px' }}>
          <section class="col grow" style={{ gap: '16px' }} aria-label="الخلفيات العائلية">
            <div class="col" style={{ gap: '4px' }}>
              <h1 style={{ margin: 0, fontSize: '26px' }}>من أيّ عائلة يأتي بطلك؟</h1>
              <p class="muted" style={{ margin: 0, fontSize: '14px' }}>العائلة تحدّد علاقاتك الأولى بالفئات، وثروتك عند البداية، والأبواب المفتوحة أمامك. لكلّ خيار ثمنه.</p>
            </div>
            <div class="grow" style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '12px' }}>
              {BACKGROUNDS.map((b) => {
                const on = b.id === bgId;
                return (
                  <button key={b.id} aria-pressed={on} onClick={() => setBgId(b.id)} style={{ position: 'relative', textAlign: 'start', background: on ? '#1d1b15' : 'var(--panel)', border: on ? '2px solid var(--gold)' : '1px solid var(--line-2)', borderRadius: '12px', padding: on ? '16px' : '17px', color: 'var(--text)', cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {on && <span style={{ position: 'absolute', top: '12px', left: '12px', width: '24px', height: '24px', borderRadius: '12px', background: 'var(--gold)', color: '#15110a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', fontWeight: 700 }}>✓</span>}
                    <span style={{ width: '56px', height: '56px', borderRadius: '12px', background: on ? 'var(--gold-bg)' : 'var(--raised)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><BgIcon icon={b.icon} color={on ? 'var(--gold)' : 'var(--blue-light)'} /></span>
                    <span style={{ fontSize: '17px', fontWeight: 700, lineHeight: 1.4 }}>{b.name}</span>
                    <span style={{ fontSize: '13px', color: 'var(--text-2)', lineHeight: 1.6 }}>{b.flavor}</span>
                    <span class="col" style={{ gap: '6px', fontSize: '12.5px' }}>
                      {b.pros.map((x) => <span key={x} style={{ display: 'flex', gap: '6px' }}><span style={{ color: 'var(--green)', fontWeight: 700 }}>+</span>{x}</span>)}
                      {b.cons.map((x) => <span key={x} style={{ display: 'flex', gap: '6px' }}><span style={{ color: 'var(--red)', fontWeight: 700 }}>−</span>{x}</span>)}
                    </span>
                    <span class="tags" style={{ marginTop: 'auto' }}>
                      {b.careers.map((c) => <Tag key={c} tone="blue">{c}</Tag>)}
                      <Tag tone={b.difficulty === 'عالية' ? 'gold' : 'green'}>صعوبة: {b.difficulty}</Tag>
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
          <aside class="card" style={{ width: '400px', flexShrink: 0, padding: '20px', gap: '16px' }} aria-label="ملخّص الاختيار">
            <div class="col" style={{ gap: '4px' }}><span class="muted" style={{ fontSize: '12px' }}>اختيارك</span><span style={{ fontSize: '20px', fontWeight: 700, color: 'var(--gold-light)' }}>{bg.name}</span></div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '8px' }}>
              <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>الثروة</span><b style={{ fontSize: '16px' }}>{bg.wealth} د.</b></div>
              <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>السمعة</span><b style={{ fontSize: '16px' }}>{bg.reputation}</b></div>
              <div class="list-row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 0 }}><span class="muted" style={{ fontSize: '11px' }}>ثقة القصر</span><b style={{ fontSize: '16px', color: bg.palaceKnown ? 'var(--gold-light)' : 'var(--muted)' }}>{bg.palaceKnown ? 'معروف' : 'مجهولة'}</b></div>
            </div>
            <div class="col" style={{ gap: '8px' }}>
              <span style={{ fontSize: '14px', fontWeight: 700 }}>موقف الفئات منك عند البداية</span>
              <div style={{ display: 'grid', gridTemplateColumns: '104px 1fr 40px', gap: '8px 10px', alignItems: 'center', fontSize: '13px' }}>
                {sortedF.map((k) => {
                  const [w, c, bar] = attitude(k);
                  return [<span key={`${k}a`}>{FACTION_LABEL[k]}</span>, <Bar key={`${k}b`} value={bg.factions[k]} color={bar} />, <span key={`${k}c`} style={{ color: c, textAlign: 'end' }}>{w}</span>];
                })}
              </div>
            </div>
            <div class="col" style={{ gap: '8px' }}>
              <span style={{ fontSize: '14px', fontWeight: 700 }}>معارفك الأولى</span>
              {[bg.patron, bg.friend].map((p, i) => (
                <div key={p.name} style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                  <Portrait silhouette size={30} border="var(--line-3)" />
                  <span class="col" style={{ gap: 0 }}><span style={{ fontSize: '13px', fontWeight: 600 }}>{p.name}</span><span class="muted" style={{ fontSize: '12px' }}>{p.relation} · {i === 0 ? 'راعٍ محتمل' : 'صديق'}</span></span>
                </div>
              ))}
            </div>
            <div class="row" style={{ marginTop: 'auto', gap: '8px' }}>
              <button class="btn" style={{ height: '48px', fontSize: '15px' }} onClick={() => app.setScreen('menu')}>رجوع</button>
              <button class="btn primary grow" style={{ height: '48px' }} onClick={() => setStep(2)}>التالي: اختر البلدية ←</button>
            </div>
          </aside>
        </div>
      </>
    );
  }

  // ---------------------------------------------------------------- step 2
  if (step === 2) {
    const m = MUNICIPALITY[town];
    const diffColor = (d: string) => (d === 'صعبة' ? 'var(--red-light)' : d === 'متوسطة' ? 'var(--gold-light)' : 'var(--green-light)');
    return (
      <>
        {header}
        <div class="content" style={{ padding: '20px 24px', gap: '16px' }}>
          <aside class="col grow" style={{ gap: '14px' }} aria-label="اختيار البلدية">
            <div class="col" style={{ gap: '4px' }}>
              <h1 style={{ margin: 0, fontSize: '26px' }}>أين تبدأ مسيرتك؟</h1>
              <p class="muted" style={{ margin: 0, fontSize: '14px' }}>ستبدأ كاتباً في بلدية من بلديات الضفة الشرقية. اختر من القائمة أو اضغط على المدينة في الخريطة.</p>
            </div>
            <div class="card" style={{ padding: 0, overflow: 'hidden', gap: 0 }} role="listbox" aria-label="البلديات">
              <div style={{ display: 'grid', gridTemplateColumns: '110px 70px 1fr 74px', gap: '12px', padding: '8px 14px', fontSize: '12px', color: 'var(--muted)', borderBottom: '1px solid var(--line)' }}><span>البلدية</span><span>المنطقة</span><span>طابعها</span><span>الصعوبة</span></div>
              {MUNICIPALITIES.map((x) => {
                const on = x.id === town;
                return (
                  <button key={x.id} role="option" aria-selected={on} onClick={() => setTown(x.id)} style={{ display: 'grid', gridTemplateColumns: '110px 70px 1fr 74px', gap: '12px', alignItems: 'center', padding: '8px 14px', background: on ? 'var(--gold-bg)' : 'transparent', border: 'none', borderInlineStart: on ? '3px solid var(--gold)' : '3px solid transparent', borderBottom: '1px solid #1f262e', textAlign: 'start', color: 'var(--text)', fontSize: '13.5px', cursor: 'pointer' }}>
                    <span style={{ fontWeight: on ? 700 : 600, color: on ? 'var(--gold-light)' : 'var(--text)' }}>{x.name}</span>
                    <span class="muted">{x.region}</span>
                    <span style={{ color: 'var(--text-2)' }}>{x.character}</span>
                    <span style={{ color: diffColor(x.difficulty) }}>{x.difficulty}</span>
                  </button>
                );
              })}
            </div>
            <div class="card gold" style={{ gap: '10px' }}>
              <div class="card-title"><span style={{ color: 'var(--gold-light)', fontSize: '17px' }}>بلدية {m.name}</span><span>منصبك الأول: كاتب في البلدية</span></div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '8px 20px', fontSize: '13px' }}>
                {m.pros.map((x) => <span key={x} style={{ display: 'flex', gap: '6px' }}><span style={{ color: 'var(--green)', fontWeight: 700 }}>+</span>{x}</span>)}
                {m.cons.map((x) => <span key={x} style={{ display: 'flex', gap: '6px' }}><span style={{ color: 'var(--red)', fontWeight: 700 }}>−</span>{x}</span>)}
              </div>
            </div>
            <div class="row" style={{ marginTop: 'auto', gap: '8px' }}>
              <button class="btn" style={{ height: '48px', fontSize: '15px' }} onClick={() => setStep(1)}>رجوع</button>
              <button class="btn primary grow" style={{ height: '48px' }} onClick={() => setStep(3)}>التالي: الاسم والسمات ←</button>
            </div>
          </aside>
          <section style={{ width: '872px', height: '756px', flexShrink: 0, position: 'relative', background: 'var(--sea)', border: '1px solid var(--line)', borderRadius: '12px', overflow: 'hidden' }} aria-label="الخريطة">
            <JordanMap selected={town} selectable={MUNICIPALITIES.map((x) => x.id)} onSelect={setTown} />
            <div style={{ position: 'absolute', top: '40px', left: '14px', width: '150px', background: 'rgba(20,25,32,0.94)', border: '1px solid var(--line-2)', borderRadius: '8px', padding: '8px 10px', fontSize: '12px', lineHeight: 1.5, color: 'var(--text-2)' }}>الضفة الغربية جزء من المملكة، لكنها ليست نقطة بداية متاحة.</div>
          </section>
        </div>
      </>
    );
  }

  // ---------------------------------------------------------------- step 3
  const cycle = (key: keyof PortraitData, n: number, dir: number) => setPortrait({ ...portrait, [key]: (portrait[key] + dir + n) % n });
  const randomName = () => {
    setFirst(MALE_NAMES[Math.floor(Math.random() * MALE_NAMES.length)]);
    setFather(MALE_NAMES[Math.floor(Math.random() * MALE_NAMES.length)]);
  };
  const Stepper = (props: { label: string; value: string; k: keyof PortraitData; n: number }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'var(--raised)', borderRadius: '8px', padding: '4px' }}>
      <button class="btn" style={{ width: '36px', height: '36px', padding: 0, background: 'transparent', border: 'none', fontSize: '18px' }} aria-label={`${props.label}: السابق`} onClick={() => cycle(props.k, props.n, -1)}>›</button>
      <span class="col" style={{ gap: 0, alignItems: 'center' }}><span class="muted" style={{ fontSize: '11px' }}>{props.label}</span><span style={{ fontSize: '14px', fontWeight: 600 }}>{props.value}</span></span>
      <button class="btn" style={{ width: '36px', height: '36px', padding: 0, background: 'transparent', border: 'none', fontSize: '18px' }} aria-label={`${props.label}: التالي`} onClick={() => cycle(props.k, props.n, 1)}>‹</button>
    </div>
  );
  return (
    <>
      {header}
      <div class="content" style={{ padding: '20px 24px', gap: '16px' }}>
        <section class="card" style={{ width: '340px', flexShrink: 0, padding: '18px', gap: '14px' }} aria-label="الصورة">
          <div class="card-title"><span>الصورة</span><button class="btn sm" onClick={() => setPortrait({ headwear: Math.floor(Math.random() * 3), face: Math.floor(Math.random() * 8), beard: Math.floor(Math.random() * 3), skin: Math.floor(Math.random() * 4) })}>عشوائي</button></div>
          <div style={{ alignSelf: 'center' }}><Portrait p={portrait} size={200} label="معاينة صورة الشخصية" /></div>
          <div class="col" style={{ gap: '8px' }}>
            <Stepper label="غطاء الرأس" value={HEADWEAR[portrait.headwear]} k="headwear" n={3} />
            <Stepper label="الوجه" value={`${portrait.face + 1} من 8`} k="face" n={8} />
            <Stepper label="الشارب واللحية" value={BEARD[portrait.beard]} k="beard" n={3} />
            <div class="list-row" style={{ padding: '8px 12px' }}>
              <span class="muted">لون البشرة</span>
              <span style={{ display: 'flex', gap: '6px' }}>
                {SKINS.map(([c, n], i) => <button key={c} aria-label={`لون بشرة ${n}`} aria-pressed={portrait.skin === i} onClick={() => setPortrait({ ...portrait, skin: i })} style={{ width: '24px', height: '24px', borderRadius: '12px', background: c, border: portrait.skin === i ? '2px solid var(--gold)' : '2px solid transparent', cursor: 'pointer' }} />)}
              </span>
            </div>
          </div>
          <span class="muted" style={{ marginTop: 'auto', fontSize: '12px', lineHeight: 1.6 }}>الصور الحالية مؤقتة. الرسوم النهائية تُركَّب من أجزاء، والصورة تشيخ مع الشخصية.</span>
        </section>

        <section class="col grow" style={{ gap: '16px' }} aria-label="الاسم والسمات">
          <div class="card" style={{ padding: '18px', gap: '14px' }}>
            <div class="card-title"><span>الاسم والعمر</span><button class="btn sm" onClick={randomName}>اسم عشوائي</button></div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '12px' }}>
              <label class="col" style={{ gap: '6px', fontSize: '12px', color: 'var(--muted)' }}>الاسم الأول<input class="inputbox" value={first} onInput={(e) => setFirst((e.target as HTMLInputElement).value)} /></label>
              <label class="col" style={{ gap: '6px', fontSize: '12px', color: 'var(--muted)' }}>اسم الأب<input class="inputbox" value={father} onInput={(e) => setFather((e.target as HTMLInputElement).value)} /></label>
              <label class="col" style={{ gap: '6px', fontSize: '12px', color: 'var(--muted)' }}>اسم العائلة<input class="inputbox" value={family} placeholder="(اختياري)" onInput={(e) => setFamily((e.target as HTMLInputElement).value)} /></label>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
              <span class="muted" style={{ fontSize: '13px', width: '40px' }}>العمر</span>
              <div class="grow" style={{ display: 'grid', gridTemplateColumns: 'repeat(11, minmax(0, 1fr))', gap: '4px' }}>
                {Array.from({ length: 11 }, (_, i) => 20 + i).map((a) => (
                  <button key={a} aria-pressed={a === age} onClick={() => setAge(a)} style={{ height: '34px', borderRadius: '6px', background: a === age ? 'var(--gold)' : 'var(--raised)', border: `1px solid ${a === age ? 'var(--gold)' : 'var(--line-2)'}`, color: a === age ? '#15110a' : 'var(--text-2)', fontWeight: a === age ? 700 : 400, fontSize: '13px', cursor: 'pointer' }}>{a}</button>
                ))}
              </div>
            </div>
            <span class="muted" style={{ fontSize: '12px' }}>الأصغر سنّاً يملك وقتاً أطول للصعود، والأكبر يبدأ بخبرة ومعارف أكثر.</span>
          </div>
          <div class="card grow" style={{ padding: '18px', gap: '12px' }}>
            <div class="card-title"><span>السمات الشخصية</span><span>اخترت <b style={{ color: 'var(--gold-light)' }}>{traits.length} من 3</b></span></div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: '8px' }}>
              {TRAITS.map((t) => {
                const on = traits.includes(t.id);
                const isBlocked = blocked(t.id);
                const conflictWith = isBlocked ? traits.find((x) => TRAIT[x].conflicts?.includes(t.id) || t.conflicts?.includes(x)) : undefined;
                return (
                  <button key={t.id} aria-pressed={on} disabled={isBlocked || (!on && traits.length >= 3)} onClick={() => toggleTrait(t.id)} style={{ textAlign: 'start', background: on ? 'var(--gold-bg)' : isBlocked ? '#14191e' : 'var(--raised)', border: on ? '1px solid var(--gold)' : isBlocked ? '1px dashed var(--line-2)' : '1px solid var(--line-2)', borderRadius: '8px', padding: '9px 11px', color: isBlocked ? 'var(--faint)' : 'var(--text)', cursor: isBlocked ? 'default' : 'pointer', display: 'flex', flexDirection: 'column', gap: '3px' }}>
                    <span style={{ fontSize: '14px', fontWeight: on ? 700 : 600 }}>{t.name}</span>
                    <span style={{ fontSize: '11.5px', color: on ? 'var(--text-2)' : 'var(--muted)' }}>{conflictWith ? `يتعارض مع «${TRAIT[conflictWith].name}»` : t.effect}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </section>

        <aside class="card" style={{ width: '380px', flexShrink: 0, padding: '18px', gap: '16px' }} aria-label="الملخّص">
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <Portrait p={portrait} size={64} />
            <div class="col" style={{ gap: '2px' }}>
              <span style={{ fontSize: '19px', fontWeight: 700 }}>{[first, father, family].filter(Boolean).join(' ')}</span>
              <span style={{ fontSize: '13px', color: 'var(--gold)', fontWeight: 600 }}>كاتب في بلدية {MUNICIPALITY[town].name}</span>
              <span class="muted" style={{ fontSize: '12px' }}>{age} عاماً · {bg.short}</span>
            </div>
          </div>
          <div class="col" style={{ gap: '6px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700 }}>القدرات عند البداية</span>
            {STAT_KEYS.map((k) => (
              <div key={k} style={{ display: 'grid', gridTemplateColumns: '1fr auto 28px', gap: '8px', alignItems: 'center', background: 'var(--raised)', borderRadius: '6px', padding: '6px 10px', fontSize: '13px' }}>
                <span>{STAT_LABEL[k]}</span>
                <span style={{ fontSize: '11.5px', color: stats[k].notes.some((n) => n.includes('−') || n.includes('-')) ? 'var(--red-light)' : stats[k].notes.length ? 'var(--green-light)' : 'var(--muted)' }}>{stats[k].notes.join(' · ') || '—'}</span>
                <b style={{ textAlign: 'end' }}>{stats[k].value}</b>
              </div>
            ))}
          </div>
          <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
            <span style={{ fontSize: '14px', fontWeight: 700 }}>بداية المسيرة</span>
            <span style={{ color: 'var(--text-2)', lineHeight: 1.7 }}>أسبوعك الأول في بلدية {MUNICIPALITY[town].name}. الملك الشاب يتولّى سلطاته الدستورية اليوم، والبلاد تترقّب.</span>
          </div>
          <div class="col" style={{ marginTop: 'auto', gap: '8px' }}>
            <button class="btn primary" style={{ height: '52px', fontSize: '17px' }} disabled={traits.length !== 3} onClick={start}>{traits.length === 3 ? 'ابدأ المسيرة' : 'اختر ثلاث سمات'}</button>
            <button class="btn" style={{ height: '44px' }} onClick={() => setStep(2)}>رجوع</button>
          </div>
        </aside>
      </div>
    </>
  );
}
