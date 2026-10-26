// Static game data: backgrounds, traits, factions, municipalities, names.
import type { BackgroundId, FactionKey, IssueKey, StatKey, TraitId } from './types';

export const STAT_LABEL: Record<StatKey, string> = {
  charisma: 'الكاريزما',
  intrigue: 'الدهاء',
  administration: 'الإدارة',
  diplomacy: 'الدبلوماسية',
  integrity: 'النزاهة',
};
export const STAT_SHORT: Record<StatKey, string> = {
  charisma: 'كاريزما', intrigue: 'دهاء', administration: 'إدارة', diplomacy: 'دبلوماسية', integrity: 'نزاهة',
};
export const STAT_GROWTH: Record<StatKey, string> = {
  charisma: 'ينمو بالخطابة واللقاءات',
  intrigue: 'ينمو بالمؤامرات وجمع الأسرار',
  administration: 'ينمو بالعمل في البلدية',
  diplomacy: 'ينمو بالوساطات وحلّ النزاعات',
  integrity: 'تنخفض مع كلّ رشوة، وترتفع برفضها',
};

export const FACTION_LABEL: Record<FactionKey, string> = {
  tribes: 'العشائر',
  merchants: 'تجّار المدن',
  palestinians: 'الفلسطينيون',
  officers: 'الضبّاط',
  clergy: 'علماء الدين',
  nationalists: 'القوميون العرب',
  leftists: 'اليساريون',
};

export const ISSUE_LABEL: Record<IssueKey, string> = {
  water: 'المياه', cleanliness: 'النظافة', roads: 'الطرق', security: 'الأمن', refugees: 'اللاجئون',
};

export interface Background {
  id: BackgroundId;
  name: string;
  short: string;
  flavor: string;
  pros: string[];
  cons: string[];
  careers: ('مدني' | 'عسكري')[];
  difficulty: 'سهلة' | 'متوسطة' | 'عالية';
  wealth: number;
  reputation: number;
  palaceKnown: boolean;
  statMods: Partial<Record<StatKey, number>>;
  factions: Record<FactionKey, number>;
  patron: { name: string; role: string; relation: string };
  friend: { name: string; role: string; relation: string };
  icon: 'tent' | 'olive' | 'mountain' | 'scales' | 'star';
}

const F = (t: number, m: number, p: number, o: number, c: number, n: number, l: number): Record<FactionKey, number> =>
  ({ tribes: t, merchants: m, palestinians: p, officers: o, clergy: c, nationalists: n, leftists: l });

export const BACKGROUNDS: Background[] = [
  {
    id: 'tribal', name: 'عائلة عشائرية من الضفة الشرقية', short: 'عشائرية، الضفة الشرقية', icon: 'tent',
    flavor: 'ابن عشيرة معروفة في البلقاء. الكلمة في الديوان تفتح أبواباً لا تفتحها الشهادات.',
    pros: ['أصوات عشائرية قوية', 'روابط مع الجيش'], cons: ['ريبة الفلسطينيين واليساريين'],
    careers: ['مدني', 'عسكري'], difficulty: 'متوسطة', wealth: 120, reputation: 35, palaceKnown: false,
    statMods: { charisma: 1 }, factions: F(80, 50, 30, 65, 55, 40, 22),
    patron: { name: 'الشيخ فالح', role: 'شيخ العشيرة', relation: 'عمّ الأب' },
    friend: { name: 'الملازم مازن', role: 'ملازم في الجيش العربي', relation: 'ابن العمّ' },
  },
  {
    id: 'palestinian', name: 'عائلة فلسطينية الأصل', short: 'فلسطينية الأصل', icon: 'olive',
    flavor: 'عائلة نزحت بعد 1948 واستقرّت شرق النهر. متعلّمة، تعرف التجارة، وتحمل ذاكرة ثقيلة.',
    pros: ['قاعدة انتخابية واسعة', 'روابط تجارية وتعليمية'], cons: ['رقابة أشدّ من القصر والأمن'],
    careers: ['مدني', 'عسكري'], difficulty: 'عالية', wealth: 150, reputation: 30, palaceKnown: false,
    statMods: { administration: 2 }, factions: F(35, 60, 85, 35, 50, 65, 50),
    patron: { name: 'الحاج يعقوب', role: 'تاجر ووجيه', relation: 'خال الأمّ' },
    friend: { name: 'الأستاذ رامي', role: 'معلّم في المدرسة الثانوية', relation: 'صديق الدراسة' },
  },
  {
    id: 'circassian', name: 'عائلة شركسية أو شيشانية', short: 'شركسية', icon: 'mountain',
    flavor: 'من الجماعات التي استقرّت في عمّان والزرقاء قبل قيام الإمارة، ولها حضور قديم في الحرس والشرطة.',
    pros: ['ثقة القصر من البداية', 'صلات في الجيش والشرطة'], cons: ['جماعة صغيرة وقاعدة انتخابية ضعيفة'],
    careers: ['مدني', 'عسكري'], difficulty: 'متوسطة', wealth: 130, reputation: 30, palaceKnown: true,
    statMods: { intrigue: 1 }, factions: F(55, 55, 45, 75, 55, 35, 25),
    patron: { name: 'العقيد يوسف', role: 'ضابط في الحرس الملكي', relation: 'عمّ الأب' },
    friend: { name: 'الملازم أوّل علي', role: 'ضابط شرطة', relation: 'ابن الخالة' },
  },
  {
    id: 'christianMerchant', name: 'عائلة تجّار مسيحية', short: 'تجّار مسيحية', icon: 'scales',
    flavor: 'بيت تجارة عريق في السلط أو مادبا. المال حاضر، والمعارف تمتدّ إلى بيروت ودمشق.',
    pros: ['ثروة كبيرة عند البداية', 'صلات بالمصارف والتجّار'], cons: ['صعوبة الفوز في الدوائر ذات الغالبية المسلمة'],
    careers: ['مدني'], difficulty: 'سهلة', wealth: 400, reputation: 35, palaceKnown: false,
    statMods: { diplomacy: 1 }, factions: F(45, 75, 50, 45, 35, 50, 40),
    patron: { name: 'الخواجة إلياس', role: 'تاجر جملة ووجيه', relation: 'عمّ الأب' },
    friend: { name: 'جورج', role: 'موظف في البنك العربي', relation: 'ابن العمّ' },
  },
  {
    id: 'officerSon', name: 'ابن ضابط سابق', short: 'ابن ضابط سابق', icon: 'star',
    flavor: 'أبوك خدم في الجيش العربي وتقاعد برتبة رئيس. البزّة العسكرية تبدو الطريق الأقصر.',
    pros: ['دخول سهل إلى المسار العسكري', 'صلات بالضبّاط'], cons: ['صلات مدنية قليلة'],
    careers: ['عسكري', 'مدني'], difficulty: 'متوسطة', wealth: 110, reputation: 28, palaceKnown: false,
    statMods: { charisma: 1 }, factions: F(60, 45, 40, 80, 50, 45, 25),
    patron: { name: 'الزعيم المتقاعد سالم', role: 'قائد أبيك القديم', relation: 'صديق العائلة' },
    friend: { name: 'الملازم مازن', role: 'ملازم في الجيش العربي', relation: 'رفيق الطفولة' },
  },
];

export interface Trait {
  id: TraitId;
  name: string;
  effect: string;
  statMods?: Partial<Record<StatKey, number>>;
  conflicts?: TraitId[];
  tone: 'good' | 'bad' | 'neutral';
}

export const TRAITS: Trait[] = [
  { id: 'ambitious', name: 'طموح', effect: 'ترقيات أسرع، رضا أقلّ', tone: 'neutral' },
  { id: 'patient', name: 'صبور', effect: 'دهاء +1، مؤامرات أنجح', statMods: { intrigue: 1 }, conflicts: ['reckless'], tone: 'good' },
  { id: 'hotTempered', name: 'حادّ الطبع', effect: 'خطابة أقوى، دبلوماسية −2', statMods: { diplomacy: -2, charisma: 1 }, tone: 'bad' },
  { id: 'generous', name: 'كريم', effect: 'ولاء الأصدقاء، نفقات أعلى', conflicts: ['greedy'], tone: 'good' },
  { id: 'greedy', name: 'جشع', effect: 'رشاوى أكبر، نزاهة −2', statMods: { integrity: -2 }, conflicts: ['generous', 'honest'], tone: 'bad' },
  { id: 'pious', name: 'متديّن', effect: 'علماء الدين +، اليساريون −', tone: 'neutral' },
  { id: 'educated', name: 'مثقّف', effect: 'إدارة +2، القوميون +', statMods: { administration: 2 }, tone: 'good' },
  { id: 'brave', name: 'شجاع', effect: 'هيبة +، أفضل في الجيش', conflicts: ['shy'], tone: 'good' },
  { id: 'deceitful', name: 'مخادع', effect: 'دهاء +2، الفضيحة أقرب', statMods: { intrigue: 2 }, conflicts: ['honest'], tone: 'bad' },
  { id: 'honest', name: 'نزيه', effect: 'نزاهة +3، سمعة تنمو ببطء', statMods: { integrity: 3 }, conflicts: ['deceitful', 'greedy'], tone: 'good' },
  { id: 'shy', name: 'خجول', effect: 'كاريزما −2، إدارة +1', statMods: { charisma: -2, administration: 1 }, conflicts: ['brave'], tone: 'bad' },
  { id: 'reckless', name: 'متهوّر', effect: 'جرأة في المخاطر، فضائح أكثر', conflicts: ['patient'], tone: 'bad' },
];
export const TRAIT = Object.fromEntries(TRAITS.map((t) => [t.id, t])) as Record<TraitId, Trait>;

export const BASE_STATS: Record<StatKey, number> = { charisma: 7, intrigue: 10, administration: 9, diplomacy: 8, integrity: 14 };

export interface MunicipalityDef {
  id: string;
  name: string;
  region: 'الشمال' | 'الوسط' | 'الجنوب';
  lon: number;
  lat: number;
  character: string;
  difficulty: 'سهلة' | 'متوسطة' | 'صعبة';
  pros: string[];
  cons: string[];
  district: string;
  issues: Record<IssueKey, number>;
  budgetScale: number;
}

const I = (water: number, cleanliness: number, roads: number, security: number, refugees: number) =>
  ({ water, cleanliness, roads, security, refugees });

export const MUNICIPALITIES: MunicipalityDef[] = [
  { id: 'amman', name: 'عمّان', region: 'الوسط', lon: 35.93, lat: 31.95, district: 'لواء عمّان', character: 'العاصمة — منافسة شديدة ومعارف كثيرة', difficulty: 'صعبة', pros: ['قرب الحكومة والقصر', 'فرص لا تنتهي'], cons: ['منافسون كثيرون', 'لا أحد يعرفك'], issues: I(70, 60, 55, 30, 75), budgetScale: 4 },
  { id: 'salt', name: 'السلط', region: 'الوسط', lon: 35.73, lat: 32.04, district: 'لواء البلقاء', character: 'مدينة سياسية عريقة قرب العاصمة', difficulty: 'متوسطة', pros: ['قريبة من عمّان: فرص في العاصمة', 'عائلتك معروفة هنا'], cons: ['شحّ المياه في الصيف', 'عائلات وجيهة تتنافس على المجلس'], issues: I(82, 45, 50, 20, 55), budgetScale: 1 },
  { id: 'zarqa', name: 'الزرقاء', region: 'الوسط', lon: 36.09, lat: 32.07, district: 'لواء عمّان', character: 'مدينة المعسكرات — الضبّاط في كلّ مكان', difficulty: 'متوسطة', pros: ['صلات بالجيش', 'مدينة تنمو بسرعة'], cons: ['مخيّمات مكتظّة', 'السياسة فيها عسكرية'], issues: I(65, 70, 55, 35, 70), budgetScale: 1.3 },
  { id: 'madaba', name: 'مادبا', region: 'الوسط', lon: 35.79, lat: 31.72, district: 'لواء البلقاء', character: 'بلدة زراعية هادئة، تجّار ومزارعون', difficulty: 'سهلة', pros: ['منافسة قليلة', 'مجتمع متماسك'], cons: ['بعيدة عن الأضواء', 'ميزانية صغيرة'], issues: I(60, 35, 60, 15, 30), budgetScale: 0.6 },
  { id: 'irbid', name: 'إربد', region: 'الشمال', lon: 35.85, lat: 32.55, district: 'لواء عجلون', character: 'سهول القمح وأكبر مدن الشمال', difficulty: 'متوسطة', pros: ['قاعدة انتخابية كبيرة', 'زراعة غنيّة'], cons: ['الجفاف يضرب المحصول', 'قرب الحدود السورية'], issues: I(55, 50, 60, 30, 50), budgetScale: 1.4 },
  { id: 'mafraq', name: 'المفرق', region: 'الشمال', lon: 36.21, lat: 32.34, district: 'لواء عجلون', character: 'بوابة البادية والحدود مع سوريا', difficulty: 'سهلة', pros: ['عشائر البادية', 'تهريب يمكن ضبطه… أو استغلاله'], cons: ['فقر وخدمات قليلة'], issues: I(70, 55, 70, 45, 25), budgetScale: 0.5 },
  { id: 'jerash', name: 'جرش', region: 'الشمال', lon: 35.9, lat: 32.28, district: 'لواء عجلون', character: 'بلدة الآثار والبساتين', difficulty: 'سهلة', pros: ['هادئة', 'بساتين وزيتون'], cons: ['صغيرة'], issues: I(45, 40, 55, 15, 30), budgetScale: 0.5 },
  { id: 'karak', name: 'الكرك', region: 'الجنوب', lon: 35.7, lat: 31.18, district: 'لواء الكرك', character: 'القلعة والعشائر الكبرى', difficulty: 'متوسطة', pros: ['عشائر قويّة', 'تاريخ سياسي'], cons: ['بعيدة عن المركز', 'تنافس عشائري حادّ'], issues: I(60, 45, 65, 30, 20), budgetScale: 0.8 },
  { id: 'maan', name: 'معان', region: 'الجنوب', lon: 35.73, lat: 30.19, district: 'لواء معان', character: 'محطة على سكة الحجاز، بعيدة عن المركز', difficulty: 'سهلة', pros: ['سكة الحجاز', 'منافسة قليلة'], cons: ['بعيدة جداً عن عمّان'], issues: I(65, 50, 70, 35, 15), budgetScale: 0.6 },
  { id: 'aqaba', name: 'العقبة', region: 'الجنوب', lon: 35.0, lat: 29.53, district: 'لواء معان', character: 'منفذ المملكة الوحيد على البحر', difficulty: 'سهلة', pros: ['الميناء سينمو', 'تجارة'], cons: ['بلدة صغيرة نائية'], issues: I(55, 40, 60, 25, 15), budgetScale: 0.5 },
];
export const MUNICIPALITY = Object.fromEntries(MUNICIPALITIES.map((m) => [m.id, m])) as Record<string, MunicipalityDef>;

/** Other towns shown on the map (not selectable as a start). */
export const OTHER_TOWNS: { name: string; lon: number; lat: number; westBank?: boolean; neighbour?: boolean }[] = [
  { name: 'الرمثا', lon: 36.01, lat: 32.56 }, { name: 'عجلون', lon: 35.75, lat: 32.33 }, { name: 'الطفيلة', lon: 35.6, lat: 30.84 },
  { name: 'الشوبك', lon: 35.56, lat: 30.52 }, { name: 'وادي موسى', lon: 35.48, lat: 30.32 }, { name: 'الأزرق', lon: 36.82, lat: 31.83 },
  { name: 'القطرانة', lon: 36.05, lat: 31.25 }, { name: 'ذيبان', lon: 35.75, lat: 31.5 }, { name: 'الرويشد', lon: 38.2, lat: 32.5 },
  { name: 'المدوّرة', lon: 36.03, lat: 29.32 },
  { name: 'القدس', lon: 35.23, lat: 31.78, westBank: true }, { name: 'نابلس', lon: 35.26, lat: 32.22, westBank: true },
  { name: 'الخليل', lon: 35.1, lat: 31.53, westBank: true }, { name: 'جنين', lon: 35.3, lat: 32.46, westBank: true },
  { name: 'رام الله', lon: 35.2, lat: 31.9, westBank: true }, { name: 'أريحا', lon: 35.45, lat: 31.86, westBank: true },
  { name: 'طولكرم', lon: 35.03, lat: 32.31, westBank: true },
  { name: 'دمشق', lon: 36.29, lat: 33.51, neighbour: true }, { name: 'حيفا', lon: 34.99, lat: 32.79, neighbour: true },
  { name: 'تل أبيب', lon: 34.78, lat: 32.08, neighbour: true }, { name: 'غزة', lon: 34.47, lat: 31.5, neighbour: true },
  { name: 'بئر السبع', lon: 34.79, lat: 31.25, neighbour: true }, { name: 'إيلات', lon: 34.95, lat: 29.56, neighbour: true },
];

export const MALE_NAMES = ['محمد', 'أحمد', 'خالد', 'عمر', 'سليم', 'فيصل', 'سامي', 'نبيل', 'عادل', 'ماجد', 'فارس', 'زياد', 'حسن', 'إبراهيم', 'يوسف', 'رياض', 'منصور', 'طارق', 'جمال', 'وليد', 'هاني', 'صالح', 'عيسى', 'نايف', 'راشد', 'غازي', 'كمال', 'مروان', 'سعيد', 'باسم'];
export const FEMALE_NAMES = ['فاطمة', 'عائشة', 'سلمى', 'ليلى', 'هند', 'نوال', 'سميرة', 'مريم', 'رقيّة', 'سعاد'];
export const KUNYA = ['أبو خليل', 'أبو محمود', 'أبو سالم', 'أبو جورج', 'أبو فهد', 'أبو نضال', 'أبو زيد', 'أبو عمر'];
