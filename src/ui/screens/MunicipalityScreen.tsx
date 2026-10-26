import { useState } from 'preact/hooks';
import { deskAction } from '../../sim/actions';
import { durationLabel, weeksLabel } from '../../sim/calendar';
import { ISSUE_LABEL, MUNICIPALITY } from '../../sim/data';
import { effectTags } from '../../sim/effects';
import { OFFICE_LABEL, opinionOf } from '../../sim/helpers';
import { availableActions, DESK_LABEL, PERMIT_TEMPLATES, type DeskAction } from '../../sim/permits';
import type { IssueKey } from '../../sim/types';
import { Bar, Card, Check, Lock, Tag, Tags } from '../components';
import { useApp, useGame } from '../store';

const STANCE: Record<string, [string, string]> = {
  mayor: ['يقود الكتلة', 'var(--gold-light)'],
  withMayor: ['مع الرئيس', 'var(--blue-light)'],
  independent: ['مستقلّ', 'var(--text-2)'],
  opposition: ['معارض', 'var(--red-light)'],
};

function issueLevel(k: IssueKey, v: number): [string, string] {
  if (k === 'security') return v >= 60 ? ['متوتّر', 'var(--red)'] : v >= 35 ? ['حذِر', 'var(--gold)'] : ['هادئ', 'var(--green)'];
  return v >= 75 ? ['حرجة', 'var(--red)'] : v >= 55 ? ['متوسّطة', 'var(--gold)'] : v >= 35 ? ['مقبولة', 'var(--gold)'] : ['جيدة', 'var(--green)'];
}

export function MunicipalityScreen() {
  const app = useApp();
  const g = useGame();
  const m = g.municipality;
  const def = MUNICIPALITY[m.id];
  const p = g.player;
  const [tab, setTab] = useState(0);
  const [menuFor, setMenuFor] = useState<string | null>(null);
  const clerk = p.office === 'clerk';
  const member = p.office === 'councilMember';

  const act = (id: string, a: DeskAction) => {
    setMenuFor(null);
    const r = app.act((s) => deskAction(s, id, a));
    if (r && !r.ok) app.toast(r.message);
  };

  const totalIn = m.budget.income.reduce((a, l) => a + l.amount, 0);
  const totalOut = m.budget.expense.reduce((a, l) => a + l.amount, 0);
  const maxLine = Math.max(...m.budget.income.map((l) => l.amount), ...m.budget.expense.map((l) => l.amount));
  const vote = m.vote;
  const tally = vote ? Object.values(vote.positions).reduce((a, v) => ({ ...a, [v]: (a[v] ?? 0) + 1 }), {} as Record<string, number>) : {};
  const voters = vote ? Object.keys(vote.positions).length : 0;
  const undecided = vote ? Object.entries(vote.positions).find(([, v]) => v === 'undecided')?.[0] : undefined;

  const powers: [string, boolean, string][] = [
    ['معالجة الطلبات والرخص', clerk, 'كاتب'],
    ['تسريع ملف أو تأخيره', clerk, 'كاتب'],
    ['الاطلاع على سجلّات البلدية', true, ''],
    ['التصويت على الميزانية', member, 'عضو مجلس'],
    ['اقتراح المشاريع', member, 'عضو مجلس'],
    ['تعيين الموظفين وفصلهم', false, 'الرئيس'],
    ['توقيع العقود', false, 'الرئيس'],
  ];

  const permitsCard = (
    <div class="card" style={{ padding: 0, gap: 0, overflow: 'visible' }} role="table" aria-label="الطلبات المعلّقة">
      <div class="card-title" style={{ padding: '12px 14px 8px' }}>
        <span>الطلبات المعلّقة على مكتبك</span>
        <span>{clerk ? `تستطيع إنجاز ${g.permitsLeft} ${g.permitsLeft === 1 ? 'طلب' : 'طلبات'} أخرى هذا الأسبوع` : 'لم يعد المكتب من عملك'}</span>
      </div>
      <div role="row" style={{ display: 'grid', gridTemplateColumns: '150px 1fr 74px 200px 186px', gap: '12px', padding: '6px 14px', fontSize: '12px', color: 'var(--muted)', borderBottom: '1px solid var(--line)' }}>
        <span role="columnheader">صاحب الطلب</span><span role="columnheader">الطلب</span><span role="columnheader">ينتظر</span><span role="columnheader">ملاحظات</span><span role="columnheader">إجراء</span>
      </div>
      <div class="scroll" style={{ maxHeight: '330px' }}>
        {m.permits.length === 0 && <div class="muted" style={{ padding: '14px', fontSize: '13px' }}>لا طلبات معلّقة. ستصل طلبات جديدة الأسبوع القادم.</div>}
        {m.permits.map((pm, i) => {
          const acts = availableActions(pm).filter((a) => a !== 'approve' && a !== 'delay');
          const hl = pm.personId === 'merchant' && g.events.some((e) => e.eventId === 'envelope');
          const preview = effectTags(g, PERMIT_TEMPLATES[pm.template].effects.approve ?? [], { person: pm.personId ?? '' });
          return (
            <div key={pm.id} role="row" style={{ position: 'relative', display: 'grid', gridTemplateColumns: '150px 1fr 74px 200px 186px', gap: '12px', alignItems: 'center', padding: '8px 14px', background: hl ? '#221e16' : 'transparent', borderInlineStart: `3px solid ${hl ? 'var(--gold)' : 'transparent'}`, borderBottom: '1px solid #1f262e', fontSize: '13.5px' }}>
              <span role="cell" style={{ fontWeight: 600 }}>{pm.applicant}</span>
              <span role="cell" class="col" style={{ gap: '3px' }}><span style={{ color: 'var(--text-2)' }}>{pm.kind}</span><Tags items={preview.slice(0, 3)} /></span>
              <span role="cell" style={{ color: pm.waited > 8 ? 'var(--red-light)' : 'var(--muted)' }}>{pm.waited === 0 ? 'جديد' : durationLabel(pm.waited)}</span>
              <span role="cell" class="tags">{pm.tags.map((t) => <Tag key={t.text} tone={t.tone}>{t.text}</Tag>)}</span>
              <span role="cell" style={{ display: 'flex', gap: '4px' }}>
                <button class="btn sm greenish" disabled={!clerk || g.permitsLeft <= 0} onClick={() => act(pm.id, 'approve')}>أنجِز</button>
                <button class="btn sm" disabled={!clerk} onClick={() => act(pm.id, 'delay')}>أجِّل</button>
                {acts.length > 0 && <button class="btn sm" style={{ width: '32px', padding: 0 }} disabled={!clerk} aria-label="خيارات أخرى" aria-expanded={menuFor === pm.id} onClick={() => setMenuFor(menuFor === pm.id ? null : pm.id)}>⋯</button>}
              </span>
              {menuFor === pm.id && (
                <div style={{ position: 'absolute', left: '14px', top: i > 3 ? 'auto' : '44px', bottom: i > 3 ? '44px' : 'auto', zIndex: 5, background: '#1b2129', border: '1px solid var(--line-3)', borderRadius: '10px', padding: '6px', display: 'flex', flexDirection: 'column', gap: '4px', minWidth: '230px', boxShadow: '0 8px 24px rgba(0,0,0,.4)' }} role="menu">
                  {acts.map((a) => {
                    const tags = effectTags(g, PERMIT_TEMPLATES[pm.template].effects[a] ?? [], { person: pm.personId ?? '' });
                    return (
                      <button key={a} role="menuitem" class="btn" style={{ justifyContent: 'space-between', height: 'auto', padding: '8px 10px', flexDirection: 'column', alignItems: 'flex-start', gap: '4px' }} disabled={g.permitsLeft <= 0} onClick={() => act(pm.id, a)}>
                        <span style={{ fontWeight: 600 }}>{DESK_LABEL[a]}</span><Tags items={tags} />
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );

  return (
    <div class="content">
      <aside class="col" style={{ width: '300px', flexShrink: 0 }} aria-label="البلدية ودورك">
        <Card>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <span style={{ width: '48px', height: '48px', borderRadius: '10px', background: '#221e16', border: '1px solid var(--gold-line)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><svg viewBox="0 0 32 32" width="28" height="28" aria-hidden="true"><path d="M4 28 H28 M6 28 V14 M26 28 V14 M11 28 V14 M16 28 V14 M21 28 V14 M3 14 H29 L16 5 Z" fill="none" stroke="var(--gold)" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round" /></svg></span>
            <span class="col" style={{ gap: 0 }}><h1 style={{ margin: 0, fontSize: '20px' }}>بلدية {m.name}</h1><span class="muted" style={{ fontSize: '12px' }}>{def.district}</span></span>
          </div>
          <div class="col" style={{ gap: '6px', fontSize: '13px' }}>
            <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">رئيس البلدية</span><span>{g.people.mayor.name}</span></span>
            <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">منصبك</span><span style={{ color: 'var(--gold-light)', fontWeight: 600 }}>{OFFICE_LABEL[p.office]}</span></span>
            <span style={{ display: 'flex', justifyContent: 'space-between' }}><span class="muted">الانتخابات البلدية</span><span>{m.electionWeek >= g.week ? weeksLabel(m.electionWeek - g.week) : '—'}</span></span>
          </div>
        </Card>
        <Card title="صلاحياتك">
          <div class="col" style={{ gap: '9px', fontSize: '13px' }}>
            {powers.map(([t, ok, who]) => ok
              ? <span key={t} style={{ display: 'flex', gap: '8px', alignItems: 'center' }}><Check />{t}</span>
              : <span key={t} style={{ display: 'flex', gap: '8px', alignItems: 'center', color: 'var(--faint)' }}><Lock size={16} /><span class="grow">{t}</span><span style={{ fontSize: '11px' }}>{who}</span></span>)}
          </div>
        </Card>
        <Card title="هموم المدينة" class="grow">
          <div class="col" style={{ gap: '10px' }}>
            {(Object.keys(ISSUE_LABEL) as IssueKey[]).map((k) => {
              const [w, c] = issueLevel(k, m.issues[k]);
              return (
                <div key={k} style={{ display: 'grid', gridTemplateColumns: '80px 1fr 56px', gap: '10px', alignItems: 'center', fontSize: '13px' }}>
                  <span>{ISSUE_LABEL[k]}</span><Bar value={m.issues[k]} color={c} /><span style={{ textAlign: 'end', color: c, fontSize: '12px' }}>{w}</span>
                </div>
              );
            })}
          </div>
          <span class="muted" style={{ fontSize: '11.5px', lineHeight: 1.6, marginTop: 'auto' }}>كلّ همّ يُحَلّ في عهدك يضيف إلى سمعتك عند الانتخابات.</span>
        </Card>
      </aside>

      <section class="col grow" aria-label="مكتب البلدية">
        <div class="tabs" role="tablist">
          {[`مكتب الطلبات`, 'المشاريع والميزانية'].map((t, i) => (
            <button key={t} role="tab" aria-selected={tab === i} onClick={() => setTab(i)}>{t}{i === 0 && <span style={{ fontSize: '11px', background: 'var(--gold)', color: '#15110a', borderRadius: '8px', padding: '0 6px', marginInlineStart: '6px' }}>{m.permits.length}</span>}</button>
          ))}
        </div>
        {tab === 0 && permitsCard}
        <div class="grow" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '12px', minHeight: 0 }}>
          <Card title={`ميزانية ${new Date(Date.UTC(1953, 4, 2 + (g.week - 1) * 7)).getUTCFullYear()}`} right={<span style={{ color: totalIn >= totalOut ? 'var(--green-light)' : 'var(--red-light)', fontWeight: 600 }}>{totalIn >= totalOut ? `فائض ${totalIn - totalOut} د.` : `عجز متوقّع ${totalOut - totalIn} د.`}</span>}>
            <span class="muted" style={{ fontSize: '12px' }}>الإيرادات · {totalIn.toLocaleString('en')} د.</span>
            {m.budget.income.map((l) => <div key={l.label} style={{ display: 'grid', gridTemplateColumns: '130px 1fr 60px', gap: '10px', alignItems: 'center', fontSize: '12.5px' }}><span>{l.label}</span><Bar value={l.amount} max={maxLine} color="var(--green)" height={8} /><span style={{ textAlign: 'end', color: 'var(--text-2)' }}>{l.amount.toLocaleString('en')}</span></div>)}
            <span class="muted" style={{ fontSize: '12px', paddingTop: '2px' }}>النفقات · {totalOut.toLocaleString('en')} د.</span>
            {m.budget.expense.map((l) => <div key={l.label} style={{ display: 'grid', gridTemplateColumns: '130px 1fr 60px', gap: '10px', alignItems: 'center', fontSize: '12.5px' }}><span>{l.label}</span><Bar value={l.amount} max={maxLine} color={l.label.includes('مقترح') ? 'var(--gold)' : 'var(--blue)'} height={8} /><span style={{ textAlign: 'end', color: 'var(--text-2)' }}>{l.amount.toLocaleString('en')}</span></div>)}
          </Card>
          <Card title="المشاريع">
            <div class="col scroll" style={{ gap: '8px' }}>
              {m.projects.map((pr) => {
                const st: Record<string, [string, string]> = { idea: ['فكرة', 'var(--faint)'], awaitingVote: ['بانتظار تصويت المجلس', 'var(--gold)'], underway: ['قيد التنفيذ', 'var(--green)'], done: ['منجز', 'var(--green)'], rejected: ['رفضه المجلس', 'var(--red)'] };
                const [label, color] = st[pr.status];
                return (
                  <div key={pr.id} style={{ background: 'var(--raised)', borderRadius: '8px', padding: '9px 12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <span style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13.5px' }}><b style={{ fontWeight: 600 }}>{pr.name}</b><span style={{ fontSize: '12px', color }}>{label}</span></span>
                    <Bar value={pr.progress} color={color} height={5} />
                    <span class="muted" style={{ fontSize: '11.5px' }}>{pr.note}</span>
                  </div>
                );
              })}
            </div>
          </Card>
        </div>
      </section>

      <aside class="col" style={{ width: '320px', flexShrink: 0 }} aria-label="المجلس البلدي">
        <Card title="المجلس البلدي">
          {m.council.map((c) => {
            const person = c.personId === 'me' ? null : g.people[c.personId];
            const [w, col] = STANCE[c.stance];
            return (
              <span key={c.personId} style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: '8px', alignItems: 'center', background: 'var(--raised)', borderRadius: '6px', padding: '6px 10px', fontSize: '13px' }}>
                <span class="col" style={{ gap: 0 }}><span style={{ fontWeight: 600 }}>{person ? person.name : `${p.firstName} (أنت)`}</span><span class="muted" style={{ fontSize: '11px' }}>{person ? person.role.replace('عضو المجلس · ', 'عضو · ') : 'عضو · مستقلّ'}</span></span>
                <span style={{ fontSize: '11.5px', color: col }}>{w}</span>
              </span>
            );
          })}
          {m.council.length < 6 && (
            <span style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: '8px', alignItems: 'center', background: 'var(--raised)', borderRadius: '6px', padding: '6px 10px', fontSize: '13px' }}>
              <span class="col" style={{ gap: 0 }}><span style={{ fontWeight: 600 }}>المقعد السادس</span><span class="muted" style={{ fontSize: '11px' }}>شاغر — في الانتخابات القادمة</span></span>
              <span style={{ fontSize: '11.5px', color: 'var(--green-light)' }}>هدفك</span>
            </span>
          )}
        </Card>
        {vote && !vote.resolved ? (
          <Card gold title="التصويت القادم" right={weeksLabel(vote.week - g.week)}>
            <span style={{ fontSize: '13.5px' }}>{vote.title}</span>
            <div style={{ display: 'flex', height: '22px', borderRadius: '6px', overflow: 'hidden', fontSize: '11.5px', fontWeight: 700 }}>
              {(tally.for ?? 0) > 0 && <span style={{ width: `${((tally.for ?? 0) / voters) * 100}%`, background: '#2f5a3d', color: '#d6f2df', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>مع: {tally.for}</span>}
              {(tally.undecided ?? 0) > 0 && <span style={{ width: `${((tally.undecided ?? 0) / voters) * 100}%`, background: '#3a434e', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>؟ {tally.undecided}</span>}
              {(tally.against ?? 0) > 0 && <span style={{ width: `${((tally.against ?? 0) / voters) * 100}%`, background: '#6a3529', color: '#f6d5cc', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>ضدّ: {tally.against}</span>}
            </div>
            <span style={{ fontSize: '12px', color: 'var(--text-2)', lineHeight: 1.6 }}>
              {undecided ? `${g.people[undecided].name} متردّد. إن أقنعته، يحفظ الرئيس لك الجميل. ` : ''}يحتاج المشروع أغلبية الأصوات.
            </span>
            <div class="col" style={{ gap: '4px' }}>
              {Object.entries(vote.positions).filter(([, v]) => v !== 'for').map(([id, v]) => (
                <button key={id} class="btn goldish" onClick={() => { app.setSelected(id); app.setTab('network'); }}>
                  أقنع {g.people[id].name} <span style={{ fontSize: '11px', opacity: 0.8 }}>({v === 'undecided' ? 'متردّد' : 'ضدّ'} · رأيه {opinionOf(g.people[id])})</span>
                </button>
              ))}
            </div>
          </Card>
        ) : vote ? (
          <Card title="آخر تصويت">
            <span style={{ fontSize: '13.5px' }}>{vote.title}</span>
            <span style={{ color: vote.resolved === 'passed' ? 'var(--green-light)' : 'var(--red-light)', fontWeight: 600 }}>{vote.resolved === 'passed' ? 'أُقرّ المشروع' : 'سقط المشروع'}</span>
          </Card>
        ) : null}
      </aside>
    </div>
  );
}
