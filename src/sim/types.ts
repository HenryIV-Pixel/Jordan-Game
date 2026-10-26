// Core game-state types. The whole game state is plain JSON so it can be saved,
// cloned and tested without any UI.

export type StatKey = 'charisma' | 'intrigue' | 'administration' | 'diplomacy' | 'integrity';
export const STAT_KEYS: StatKey[] = ['charisma', 'intrigue', 'administration', 'diplomacy', 'integrity'];

export type FactionKey =
  | 'tribes'
  | 'merchants'
  | 'palestinians'
  | 'officers'
  | 'clergy'
  | 'nationalists'
  | 'leftists';
export const FACTION_KEYS: FactionKey[] = [
  'tribes', 'merchants', 'palestinians', 'officers', 'clergy', 'nationalists', 'leftists',
];

export type BackgroundId = 'tribal' | 'palestinian' | 'circassian' | 'christianMerchant' | 'officerSon';
export type TraitId =
  | 'ambitious' | 'patient' | 'hotTempered' | 'generous' | 'greedy' | 'pious'
  | 'educated' | 'brave' | 'deceitful' | 'honest' | 'shy' | 'reckless';

export type OfficeId = 'unemployed' | 'clerk' | 'councilMember' | 'mayor';

export type IssueKey = 'water' | 'cleanliness' | 'roads' | 'security' | 'refugees';

export interface Portrait {
  headwear: number; // 0 shemagh, 1 tarbush, 2 bare
  face: number;
  beard: number; // 0 heavy mustache, 1 light, 2 none
  skin: number;
}

export interface OpinionModifier {
  reason: string;
  value: number;
  /** Weeks left; undefined = permanent. */
  weeks?: number;
}

export interface Person {
  id: string;
  name: string;
  role: string;
  age: number;
  female?: boolean;
  traits: TraitId[];
  /** What this person thinks of the player, built from modifiers. */
  opinion: OpinionModifier[];
  /** Kind of tie to the player, drives the network drawing. */
  tie: 'family' | 'patron' | 'boss' | 'friend' | 'acquaintance' | 'rival' | 'pending';
  ring: 1 | 2;
  /** What they currently want, if anything. */
  wants?: string;
  /** What the player knows about them. */
  known?: string;
  influence: 'weak' | 'local' | 'strong';
  /** Allies among other NPCs (by id). */
  allies?: string[];
  dead?: boolean;
  /** Whether the player has already asked this person to sponsor them. */
  sponsor?: boolean;
}

export interface Favor {
  personId: string;
  size: 'small' | 'large';
  reason: string;
}

export interface Permit {
  id: string;
  applicant: string; // display name
  personId?: string;
  kind: string;
  waited: number;
  tags: { text: string; tone: 'green' | 'red' | 'gold' | 'blue' }[];
  /** Effects keyed by action, applied by the permit desk. */
  template: string;
}

export interface Project {
  id: string;
  name: string;
  status: 'idea' | 'awaitingVote' | 'underway' | 'done' | 'rejected';
  progress: number; // 0..100
  weeksTotal: number;
  note: string;
  cost: number;
  issue?: IssueKey;
}

export interface CouncilMember {
  personId: string;
  stance: 'mayor' | 'withMayor' | 'independent' | 'opposition';
}

export interface Vote {
  id: string;
  title: string;
  week: number;
  projectId?: string;
  /** personId -> 'for' | 'against' | 'undecided' */
  positions: Record<string, 'for' | 'against' | 'undecided'>;
  resolved?: 'passed' | 'failed';
}

export interface Municipality {
  id: string;
  name: string;
  region: string;
  mayorId: string;
  council: CouncilMember[];
  issues: Record<IssueKey, number>; // 0 fine .. 100 critical
  budget: { income: { label: string; amount: number }[]; expense: { label: string; amount: number }[] };
  projects: Project[];
  permits: Permit[];
  vote?: Vote;
  electionWeek: number;
  /** Local mood of each faction toward the state, 0..100. */
  mood: Record<FactionKey, number>;
}

export interface InboxItem {
  id: string;
  week: number;
  kind: 'letter' | 'report' | 'news' | 'result';
  title: string;
  body: string;
  read?: boolean;
}

export interface ActiveEvent {
  eventId: string;
  firedWeek: number;
  deadline: number; // week by which it auto-resolves
  vars: Record<string, string>;
}

export interface LogEntry {
  week: number;
  text: string;
  important?: boolean;
}

export interface Player {
  firstName: string;
  fatherName: string;
  familyName: string;
  birthYear: number;
  background: BackgroundId;
  traits: TraitId[];
  portrait: Portrait;
  stats: Record<StatKey, number>;
  xp: Record<StatKey, number>; // 0..100 toward next point
  wealth: number;
  reputation: { local: number; notables: number; amman: number; palace: number | null };
  health: number;
  stress: number;
  scandal: number; // 0..100 hidden pressure
  office: OfficeId;
  officeSince: number; // week
  municipalityId: string;
  favorsOwedToMe: Favor[];
  favorsIOwe: Favor[];
  filesHeld: string[]; // person ids we hold dirt on
  patronId?: string;
  married: boolean;
  /** Weekly income lines. */
  income: { label: string; amount: number }[];
}

export interface GameState {
  version: 1;
  seed: number;
  rng: number;
  week: number;
  player: Player;
  people: Record<string, Person>;
  municipality: Municipality;
  /** Attitude of each national faction to the player, 0..100. */
  factions: Record<FactionKey, number>;
  events: ActiveEvent[];
  firedOnce: string[];
  cooldowns: Record<string, number>;
  inbox: InboxItem[];
  log: LogEntry[];
  actionPoints: number;
  permitsLeft: number;
  flags: Record<string, number | boolean | string>;
  gameOver?: string;
}
