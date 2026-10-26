// The weekly turn: income, desk, projects, opinions, scandal, votes, elections, events.
import { applyEffects } from './effects';
import { checkEvents, EVENT_BY_ID, expireEvents, fire } from './events';
import { addOpinion, clamp, inbox, log, opinionOf } from './helpers';
import { makePermit, PERMIT_TEMPLATES } from './permits';
import { chance, nextRandom } from './rng';
import { weekToDate } from './calendar';
import type { GameState } from './types';

export function endTurn(prev: GameState): GameState {
  const s: GameState = structuredClone(prev);
  if (s.gameOver) return s;

  expireEvents(s);
  s.week += 1;
  const p = s.player;

  // Income
  if (p.office === 'unemployed') p.income = p.income.filter((l) => !l.label.startsWith('راتب'));
  const net = p.income.reduce((a, l) => a + l.amount, 0);
  p.wealth += net;
  if (p.wealth < 0) {
    p.stress = clamp(p.stress + 3);
    log(s, 'أنت مدين. الضغط يزداد.');
  }

  // Opinions decay
  for (const person of Object.values(s.people)) {
    for (const m of person.opinion) if (m.weeks !== undefined) m.weeks -= 1;
    person.opinion = person.opinion.filter((m) => m.weeks === undefined || m.weeks > 0);
  }

  // Permit desk
  const m = s.municipality;
  for (const permit of m.permits) {
    permit.waited += 1;
    permit.tags = permit.tags.filter((t) => t.text !== 'مؤجَّل');
    if (permit.waited > 8 && permit.personId) addOpinion(s.people[permit.personId], -2, 'طلبه معطّل', 26);
  }
  const giveUp = m.permits.filter((x) => x.waited > 14 && !x.personId);
  if (giveUp.length) {
    m.permits = m.permits.filter((x) => !giveUp.includes(x));
    applyEffects(s, [{ t: 'rep', v: -2 * giveUp.length }]);
    log(s, `يئس ${giveUp.length === 1 ? 'صاحب طلب' : 'أصحاب طلبات'} من الانتظار. السمعة تتراجع.`);
  }
  if (p.office === 'clerk' && m.permits.length < 9) {
    const n = 1 + (chance(s, 0.5) ? 1 : 0);
    const pool = Object.values(PERMIT_TEMPLATES).filter((t) => t.recurring);
    const total = pool.reduce((a, t) => a + t.weight, 0);
    for (let i = 0; i < n; i++) {
      let r = nextRandom(s) * total;
      const t = pool.find((x) => (r -= x.weight) < 0) ?? pool[0];
      m.permits.push(makePermit(s, t.id));
    }
  }

  // Projects and town issues
  const month = weekToDate(s.week).getUTCMonth();
  const summer = month >= 5 && month <= 8;
  for (const pr of m.projects) {
    if (pr.status !== 'underway') continue;
    pr.progress = Math.min(100, pr.progress + 100 / pr.weeksTotal);
    if (pr.progress >= 100) {
      pr.status = 'done';
      if (pr.issue) m.issues[pr.issue] = clamp(m.issues[pr.issue] - 30);
      inbox(s, 'report', `اكتمل مشروع: ${pr.name}`, 'أعلنت البلدية انتهاء العمل. الناس يلاحظون الفرق.');
      applyEffects(s, [{ t: 'rep', v: 2 }]);
    }
  }
  const waterUnderway = m.projects.some((x) => x.id === 'water' && (x.status === 'underway' || x.status === 'done'));
  if (summer && !waterUnderway) m.issues.water = clamp(m.issues.water + 1);
  if (!summer) m.issues.water = clamp(m.issues.water - 0.5);
  m.issues.cleanliness = clamp(m.issues.cleanliness + 0.3);

  // Health, stress and scandal
  if (p.stress > 75) p.health = clamp(p.health - 2);
  else if (p.health < 90) p.health = clamp(p.health + 1);
  p.stress = clamp(p.stress - 1);
  if (p.scandal > 0) p.scandal = clamp(p.scandal - 0.5);
  if (p.scandal >= 55 && p.office !== 'unemployed' && !s.events.some((e) => e.eventId === 'exposure')) {
    const risk = (p.scandal - 45) / 250;
    if (nextRandom(s) < risk && (!s.cooldowns.exposure || s.cooldowns.exposure <= s.week)) fire(s, EVENT_BY_ID.exposure);
  }
  if (p.health <= 0) {
    s.gameOver = 'مات بطلك. (نظام الورثة يأتي في المرحلة القادمة.)';
    return s;
  }
  p.married = !!s.flags.married;

  // Council vote
  if (m.vote && !m.vote.resolved && s.week >= m.vote.week) resolveVote(s);

  // Elections
  if (s.week === m.electionWeek && s.flags.running) runElection(s);

  // Unemployed: a chance to be re-hired through a patron
  if (p.office === 'unemployed' && s.week - p.officeSince > 8 && p.patronId && opinionOf(s.people[p.patronId]) >= 40 && chance(s, 0.15)) {
    applyEffects(s, [
      { t: 'office', office: 'clerk' },
      { t: 'favorIOwe', who: p.patronId, size: 'small', reason: 'أعادك إلى العمل' },
      { t: 'log', text: 'بفضل راعيك، عدت إلى العمل في البلدية.', important: true },
    ]);
    if (!p.income.some((l) => l.label.startsWith('راتب'))) p.income.unshift({ label: 'راتب كاتب البلدية', amount: 3 });
  }

  checkEvents(s);

  // Weekly capacity
  const rest = !!s.flags.restWeek;
  s.flags.restWeek = false;
  s.actionPoints = rest ? 1 : 3;
  s.permitsLeft = p.office === 'clerk' ? (rest ? 0 : 3 + (p.stats.administration >= 12 ? 1 : 0)) : 0;
  return s;
}

function resolveVote(s: GameState) {
  const m = s.municipality;
  const v = m.vote!;
  let yes = 0, no = 0;
  for (const [id, pos] of Object.entries(v.positions)) {
    if (pos === 'for') yes++;
    else if (pos === 'against') no++;
    else if (opinionOf(s.people[id]) > 40 && chance(s, 0.3)) yes++;
    else no++;
  }
  const passed = yes > no;
  v.resolved = passed ? 'passed' : 'failed';
  const project = m.projects.find((x) => x.id === v.projectId);
  if (project) project.status = passed ? 'underway' : 'rejected';
  // the proposed budget line becomes real spending or disappears
  const line = m.budget.expense.find((l) => l.label.includes('(مقترح)'));
  if (line) {
    if (passed) line.label = line.label.replace(' (مقترح)', '');
    else m.budget.expense = m.budget.expense.filter((l) => l !== line);
  }
  inbox(s, 'result', `المجلس البلدي: ${v.title}`, passed
    ? `أُقرّ المشروع بـ${yes} أصوات مقابل ${no}. يبدأ العمل الأسبوع القادم.`
    : `سقط المشروع: ${yes} مع، ${no} ضدّ. المياه ستبقى أزمة هذا الصيف.`);
  log(s, passed ? `أقرّ المجلس ${v.title}.` : `رفض المجلس ${v.title}.`, true);
  if (passed && s.flags.helpedVote) {
    addOpinion(s.people.mayor, 15, 'ساعدني في تمرير الخزّان', 156);
    applyEffects(s, [{ t: 'favorToMe', who: 'mayor', size: 'small', reason: 'تمرير ميزانية الخزّان' }]);
  }
}

export function electionForecast(s: GameState): { you: number; rival: number; third: number; undecided: number } {
  const p = s.player;
  const sponsors = Object.values(s.people).filter((x) => x.sponsor);
  let you = 16 + p.reputation.local * 0.2 + p.reputation.notables * 0.1;
  you += sponsors.reduce((a, x) => a + (x.influence === 'strong' ? 5 : x.influence === 'local' ? 3 : 1), 0);
  you += (s.factions.tribes - 50) * 0.08 + (s.factions.palestinians - 50) * 0.06 + (s.factions.merchants - 50) * 0.04;
  you += p.stats.charisma * 0.4 - p.scandal * 0.15;
  if (s.flags.noSponsor) you -= 4;
  const rivalDamage = Number(s.flags.rivalDamage ?? 0);
  const rivalOpinionOfMayor = s.people.mayor && opinionOf(s.people.mayor) > 40 ? -4 : 0;
  let rival = 46 - rivalDamage + rivalOpinionOfMayor;
  const third = 22;
  you = Math.max(5, you);
  rival = Math.max(5, rival);
  const total = you + rival + third + 6;
  return {
    you: Math.round((you / total) * 100),
    rival: Math.round((rival / total) * 100),
    third: Math.round((third / total) * 100),
    undecided: 100 - Math.round((you / total) * 100) - Math.round((rival / total) * 100) - Math.round((third / total) * 100),
  };
}

function runElection(s: GameState) {
  const f = electionForecast(s);
  const noise = (nextRandom(s) - 0.5) * 10;
  const you = f.you + noise + f.undecided * nextRandom(s);
  const rival = f.rival - noise + f.undecided * nextRandom(s);
  const won = you > rival && you > f.third;
  const rivalName = s.people.rival.name;
  if (won) {
    applyEffects(s, [
      { t: 'office', office: 'councilMember' }, { t: 'rep', v: 10 }, { t: 'rep', v: 8, scope: 'notables' },
      { t: 'log', text: `فزت بمقعد في المجلس البلدي بنحو ${Math.round(you)}% من الأصوات.`, important: true },
      { t: 'inbox', kind: 'result', title: 'فزت بالمقعد!', body: `حصلت على نحو ${Math.round(you)}% من الأصوات، مقابل ${Math.round(rival)}% لـ${rivalName}. أصبحت عضواً في المجلس البلدي.` },
    ]);
    const p = s.player;
    p.income = p.income.filter((l) => !l.label.startsWith('راتب'));
    p.income.unshift({ label: 'مكافأة عضو المجلس', amount: 2 });
    s.municipality.council.push({ personId: 'me', stance: 'independent' });
    addOpinion(s.people.rival, -15, 'هزمني', 156);
  } else {
    applyEffects(s, [
      { t: 'rep', v: -4 }, { t: 'stress', v: 10 },
      { t: 'log', text: `خسرت الانتخابات أمام ${rivalName}.`, important: true },
      { t: 'inbox', kind: 'result', title: 'خسرت الانتخابات', body: `حصلت على نحو ${Math.round(you)}% مقابل ${Math.round(rival)}% لـ${rivalName}. الانتخابات القادمة بعد أربع سنوات، والطريق ما زال طويلاً.` },
    ]);
    s.people.rival.role = 'عضو المجلس البلدي';
    s.municipality.council.push({ personId: 'rival', stance: 'withMayor' });
    s.municipality.electionWeek = s.week + 208;
  }
  s.flags.running = false;
}
