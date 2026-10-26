// Builds the opening state from the player's New Game choices.
import { BACKGROUNDS, BASE_STATS, FEMALE_NAMES, MALE_NAMES, MUNICIPALITY, TRAIT } from './data';
import { log } from './helpers';
import { checkEvents } from './events';
import { makePermit } from './permits';
import { seededRandom } from './rng';
import type {
  BackgroundId, FactionKey, GameState, Municipality, Person, Portrait, StatKey, TraitId,
} from './types';
import { FACTION_KEYS, STAT_KEYS } from './types';

export interface NewGameChoices {
  background: BackgroundId;
  municipalityId: string;
  firstName: string;
  fatherName: string;
  familyName: string;
  age: number;
  traits: TraitId[];
  portrait: Portrait;
  seed?: number;
}

export const ELECTION_WEEK = 19;
export const WATER_VOTE_WEEK = 4;

export function createGame(c: NewGameChoices): GameState {
  const seed = c.seed ?? Math.floor(Math.random() * 2 ** 31);
  const rnd = seededRandom(seed);
  const used = new Set<string>([c.firstName, c.fatherName]);
  const pickName = (list: string[]) => {
    for (let i = 0; i < 50; i++) {
      const n = list[Math.floor(rnd() * list.length)];
      if (!used.has(n)) { used.add(n); return n; }
    }
    return list[0];
  };
  const bg = BACKGROUNDS.find((b) => b.id === c.background)!;
  const mdef = MUNICIPALITY[c.municipalityId];
  const people: Record<string, Person> = {};
  const add = (p: Omit<Person, 'opinion'> & { opinion?: Person['opinion'] }) => {
    people[p.id] = { opinion: [], ...p };
    return p.id;
  };

  // --- family ---
  const motherName = FEMALE_NAMES[Math.floor(rnd() * FEMALE_NAMES.length)];
  add({ id: 'father', name: c.fatherName, role: 'الأب', age: c.age + 32, traits: [], tie: 'family', ring: 1, influence: 'weak',
    opinion: [{ reason: 'ابنه', value: 60 }] });
  add({ id: 'mother', name: motherName, role: 'الأم', age: c.age + 27, female: true, traits: [], tie: 'family', ring: 1, influence: 'weak',
    opinion: [{ reason: 'ابنها', value: 70 }] });
  const brother = pickName(MALE_NAMES);
  add({ id: 'brother', name: brother, role: 'الأخ الأصغر · طالب', age: c.age - 5, traits: [], tie: 'family', ring: 1, influence: 'weak',
    opinion: [{ reason: 'أخوه', value: 45 }], wants: 'وظيفة بعد التخرّج' });
  const sister = FEMALE_NAMES[Math.floor(rnd() * FEMALE_NAMES.length)];
  add({ id: 'sister', name: sister, role: 'الأخت · متزوّجة', age: c.age - 3, female: true, traits: [], tie: 'family', ring: 2, influence: 'weak',
    opinion: [{ reason: 'أخوها', value: 50 }] });

  // --- patron and friend from the background ---
  add({ id: 'patron', name: bg.patron.name, role: `${bg.patron.role} · ${bg.patron.relation}`, age: 64, traits: ['patient'], tie: 'patron', ring: 1,
    influence: 'strong', opinion: [{ reason: 'من العائلة', value: 30 }, { reason: 'يرى فيك مستقبلاً', value: 10 }],
    wants: 'أن تردّ الجميل حين يطلب' });
  add({ id: 'friend', name: bg.friend.name, role: `${bg.friend.role} · ${bg.friend.relation}`, age: c.age + 2, traits: ['brave'], tie: 'friend',
    ring: 1, influence: 'local', opinion: [{ reason: 'صداقة قديمة', value: 45 }] });

  // --- the town ---
  const mayorName = `الحاج ${pickName(MALE_NAMES)}`;
  const mayorOpinion: Person['opinion'] = [{ reason: 'موظف مجتهد', value: 10 }];
  if (c.background === 'tribal' || c.background === 'circassian') mayorOpinion.push({ reason: 'من عائلة يحترمها', value: 10 });
  if (c.traits.includes('ambitious')) mayorOpinion.push({ reason: 'طموحك يقلقه', value: -5 });
  add({ id: 'mayor', name: mayorName, role: `رئيس بلدية ${mdef.name}`, age: 55, traits: ['greedy'], tie: 'boss', ring: 1, influence: 'strong',
    opinion: mayorOpinion, wants: 'تمرير ميزانية إصلاح خزّان المياه قبل الصيف', allies: ['rival', 'member1', 'member2'],
    known: 'يحمي منافسك لأنه ابن صديقه. لا أسرار معروفة بعد.' });
  add({ id: 'rival', name: pickName(MALE_NAMES), role: 'كاتب يطمح للمقعد نفسه', age: c.age + 1, traits: ['ambitious', 'deceitful'], tie: 'rival', ring: 2,
    influence: 'local', opinion: [{ reason: 'منافس على المقعد', value: -35 }], allies: ['mayor'] });
  add({ id: 'member1', name: pickName(MALE_NAMES), role: 'عضو المجلس · مالك أراضٍ', age: 50, traits: [], tie: 'acquaintance', ring: 2, influence: 'local',
    opinion: [{ reason: 'لا يعرفك جيداً', value: 0 }], allies: ['mayor'] });
  add({ id: 'member2', name: pickName(MALE_NAMES), role: 'عضو المجلس · تاجر أقمشة', age: 47, traits: [], tie: 'acquaintance', ring: 2, influence: 'local',
    opinion: [{ reason: 'لا يعرفك جيداً', value: 5 }] });
  add({ id: 'doctor', name: `الدكتور ${pickName(MALE_NAMES)}`, role: 'عضو المجلس · طبيب', age: 44, traits: ['educated', 'honest'], tie: 'acquaintance',
    ring: 2, influence: 'local', opinion: [{ reason: 'محايد', value: 5 }], wants: 'مستوصف للحيّ الفقير' });
  add({ id: 'teacher', name: `الأستاذ ${pickName(MALE_NAMES)}`, role: 'عضو المجلس · معلّم', age: 39, traits: ['educated'], tie: 'acquaintance',
    ring: 2, influence: 'weak', opinion: [{ reason: 'يحترم المتعلّمين', value: 10 }], wants: 'مدرسة ثانية للبنات' });
  add({ id: 'mukhtar', name: 'أبو محمود', role: 'مختار الحيّ', age: 60, traits: ['generous'], tie: 'friend', ring: 1, influence: 'local',
    opinion: [{ reason: 'جار قديم', value: 25 }], wants: 'بئر لأهل الحيّ' });
  add({ id: 'merchant', name: 'أبو خليل', role: 'تاجر في السوق', age: 52, traits: ['greedy'], tie: 'pending', ring: 2, influence: 'local',
    opinion: [{ reason: 'يحتاج ترخيصك', value: 10 }] });
  add({ id: 'police', name: `الملازم أوّل ${pickName(MALE_NAMES)}`, role: `شرطة ${mdef.name}`, age: 35, traits: ['patient'], tie: 'acquaintance',
    ring: 2, influence: 'local', opinion: [{ reason: 'معرفة عابرة', value: 5 }] });

  // --- player stats ---
  const stats = { ...BASE_STATS } as Record<StatKey, number>;
  const flags: GameState['flags'] = {};
  for (const k of STAT_KEYS) {
    const m = bg.statMods[k] ?? 0;
    if (m) { stats[k] += m; flags[`bgmod_${k}`] = m; }
  }
  for (const t of c.traits) for (const [k, v] of Object.entries(TRAIT[t].statMods ?? {})) stats[k as StatKey] += v as number;
  for (const k of STAT_KEYS) stats[k] = Math.max(0, Math.min(20, stats[k]));

  const familyIncome: Record<BackgroundId, { label: string; amount: number }> = {
    tribal: { label: 'حصّتك من زيتون العائلة', amount: 2 },
    palestinian: { label: 'دكّان العائلة', amount: 2 },
    circassian: { label: 'إيجار أرض العائلة', amount: 2 },
    christianMerchant: { label: 'حصّة في تجارة العائلة', amount: 6 },
    officerSon: { label: 'مساعدة من تقاعد الأب', amount: 1 },
  };

  const mood = {} as Record<FactionKey, number>;
  for (const k of FACTION_KEYS) mood[k] = 45 + Math.floor(rnd() * 30);

  const s = mdef.budgetScale;
  const R = (n: number) => Math.round(n * s / 100) * 100;
  const municipality: Municipality = {
    id: mdef.id, name: mdef.name, region: mdef.region, mayorId: 'mayor',
    council: [
      { personId: 'mayor', stance: 'mayor' }, { personId: 'member1', stance: 'withMayor' }, { personId: 'member2', stance: 'withMayor' },
      { personId: 'doctor', stance: 'independent' }, { personId: 'teacher', stance: 'opposition' },
    ],
    issues: { ...mdef.issues },
    budget: {
      income: [{ label: 'الرسوم والرخص', amount: R(3200) }, { label: 'ضريبة الأبنية', amount: R(2100) }, { label: 'منحة الحكومة', amount: R(1500) }],
      expense: [{ label: 'الرواتب', amount: R(2900) }, { label: 'إصلاح الخزّان (مقترح)', amount: R(2400) }, { label: 'النظافة', amount: R(1100) }, { label: 'الطرق', amount: R(900) }],
    },
    projects: [
      { id: 'water', name: 'إصلاح خزّان المياه العامّ', status: 'awaitingVote', progress: 10, weeksTotal: 16, note: 'الرئيس يريده قبل الصيف', cost: R(2400), issue: 'water' },
      { id: 'road', name: 'رصف طريق السوق', status: 'underway', progress: 60, weeksTotal: 15, note: 'المقاول من أقارب عضو في المجلس', cost: R(900), issue: 'roads' },
      { id: 'school', name: 'مدرسة البنات الثانية', status: 'idea', progress: 0, weeksTotal: 30, note: 'تحتاج من يقترحها في المجلس', cost: R(1800) },
    ],
    permits: [],
    vote: {
      id: 'waterVote', title: 'ميزانية إصلاح خزّان المياه', week: WATER_VOTE_WEEK, projectId: 'water',
      positions: { mayor: 'for', member1: 'for', member2: 'against', doctor: 'undecided', teacher: 'against' },
    },
    electionWeek: ELECTION_WEEK,
    mood,
  };

  const state: GameState = {
    version: 1, seed, rng: seed, week: 1,
    player: {
      firstName: c.firstName, fatherName: c.fatherName, familyName: c.familyName, birthYear: 1953 - c.age,
      background: c.background, traits: c.traits, portrait: c.portrait, stats,
      xp: { charisma: 40, intrigue: 15, administration: 72, diplomacy: 25, integrity: 50 },
      wealth: bg.wealth,
      reputation: { local: bg.reputation + 10, notables: 20, amman: 5, palace: bg.palaceKnown ? 30 : null },
      health: 88, stress: 20, scandal: 0, office: 'clerk', officeSince: -100, municipalityId: mdef.id,
      favorsOwedToMe: [
        { personId: 'mukhtar', size: 'small', reason: 'سرّعت له معاملة' },
        { personId: 'member2', size: 'small', reason: 'ساعدته في سجلّ قديم' },
        { personId: 'friend', size: 'large', reason: 'وقفت معه في محنة' },
      ],
      favorsIOwe: [{ personId: 'patron', size: 'large', reason: 'التوصية التي جاءت بك إلى البلدية' }],
      filesHeld: [], married: false,
      income: [{ label: 'راتب كاتب البلدية', amount: 3 }, familyIncome[c.background], { label: 'مصروف البيت والضيافة', amount: -1 }],
    },
    people, municipality, factions: { ...bg.factions },
    events: [], firedOnce: [], cooldowns: {}, inbox: [], log: [],
    actionPoints: 3, permitsLeft: 3, flags,
  };

  // Opening permits: the merchant's request is the first event's hook.
  municipality.permits.push(makePermit(state, 'shopLicense', 'merchant', 8));
  municipality.permits.push(makePermit(state, 'well', 'mukhtar', 1));
  municipality.permits.push(makePermit(state, 'widowFee', undefined, 2));
  municipality.permits.push(makePermit(state, 'busLine', 'rival', 4));
  municipality.permits.push(makePermit(state, 'hallBooking', undefined, 3));
  municipality.permits.push(makePermit(state, 'landDispute', undefined, 5));

  log(state, `بدأ ${c.firstName} ${c.fatherName} عمله كاتباً في بلدية ${mdef.name}.`, true);
  checkEvents(state);
  return state;
}
