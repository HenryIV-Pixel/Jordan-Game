// Data-driven effects. Events and player actions describe their consequences as
// lists of effects; the same list is applied to the state and turned into the
// coloured consequence tags shown on buttons.
import { FACTION_LABEL, ISSUE_LABEL, STAT_SHORT } from './data';
import { addOpinion, clamp, gainXp, inbox, log } from './helpers';
import type { FactionKey, GameState, IssueKey, OfficeId, Person, StatKey } from './types';

export type Effect =
  | { t: 'wealth'; v: number }
  | { t: 'rep'; v: number; scope?: 'local' | 'notables' | 'amman' }
  | { t: 'palace'; v: number }
  | { t: 'stat'; k: StatKey; v: number }
  | { t: 'xp'; k: StatKey; v: number }
  | { t: 'opinion'; who: string; v: number; reason: string; weeks?: number }
  | { t: 'faction'; k: FactionKey; v: number }
  | { t: 'mood'; k: FactionKey; v: number }
  | { t: 'scandal'; v: number }
  | { t: 'stress'; v: number }
  | { t: 'health'; v: number }
  | { t: 'favorToMe'; who: string; size: 'small' | 'large'; reason: string }
  | { t: 'favorIOwe'; who: string; size: 'small' | 'large'; reason: string }
  | { t: 'repayFavor'; who: string }
  | { t: 'useFavor'; who: string }
  | { t: 'issue'; k: IssueKey; v: number }
  | { t: 'flag'; k: string; v: number | boolean | string }
  | { t: 'tie'; who: string; tie: Person['tie'] }
  | { t: 'file'; who: string }
  | { t: 'log'; text: string; important?: boolean }
  | { t: 'inbox'; kind: 'letter' | 'report' | 'news' | 'result'; title: string; body: string }
  | { t: 'queueEvent'; id: string; delay: number }
  | { t: 'office'; office: OfficeId }
  | { t: 'patron'; who: string }
  | { t: 'votePos'; who: string; pos: 'for' | 'against' | 'undecided' }
  | { t: 'project'; id: string; status: 'idea' | 'awaitingVote' | 'underway' | 'done' | 'rejected' }
  | { t: 'removePermit'; id: string }
  | { t: 'known'; who: string; text: string }
  | { t: 'hiddenRisk'; text: string };

export type Vars = Record<string, string>;

function resolveWho(who: string, vars: Vars): string {
  return who.startsWith('$') ? vars[who.slice(1)] ?? who : who;
}

export function applyEffects(state: GameState, effects: Effect[], vars: Vars = {}) {
  const p = state.player;
  for (const e of effects) {
    switch (e.t) {
      case 'wealth':
        p.wealth = Math.round(p.wealth + e.v);
        break;
      case 'rep': {
        const scope = e.scope ?? 'local';
        p.reputation[scope] = clamp(p.reputation[scope] + e.v);
        break;
      }
      case 'palace':
        p.reputation.palace = clamp((p.reputation.palace ?? 0) + e.v);
        break;
      case 'stat':
        p.stats[e.k] = clamp(p.stats[e.k] + e.v, 0, 20);
        break;
      case 'xp':
        gainXp(state, e.k, e.v);
        break;
      case 'opinion': {
        const person = state.people[resolveWho(e.who, vars)];
        if (person) addOpinion(person, e.v, e.reason, e.weeks);
        break;
      }
      case 'faction':
        state.factions[e.k] = clamp(state.factions[e.k] + e.v);
        break;
      case 'mood':
        state.municipality.mood[e.k] = clamp(state.municipality.mood[e.k] + e.v);
        break;
      case 'scandal':
        p.scandal = clamp(p.scandal + e.v);
        break;
      case 'stress':
        p.stress = clamp(p.stress + e.v);
        break;
      case 'health':
        p.health = clamp(p.health + e.v);
        break;
      case 'favorToMe':
        p.favorsOwedToMe.push({ personId: resolveWho(e.who, vars), size: e.size, reason: e.reason });
        break;
      case 'favorIOwe':
        p.favorsIOwe.push({ personId: resolveWho(e.who, vars), size: e.size, reason: e.reason });
        break;
      case 'repayFavor': {
        const id = resolveWho(e.who, vars);
        const i = p.favorsIOwe.findIndex((f) => f.personId === id);
        if (i >= 0) p.favorsIOwe.splice(i, 1);
        break;
      }
      case 'useFavor': {
        const id = resolveWho(e.who, vars);
        const i = p.favorsOwedToMe.findIndex((f) => f.personId === id);
        if (i >= 0) p.favorsOwedToMe.splice(i, 1);
        break;
      }
      case 'issue': {
        const m = state.municipality;
        m.issues[e.k] = clamp(m.issues[e.k] + e.v);
        break;
      }
      case 'flag':
        state.flags[e.k] = e.v;
        break;
      case 'tie': {
        const person = state.people[resolveWho(e.who, vars)];
        if (person) person.tie = e.tie;
        break;
      }
      case 'file': {
        const id = resolveWho(e.who, vars);
        if (!p.filesHeld.includes(id)) p.filesHeld.push(id);
        break;
      }
      case 'log':
        log(state, fill(e.text, vars, state), e.important);
        break;
      case 'inbox':
        inbox(state, e.kind, fill(e.title, vars, state), fill(e.body, vars, state));
        break;
      case 'queueEvent':
        state.flags[`queued_${e.id}`] = state.week + e.delay;
        break;
      case 'office':
        p.office = e.office;
        p.officeSince = state.week;
        break;
      case 'patron':
        p.patronId = resolveWho(e.who, vars);
        break;
      case 'votePos': {
        const v = state.municipality.vote;
        if (v) v.positions[resolveWho(e.who, vars)] = e.pos;
        break;
      }
      case 'project': {
        const pr = state.municipality.projects.find((x) => x.id === e.id);
        if (pr) pr.status = e.status;
        break;
      }
      case 'removePermit': {
        const m = state.municipality;
        m.permits = m.permits.filter((x) => x.id !== resolveWho(e.id, vars));
        break;
      }
      case 'known': {
        const person = state.people[resolveWho(e.who, vars)];
        if (person) person.known = fill(e.text, vars, state);
        break;
      }
      case 'hiddenRisk':
        break;
    }
  }
}

/** Replace {name:id} and {var} placeholders in event text. */
export function fill(text: string, vars: Vars, state: GameState): string {
  return text
    .replace(/\{name:([$\w]+)\}/g, (_, id) => state.people[resolveWho(id, vars)]?.name ?? '؟')
    .replace(/\{role:([$\w]+)\}/g, (_, id) => state.people[resolveWho(id, vars)]?.role ?? '')
    .replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? `{${k}}`);
}

export type Tone = 'green' | 'red' | 'gold' | 'blue' | 'grey';

/** Human-readable consequence tags for a list of effects. */
export function effectTags(state: GameState, effects: Effect[], vars: Vars = {}): { text: string; tone: Tone }[] {
  const out: { text: string; tone: Tone }[] = [];
  const sign = (v: number) => (v > 0 ? `+${v}` : `${v}`);
  for (const e of effects) {
    switch (e.t) {
      case 'wealth': out.push({ text: `${sign(e.v)} د.`, tone: e.v >= 0 ? 'green' : 'red' }); break;
      case 'rep': out.push({ text: `سمعة ${sign(e.v)}`, tone: e.v >= 0 ? 'green' : 'red' }); break;
      case 'palace': out.push({ text: `ثقة القصر ${sign(e.v)}`, tone: e.v >= 0 ? 'green' : 'red' }); break;
      case 'stat': out.push({ text: `${STAT_SHORT[e.k]} ${sign(e.v)}`, tone: e.v >= 0 ? 'green' : 'red' }); break;
      case 'opinion': {
        const name = state.people[resolveWho(e.who, vars)]?.name ?? '';
        out.push({ text: `${name} ${sign(e.v)}`, tone: e.v >= 0 ? 'green' : 'red' });
        break;
      }
      case 'faction':
      case 'mood':
        out.push({ text: `${FACTION_LABEL[e.k]} ${e.v > 0 ? '+' : '−'}`, tone: e.v >= 0 ? 'green' : 'red' });
        break;
      case 'scandal': if (e.v > 0) out.push({ text: `فضيحة +${Math.max(1, Math.round(e.v / 8))}`, tone: 'red' }); else out.push({ text: 'فضيحة −', tone: 'green' }); break;
      case 'stress': out.push({ text: `ضغط نفسي ${sign(e.v)}`, tone: e.v > 0 ? 'red' : 'green' }); break;
      case 'health': out.push({ text: `صحّة ${sign(e.v)}`, tone: e.v >= 0 ? 'green' : 'red' }); break;
      case 'favorToMe': out.push({ text: e.size === 'large' ? '+فضل كبير' : '+1 فضل', tone: 'green' }); break;
      case 'favorIOwe': out.push({ text: 'فضل عليك', tone: 'gold' }); break;
      case 'repayFavor': out.push({ text: 'تسدّد فضلاً', tone: 'blue' }); break;
      case 'useFavor': out.push({ text: 'تستهلك فضلاً', tone: 'gold' }); break;
      case 'issue': out.push({ text: `${ISSUE_LABEL[e.k]} ${e.v < 0 ? 'تتحسّن' : 'تسوء'}`, tone: e.v < 0 ? 'green' : 'red' }); break;
      case 'tie':
        if (e.tie === 'rival') out.push({ text: `${state.people[resolveWho(e.who, vars)]?.name ?? ''} يصبح خصماً`, tone: 'red' });
        if (e.tie === 'friend') out.push({ text: `${state.people[resolveWho(e.who, vars)]?.name ?? ''} صديق`, tone: 'green' });
        break;
      case 'file': out.push({ text: 'ملف جديد', tone: 'gold' }); break;
      case 'hiddenRisk': out.push({ text: e.text, tone: 'gold' }); break;
      default: break;
    }
  }
  return out;
}
