// Event content for the 1953 start. Each event is plain data plus small functions.
import { weekOf } from './calendar';
import type { Effect } from './effects';
import type { EventDef } from './events';
import { hasTrait, opinionOf } from './helpers';
import type { GameState } from './types';

const op = (s: GameState, id: string) => (s.people[id] ? opinionOf(s.people[id]) : 0);
const isClerk = (s: GameState) => s.player.office === 'clerk';
const tookBribe = (s: GameState) => !!s.flags.tookBribe;
const nature = (s: GameState, ...traits: string[]) => (traits.some((t) => hasTrait(s, t)) ? 'يناسب طبعك' : null);
const against = (s: GameState, ...traits: string[]) => (traits.some((t) => hasTrait(s, t)) ? 'ضدّ طبعك · ضغط +' : null);

export const EVENTS: EventDef[] = [
  // ------------------------------------------------------------ opening week
  {
    id: 'kingNews', title: 'الملك الشاب يتولّى سلطاته الدستورية', tags: [], illustration: 'news', newsOnly: true,
    trigger: { week: 1 },
    text: () => 'أقسم الملك حسين بن طلال اليمين الدستورية أمام مجلس الأمّة اليوم، بعد أن بلغ الثامنة عشرة. الناس في المقاهي يتساءلون عمّا سيتغيّر.',
    deadline: 0, defaultOption: 'ok', options: [{ id: 'ok', text: '', effects: () => [] }],
  },
  {
    id: 'mulkiNews', title: 'فوزي الملقي يشكّل حكومة جديدة', tags: [], illustration: 'news', newsOnly: true,
    trigger: { week: 2 },
    text: () => 'كلّف الملك فوزي الملقي بتشكيل أوّل حكومة في عهده. تتحدّث الصحف عن انفتاح سياسي وحرّية أوسع للصحافة.',
    deadline: 0, defaultOption: 'ok', options: [{ id: 'ok', text: '', effects: () => [{ t: 'faction', k: 'nationalists', v: 2 }] }],
  },
  {
    id: 'envelope', title: 'ظرفٌ على المكتب',
    tags: [{ text: 'قرار مطلوب', tone: 'gold' }, { text: 'البلدية', tone: 'blue' }, { text: 'رشوة', tone: 'red' }],
    illustration: 'desk', trigger: { week: 1 },
    text: (s) => `دخل {name:merchant} مكتبك قبيل الظهر، وجلس من غير أن يُدعى. تحدّث عن الطقس وعن غلاء الطحين، ثم وضع ظرفاً بنّيّاً على الأوراق أمامك وقال: «الترخيص يا أستاذ، والله يرضى عليك».\n\nفي الظرف عشرة دنانير، أي أكثر من راتبك في ثلاثة أسابيع. ودكّانه ينتظر الترخيص منذ شهرين، والملف كامل لا ينقصه شيء.${s ? '' : ''}`,
    involved: () => ['merchant'], whoKnows: (s) => `${s.people.merchant.name} وحده`, exposure: () => 'low',
    deadline: 2, defaultOption: 'silence', defaultNote: 'إن لم تقرّر خلال أسبوعين، يعتبر أبو خليل صمتك رفضاً.',
    options: [
      {
        id: 'accept', text: '«على راسي يا أبو خليل». تقبل الظرف وتسرّع الترخيص.',
        effects: (s) => [
          { t: 'wealth', v: 10 }, { t: 'opinion', who: 'merchant', v: 20, reason: 'سرّعت ترخيصه مقابل هديته', weeks: 104 },
          { t: 'favorToMe', who: 'merchant', size: 'small', reason: 'الترخيص' }, { t: 'stat', k: 'integrity', v: -2 },
          { t: 'scandal', v: 10 }, { t: 'flag', k: 'tookBribe', v: true }, { t: 'removePermit', id: permitOf(s, 'merchant') },
          { t: 'queueEvent', id: 'merchantReturns', delay: 5 }, { t: 'hiddenRisk', text: 'نتائج خفيّة ؟' },
        ],
        note: (s) => against(s, 'honest'),
      },
      {
        id: 'refuse', text: '«ما بيصير يا عمّي». تردّ الظرف بأدب، وتسرّع الترخيص على أيّ حال.',
        effects: (s) => [
          { t: 'opinion', who: 'merchant', v: 10, reason: 'أنجزت ترخيصه بلا مقابل', weeks: 104 }, { t: 'favorToMe', who: 'merchant', size: 'small', reason: 'الترخيص' },
          { t: 'xp', k: 'integrity', v: 50 }, { t: 'rep', v: 2 }, { t: 'removePermit', id: permitOf(s, 'merchant') },
        ],
        note: (s) => nature(s, 'honest', 'patient') ?? (hasTrait(s, 'greedy') ? 'ضدّ طبعك · ضغط +' : 'يناسب طبعك'),
      },
      {
        id: 'report', text: 'تأخذ الظرف إلى رئيس البلدية وتشرح له ما جرى.',
        effects: () => [
          { t: 'opinion', who: 'mayor', v: 15, reason: 'أمانتك', weeks: 156 }, { t: 'xp', k: 'integrity', v: 100 },
          { t: 'tie', who: 'merchant', tie: 'rival' }, { t: 'opinion', who: 'merchant', v: -40, reason: 'فضحتني عند الرئيس' },
          { t: 'mood', k: 'merchants', v: -5 }, { t: 'stress', v: 5 },
        ],
      },
      {
        id: 'more', text: '«الملف فيه نواقص…». تلمّح إلى أنّ المبلغ لا يكفي.',
        requires: (s) => (hasTrait(s, 'greedy') || s.player.stats.intrigue >= 13 ? null : `يتطلّب سمة «جشع» أو دهاء 13 (لديك ${s.player.stats.intrigue})`),
        effects: (s) => [
          { t: 'wealth', v: 20 }, { t: 'opinion', who: 'merchant', v: -10, reason: 'ابتززتني', weeks: 104 }, { t: 'stat', k: 'integrity', v: -3 },
          { t: 'scandal', v: 18 }, { t: 'flag', k: 'tookBribe', v: true }, { t: 'removePermit', id: permitOf(s, 'merchant') },
        ],
      },
      {
        id: 'silence', text: 'تترك الظرف على المكتب ولا تقول شيئاً.', requires: () => 'يحدث تلقائياً إن انقضت المهلة',
        effects: () => [{ t: 'opinion', who: 'merchant', v: -10, reason: 'تجاهلتني', weeks: 52 }],
      },
    ],
  },
  {
    id: 'merchantReturns', title: 'أبو خليل يعود', tags: [{ text: 'رشوة', tone: 'red' }], illustration: 'desk',
    trigger: { when: tookBribe },
    text: () => 'عاد {name:merchant} وفي يده ظرف أسمك. «عندي ابن عمّ يريد رخصة فرن في حيّ السوق. الأوراق ناقصة قليلاً… لكنّك تعرف كيف تُرتَّب الأمور».\n\nالرخصة دون الشروط الصحّية الكاملة. لو انكشف الأمر، فاسمك على الملف.',
    involved: () => ['merchant'], whoKnows: () => 'أبو خليل وابن عمّه', exposure: () => 'medium',
    deadline: 2, defaultOption: 'refuse',
    options: [
      { id: 'take', text: 'تأخذ الظرف وترتّب الرخصة.', effects: () => [{ t: 'wealth', v: 15 }, { t: 'scandal', v: 15 }, { t: 'stat', k: 'integrity', v: -2 }, { t: 'opinion', who: 'merchant', v: 15, reason: 'شريك موثوق', weeks: 104 }, { t: 'hiddenRisk', text: 'الملف يحمل اسمك' }] },
      { id: 'refuse', text: '«المرّة الماضية كانت الأخيرة».', effects: () => [{ t: 'opinion', who: 'merchant', v: -15, reason: 'صرت تتعالى', weeks: 52 }, { t: 'scandal', v: 4 }, { t: 'hiddenRisk', text: 'قد يتكلّم' }] },
      {
        id: 'file', text: 'ترفض، وتحتفظ بنسخة من طلبه لنفسك.',
        requires: (s) => (s.player.stats.intrigue >= 10 ? null : 'يتطلّب دهاء 10'),
        effects: () => [{ t: 'file', who: 'merchant' }, { t: 'known', who: 'merchant', text: 'طلب رخصة فرن مخالفة لابن عمّه. لديك نسخة من الطلب.' }, { t: 'opinion', who: 'merchant', v: -10, reason: 'رفضت', weeks: 52 }, { t: 'xp', k: 'intrigue', v: 40 }],
      },
    ],
  },
  {
    id: 'mukhtarDinner', title: 'دعوة إلى الديوان', tags: [{ text: 'علاقات', tone: 'blue' }], illustration: 'diwan',
    trigger: { week: 2 },
    text: () => 'وصلتك ورقة بخطّ {name:mukhtar}: «عشاء في ديوان العائلة يوم الجمعة، وسيحضر وجهاء الحيّ».\n\nحضورك يعني أن يراك الناس بين الكبار. وغيابك سيُلاحَظ.',
    involved: () => ['mukhtar'], deadline: 1, defaultOption: 'skip',
    options: [
      { id: 'go', text: 'تحضر ومعك هديّة متواضعة.', effects: () => [{ t: 'wealth', v: -2 }, { t: 'opinion', who: 'mukhtar', v: 12, reason: 'حضرت عشاءه', weeks: 52 }, { t: 'rep', v: 2, scope: 'notables' }, { t: 'rep', v: 1 }, { t: 'xp', k: 'charisma', v: 25 }] },
      { id: 'speech', text: 'تحضر وتتكلّم عن أزمة المياه أمام الوجهاء.', effects: () => [{ t: 'opinion', who: 'mukhtar', v: 8, reason: 'حضرت عشاءه', weeks: 52 }, { t: 'rep', v: 4, scope: 'notables' }, { t: 'xp', k: 'charisma', v: 40 }, { t: 'opinion', who: 'mayor', v: -3, reason: 'تكلّم عن المياه علناً', weeks: 26 }], note: (s) => nature(s, 'hotTempered', 'ambitious') },
      { id: 'skip', text: 'تعتذر بلطف، فعندك عمل.', effects: () => [{ t: 'opinion', who: 'mukhtar', v: -6, reason: 'لم يحضر', weeks: 26 }] },
    ],
  },
  // ------------------------------------------------------------ family
  {
    id: 'brotherJob', title: 'أخوك يريد وظيفة', tags: [{ text: 'العائلة', tone: 'blue' }, { text: 'واسطة', tone: 'gold' }], illustration: 'home',
    trigger: { minWeek: 5, chance: 0.25 },
    text: () => 'جلس {name:brother} قبالتك بعد العشاء، وأمّك تراقب من المطبخ. «أنهيت المدرسة. كلّ أصحابي وجدوا وظائف عبر أقاربهم. أنت في البلدية… ألا تستطيع شيئاً؟»',
    involved: () => ['brother', 'mother'], deadline: 2, defaultOption: 'refuse',
    options: [
      { id: 'mayor', text: 'تطلب من رئيس البلدية وظيفة له.', requires: (s) => (op(s, 'mayor') >= 15 ? null : 'يحتاج رأي الرئيس فيك +15'), effects: () => [{ t: 'opinion', who: 'mayor', v: -6, reason: 'طلب وظيفة لأخيه', weeks: 52 }, { t: 'opinion', who: 'brother', v: 20, reason: 'وجد له عملاً', weeks: 156 }, { t: 'opinion', who: 'mother', v: 10, reason: 'ساعد أخاه', weeks: 104 }, { t: 'favorIOwe', who: 'mayor', size: 'small', reason: 'وظيفة أخيك' }, { t: 'scandal', v: 2 }] },
      { id: 'patron', text: 'تطلب من الراعي أن يجد له عملاً.', requires: (s) => (op(s, 'patron') >= 30 ? null : 'يحتاج رأي الراعي فيك +30'), effects: () => [{ t: 'opinion', who: 'brother', v: 15, reason: 'وجد له عملاً', weeks: 156 }, { t: 'favorIOwe', who: 'patron', size: 'small', reason: 'وظيفة أخيك' }, { t: 'opinion', who: 'mother', v: 8, reason: 'ساعد أخاه', weeks: 104 }] },
      { id: 'refuse', text: '«ابحث بنفسك، هكذا يُبنى الرجال».', effects: (s) => [{ t: 'opinion', who: 'brother', v: -15, reason: 'لم يساعده', weeks: 104 }, { t: 'opinion', who: 'mother', v: -8, reason: 'قسا على أخيه', weeks: 52 }, { t: 'stress', v: hasTrait(s, 'generous') ? 8 : 3 }], note: (s) => nature(s, 'honest') },
    ],
  },
  {
    id: 'marriage', title: 'أمّك تقترح عروساً', tags: [{ text: 'العائلة', tone: 'blue' }, { text: 'تحالف', tone: 'gold' }], illustration: 'home',
    trigger: { minWeek: 10, chance: 0.12, when: (s) => !s.player.married },
    text: () => '«ابنة عائلة محترمة، والدها من وجهاء المدينة»، قالت {name:mother}. «الزواج يا ابني ليس بين شخصين فقط، بل بين عائلتين».\n\nالعرس يكلّف، لكنّ النسب يفتح أبواباً.',
    involved: () => ['mother'], deadline: 4, defaultOption: 'later',
    options: [
      { id: 'yes', text: 'توافق، وتبدأ ترتيبات الخطبة.', effects: () => [{ t: 'wealth', v: -35 }, { t: 'flag', k: 'married', v: true }, { t: 'rep', v: 6, scope: 'notables' }, { t: 'faction', k: 'tribes', v: 3 }, { t: 'opinion', who: 'mother', v: 20, reason: 'تزوّج', weeks: 520 }, { t: 'stress', v: -8 }] },
      { id: 'later', text: '«ليس الآن يا أمّي، بعد أن أستقرّ».', effects: () => [{ t: 'opinion', who: 'mother', v: -4, reason: 'أجّل الزواج', weeks: 52 }] },
      { id: 'no', text: 'ترفض. ستختار بنفسك.', effects: () => [{ t: 'opinion', who: 'mother', v: -12, reason: 'رفض العروس', weeks: 104 }, { t: 'rep', v: -2, scope: 'notables' }] },
    ],
  },
  {
    id: 'friendLoan', title: 'صديق في ضيق', tags: [{ text: 'صداقة', tone: 'blue' }], illustration: 'street',
    trigger: { minWeek: 6, chance: 0.1 },
    text: () => 'جاءك {name:friend} على غير عادته، خافت الصوت. «عليّ دين للخيّاط وللبقّال، وراتبي تأخّر. عشرون ديناراً فقط، وأردّها خلال أشهر».',
    involved: () => ['friend'], deadline: 2, defaultOption: 'no',
    options: [
      { id: 'lend', text: 'تقرضه المبلغ كاملاً.', requires: (s) => (s.player.wealth >= 20 ? null : 'لا تملك 20 ديناراً'), effects: () => [{ t: 'wealth', v: -20 }, { t: 'opinion', who: 'friend', v: 18, reason: 'أقرضني وقت الضيق', weeks: 260 }, { t: 'favorToMe', who: 'friend', size: 'small', reason: 'القرض' }, { t: 'flag', k: 'friendDebt', v: 20 }] },
      { id: 'half', text: 'تعطيه عشرة، وتعتذر عن الباقي.', requires: (s) => (s.player.wealth >= 10 ? null : 'لا تملك 10 دنانير'), effects: () => [{ t: 'wealth', v: -10 }, { t: 'opinion', who: 'friend', v: 6, reason: 'ساعدني قليلاً', weeks: 104 }] },
      { id: 'no', text: '«والله ما معي».', effects: () => [{ t: 'opinion', who: 'friend', v: -15, reason: 'تخلّى عنّي', weeks: 104 }] },
    ],
  },
  {
    id: 'patronFavor', title: 'الراعي يطلب ردّ الجميل', tags: [{ text: 'فضل', tone: 'gold' }, { text: 'مخالفة', tone: 'red' }], illustration: 'diwan',
    trigger: { minWeek: 7, chance: 0.18, when: (s) => s.player.favorsIOwe.some((f) => f.personId === 'patron') && isClerk(s) },
    text: () => 'استدعاك {name:patron} إلى بيته. بعد القهوة قال: «قريب لنا يبني على أرض فيها خلاف مع البلدية. أريد الترخيص أن يمرّ هذا الشهر… أنت تعرف ما فعلته لك».\n\nالأرض متنازع عليها، والترخيص السريع مخالف.',
    involved: () => ['patron'], whoKnows: () => 'الراعي وقريبه', exposure: () => 'medium', deadline: 2, defaultOption: 'delay',
    options: [
      { id: 'do', text: 'تمرّر الترخيص كما طلب.', effects: () => [{ t: 'repayFavor', who: 'patron' }, { t: 'opinion', who: 'patron', v: 15, reason: 'وفى بالجميل', weeks: 260 }, { t: 'scandal', v: 12 }, { t: 'stat', k: 'integrity', v: -1 }] },
      { id: 'proper', text: 'تعده بأن تسرّع الملف ضمن القانون.', effects: () => [{ t: 'opinion', who: 'patron', v: -5, reason: 'تحايل علينا', weeks: 52 }, { t: 'xp', k: 'diplomacy', v: 50 }, { t: 'xp', k: 'integrity', v: 30 }] },
      { id: 'delay', text: 'تتهرّب من الجواب.', effects: () => [{ t: 'opinion', who: 'patron', v: -12, reason: 'تهرّب', weeks: 104 }] },
    ],
  },
  // ------------------------------------------------------------ rivals and scandal
  {
    id: 'rivalRumor', title: 'إشاعة في السوق', tags: [{ text: 'خصم', tone: 'red' }], illustration: 'street',
    trigger: { minWeek: 5, chance: 0.15, when: (s) => s.people.rival?.tie === 'rival', cooldown: 20, once: false },
    text: (s) => tookBribe(s)
      ? 'يتهامس الناس في السوق أنّ {name:rival} يقول للجميع إنك «تأكل من الطلبات». وهذه المرّة، الكلام قريب من الحقيقة.'
      : 'يتهامس الناس في السوق أنّ {name:rival} يقول للجميع إنك «تأكل من الطلبات». الكلام كذب، لكنّ الكذب يسري أسرع من الحقيقة.',
    involved: () => ['rival'], deadline: 2, defaultOption: 'ignore',
    options: [
      {
        id: 'confront', text: 'تواجهه علناً في المقهى.', effects: () => [{ t: 'rep', v: 4 }, { t: 'opinion', who: 'rival', v: -10, reason: 'أهانني علناً', weeks: 104 }, { t: 'xp', k: 'charisma', v: 40 }],
        risk: { p: (s) => Math.min(0.85, 0.3 + s.player.stats.charisma * 0.04 - (tookBribe(s) ? 0.2 : 0)), fail: () => [{ t: 'rep', v: -6 }, { t: 'stress', v: 6 }], failText: 'خرجت من المواجهة أضعف ممّا دخلت.', successText: 'انقلب الحاضرون على {name:rival}.' },
        note: (s) => nature(s, 'hotTempered', 'brave'),
      },
      { id: 'ignore', text: 'تتجاهل الكلام وتواصل عملك.', effects: (s) => [{ t: 'rep', v: tookBribe(s) ? -6 : -3 }, { t: 'scandal', v: tookBribe(s) ? 5 : 0 }], note: (s) => nature(s, 'patient') },
      {
        id: 'counter', text: 'تنشر إشاعة مضادّة عنه.', requires: (s) => (s.player.stats.intrigue >= 10 ? null : 'يتطلّب دهاء 10'),
        effects: () => [{ t: 'opinion', who: 'rival', v: -10, reason: 'شوّه سمعتي', weeks: 104 }, { t: 'flag', k: 'rivalDamage', v: 6 }, { t: 'xp', k: 'intrigue', v: 40 }],
        risk: { p: (s) => Math.min(0.9, 0.35 + s.player.stats.intrigue * 0.03), fail: () => [{ t: 'rep', v: -8 }, { t: 'scandal', v: 8 }], failText: 'عُرف أنك مصدر الإشاعة.' },
      },
    ],
  },
  {
    id: 'journalist', title: 'صحفيّ يسأل عنك', tags: [{ text: 'فضيحة', tone: 'red' }], illustration: 'street',
    trigger: { minWeek: 4, chance: 0.25, when: (s) => s.player.scandal >= 30, cooldown: 15, once: false },
    text: () => 'مراسل جريدة محلّية يتنقّل بين التجّار ويسأل عن «الكاتب الذي يسرّع الرخص». ترك لك رسالة: يريد «توضيحك» قبل أن يكتب.',
    whoKnows: () => 'المراسل وبعض التجّار', exposure: () => 'high', deadline: 2, defaultOption: 'deny',
    options: [
      { id: 'pay', text: 'تدفع له ليصمت.', requires: (s) => (s.player.wealth >= 15 ? null : 'يحتاج 15 ديناراً'), effects: () => [{ t: 'wealth', v: -15 }, { t: 'scandal', v: -12 }, { t: 'hiddenRisk', text: 'قد يعود ويطلب المزيد' }] },
      {
        id: 'story', text: 'تعطيه قصّة أكبر عن منافسك.', requires: (s) => (s.player.filesHeld.length > 0 ? null : 'تحتاج ملفاً على أحد'),
        effects: () => [{ t: 'scandal', v: -18 }, { t: 'flag', k: 'rivalDamage', v: 10 }, { t: 'xp', k: 'intrigue', v: 50 }],
      },
      {
        id: 'deny', text: 'تنكر كلّ شيء بثقة.', effects: () => [{ t: 'scandal', v: -5 }],
        risk: { p: (s) => Math.min(0.85, 0.25 + s.player.stats.charisma * 0.03 + (100 - s.player.scandal) / 300), fail: () => [{ t: 'scandal', v: 12 }, { t: 'rep', v: -8 }], failText: 'نشر المراسل مقالاً لاذعاً عنك.', successText: 'اقتنع المراسل… هذه المرّة.' },
      },
    ],
  },
  {
    id: 'exposure', title: 'الفضيحة تنكشف', tags: [{ text: 'خطر', tone: 'red' }], illustration: 'council',
    trigger: { minWeek: 3, chance: 0.0, once: false, cooldown: 26 },
    text: () => 'استدعاك {name:mayor} إلى مكتبه، وعلى الطاولة ملفّات تحمل توقيعك. «الناس يتكلّمون، والمتصرّف سأل. ماذا أقول له؟»',
    involved: () => ['mayor'], exposure: () => 'high', deadline: 1, defaultOption: 'resign',
    options: [
      { id: 'resign', text: 'تستقيل قبل أن تُقال.', effects: () => [{ t: 'office', office: 'unemployed' }, { t: 'scandal', v: -45 }, { t: 'rep', v: -12 }, { t: 'stress', v: 15 }, { t: 'log', text: 'استقلت من البلدية.', important: true }] },
      {
        id: 'fight', text: 'تنكر وتطالب بالتحقيق.', effects: () => [{ t: 'scandal', v: -15 }, { t: 'opinion', who: 'mayor', v: -10, reason: 'تحدّاني', weeks: 104 }],
        risk: { p: (s) => Math.min(0.75, 0.15 + s.player.stats.charisma * 0.025 + s.player.stats.intrigue * 0.02), fail: () => [{ t: 'office', office: 'unemployed' }, { t: 'rep', v: -20 }, { t: 'scandal', v: -30 }, { t: 'stress', v: 20 }, { t: 'log', text: 'فُصلت من البلدية بعد التحقيق.', important: true }], failText: 'أثبت التحقيق المخالفات. فُصلت من عملك.', successText: 'لم يجد التحقيق ما يكفي. نجوت.' },
      },
      {
        id: 'patron', text: 'تطلب من راعيك أن يتدخّل.', requires: (s) => (op(s, 'patron') >= 45 ? null : 'يحتاج رأي الراعي فيك +45'),
        effects: () => [{ t: 'scandal', v: -35 }, { t: 'favorIOwe', who: 'patron', size: 'large', reason: 'أنقذك من الفضيحة' }, { t: 'opinion', who: 'mayor', v: -5, reason: 'ضغط عليّ', weeks: 52 }],
      },
    ],
  },
  // ------------------------------------------------------------ the town
  {
    id: 'summerDrought', title: 'صيف بلا ماء', tags: [{ text: 'أزمة', tone: 'red' }, { text: 'المياه', tone: 'blue' }], illustration: 'street',
    trigger: { minWeek: 9, maxWeek: 16, chance: 0.4, when: (s) => s.municipality.projects.find((p) => p.id === 'water')?.status !== 'underway' },
    text: () => 'جفّت حنفيات الأحياء العالية منذ أسبوع. النساء يحملن الجرار من العين، والناس يقفون أمام البلدية يسألون: أين الماء؟\n\nأنت أوّل موظف يرونه حين يدخلون.',
    deadline: 1, defaultOption: 'nothing',
    options: [
      { id: 'organize', text: 'تنظّم توزيع الماء بالصهاريج على الأحياء.', effects: () => [{ t: 'rep', v: 5 }, { t: 'issue', k: 'water', v: -4 }, { t: 'xp', k: 'administration', v: 50 }, { t: 'stress', v: 4 }, { t: 'mood', k: 'palestinians', v: 3 }] },
      { id: 'blame', text: 'تقول للناس إنّ المجلس لم يصوّت على الخزّان.', effects: () => [{ t: 'rep', v: 2 }, { t: 'opinion', who: 'mayor', v: -8, reason: 'ألقى اللوم علينا', weeks: 52 }, { t: 'opinion', who: 'teacher', v: 6, reason: 'قال الحقيقة', weeks: 52 }] },
      { id: 'nothing', text: 'هذا ليس من عملك.', effects: () => [{ t: 'rep', v: -4 }, { t: 'issue', k: 'water', v: 5 }] },
    ],
  },
  {
    id: 'teacherSchool', title: 'مدرسة للبنات', tags: [{ text: 'مشروع', tone: 'blue' }], illustration: 'council',
    trigger: { minWeek: 8, chance: 0.12 },
    text: () => '{name:teacher} يزورك ومعه أوراق مكتوبة بخطّ دقيق: «مدرسة ثانية للبنات. الأرض موجودة، والكلفة معقولة. أحتاج موظفاً يعرف الأرقام ليساعدني في الطلب».',
    involved: () => ['teacher'], deadline: 2, defaultOption: 'decline',
    options: [
      { id: 'help', text: 'تساعده في إعداد الطلب ليلاً.', effects: () => [{ t: 'opinion', who: 'teacher', v: 15, reason: 'ساعدني في المدرسة', weeks: 156 }, { t: 'xp', k: 'administration', v: 40 }, { t: 'faction', k: 'nationalists', v: 3 }, { t: 'opinion', who: 'mayor', v: -4, reason: 'يعمل مع المعارضة', weeks: 52 }, { t: 'flag', k: 'schoolPlan', v: true }] },
      { id: 'decline', text: 'تعتذر بلباقة.', effects: () => [{ t: 'opinion', who: 'teacher', v: -4, reason: 'اعتذر', weeks: 26 }] },
    ],
  },
  {
    id: 'illness', title: 'حمّى', tags: [{ text: 'الصحّة', tone: 'red' }], illustration: 'home',
    trigger: { minWeek: 6, chance: 0.02, cooldown: 40, once: false },
    text: () => 'استيقظت والعرق يبلّل الوسادة. الطبيب يقول: راحة أسبوع على الأقلّ.',
    deadline: 1, defaultOption: 'rest',
    options: [
      { id: 'rest', text: 'تلتزم الفراش.', effects: () => [{ t: 'wealth', v: -3 }, { t: 'health', v: 6 }, { t: 'flag', k: 'restWeek', v: true }] },
      { id: 'work', text: 'تذهب إلى العمل رغم الحمّى.', effects: () => [{ t: 'health', v: -10 }, { t: 'stress', v: 6 }, { t: 'opinion', who: 'mayor', v: 3, reason: 'مخلص في عمله', weeks: 26 }] },
    ],
  },
  // ------------------------------------------------------------ elections
  {
    id: 'campaignStart', title: 'باب الترشّح مفتوح', tags: [{ text: 'انتخابات', tone: 'gold' }], illustration: 'council',
    trigger: { week: 15, when: (s) => isClerk(s) },
    text: (s) => `أعلنت المتصرّفية انتخاباً تكميلياً للمقعد الشاغر في المجلس البلدي، بعد أربعة أسابيع.\n\n${s.people.rival.name} أعلن ترشّحه بمباركة الرئيس. والسؤال الآن: هل تدخل السباق؟`,
    deadline: 2, defaultOption: 'no',
    options: [
      { id: 'run', text: 'تترشّح وخلفك من يدعمك.', requires: (s) => (Object.values(s.people).some((p) => p.sponsor) ? null : 'تحتاج داعماً: اطلب الرعاية من شخص رأيه فيك +50'), effects: () => [{ t: 'flag', k: 'running', v: true }, { t: 'log', text: 'ترشّحت للمجلس البلدي.', important: true }, { t: 'stress', v: 5 }] },
      { id: 'alone', text: 'تترشّح مستقلّاً بلا داعم.', effects: () => [{ t: 'flag', k: 'running', v: true }, { t: 'flag', k: 'noSponsor', v: true }, { t: 'log', text: 'ترشّحت للمجلس البلدي بلا داعم.', important: true }, { t: 'stress', v: 8 }] },
      { id: 'no', text: 'ليس هذه المرّة.', effects: () => [{ t: 'flag', k: 'running', v: false }] },
    ],
  },
  {
    id: 'councilTax', title: 'ضريبة السوق', tags: [{ text: 'المجلس', tone: 'blue' }], illustration: 'council',
    trigger: { minWeek: 20, chance: 0.3, when: (s) => s.player.office === 'councilMember' },
    text: () => 'يقترح {name:mayor} رسماً جديداً على دكاكين السوق لتمويل الخزّان. التجّار غاضبون، و{name:teacher} يقترح بدلاً منه ضريبة على الأراضي الكبيرة.\n\nصوتك هو الصوت المرجّح.',
    involved: () => ['mayor', 'teacher'], deadline: 2, defaultOption: 'abstain',
    options: [
      { id: 'mayor', text: 'تصوّت مع رسم السوق.', effects: () => [{ t: 'opinion', who: 'mayor', v: 12, reason: 'صوّت معي', weeks: 104 }, { t: 'mood', k: 'merchants', v: -6 }, { t: 'faction', k: 'merchants', v: -5 }, { t: 'issue', k: 'water', v: -6 }] },
      { id: 'land', text: 'تدعم ضريبة الأراضي.', effects: () => [{ t: 'opinion', who: 'teacher', v: 10, reason: 'صوّت معي', weeks: 104 }, { t: 'opinion', who: 'member1', v: -15, reason: 'يستهدف أرضي', weeks: 104 }, { t: 'faction', k: 'leftists', v: 5 }, { t: 'faction', k: 'tribes', v: -4 }] },
      { id: 'abstain', text: 'تمتنع عن التصويت.', effects: () => [{ t: 'rep', v: -2, scope: 'notables' }] },
    ],
  },
  // ------------------------------------------------------------ history
  {
    id: 'qibya', title: 'مجزرة قبية', tags: [{ text: 'حدث تاريخي', tone: 'red' }], illustration: 'protest',
    trigger: { week: weekOf(1953, 10, 17) },
    text: () => 'وصلت الأخبار من الضفّة الغربية: هجوم إسرائيلي ليلي على قرية قبية قتل العشرات من أهلها. المدينة تغلي، والشباب يتجمّعون أمام الجامع الكبير، وبعضهم يهتف ضدّ قيادة الجيش البريطانية.\n\nالشرطة تراقب من بعيد.',
    deadline: 1, defaultOption: 'stay',
    options: [
      { id: 'march', text: 'تمشي مع المتظاهرين.', effects: () => [{ t: 'faction', k: 'nationalists', v: 8 }, { t: 'faction', k: 'palestinians', v: 6 }, { t: 'opinion', who: 'police', v: -8, reason: 'شارك في المظاهرة', weeks: 104 }, { t: 'palace', v: -3 }, { t: 'rep', v: 3 }], note: (s) => nature(s, 'hotTempered', 'brave') },
      { id: 'relief', text: 'تجمع تبرّعات لأهل القرية.', effects: () => [{ t: 'wealth', v: -8 }, { t: 'rep', v: 5 }, { t: 'faction', k: 'palestinians', v: 8 }, { t: 'mood', k: 'palestinians', v: 5 }, { t: 'xp', k: 'administration', v: 30 }] },
      { id: 'stay', text: 'تبقى في مكتبك.', effects: () => [{ t: 'faction', k: 'nationalists', v: -3 }] },
    ],
  },
  {
    id: 'huda54', title: 'توفيق أبو الهدى يعود إلى رئاسة الحكومة', tags: [], illustration: 'news', newsOnly: true,
    trigger: { week: weekOf(1954, 5, 4) },
    text: () => 'استقالت حكومة الملقي، وعاد توفيق أبو الهدى إلى رئاسة الوزراء. يتوقّع المراقبون قبضة أشدّ على الصحف والأحزاب.',
    deadline: 0, defaultOption: 'ok', options: [{ id: 'ok', text: '', effects: () => [{ t: 'faction', k: 'nationalists', v: -2 }, { t: 'faction', k: 'leftists', v: -2 }] }],
  },
  {
    id: 'baghdadPact', title: 'المدن تشتعل ضدّ حلف بغداد', tags: [{ text: 'حدث تاريخي', tone: 'red' }], illustration: 'protest',
    trigger: { week: weekOf(1955, 12, 17) },
    text: () => 'خرجت مظاهرات عارمة في المدن ضدّ دخول الأردن حلف بغداد. الحكومة تتهاوى، والجيش ينزل إلى الشوارع. في بلدتك أُحرق مكتب حكومي.',
    deadline: 1, defaultOption: 'calm',
    options: [
      { id: 'join', text: 'تعلن رفضك للحلف علناً.', effects: () => [{ t: 'faction', k: 'nationalists', v: 10 }, { t: 'palace', v: -6 }, { t: 'rep', v: 4 }] },
      { id: 'calm', text: 'تعمل على تهدئة الشارع.', effects: () => [{ t: 'palace', v: 4 }, { t: 'opinion', who: 'police', v: 10, reason: 'ساعد في التهدئة', weeks: 104 }, { t: 'faction', k: 'nationalists', v: -5 }, { t: 'xp', k: 'diplomacy', v: 50 }] },
    ],
  },
  {
    id: 'glubb', title: 'الملك يعزل غلوب باشا', tags: [], illustration: 'news', newsOnly: true,
    trigger: { week: weekOf(1956, 3, 1) },
    text: () => 'أعفى الملك حسين الجنرال غلوب باشا من قيادة الجيش العربي، وأمره بمغادرة البلاد خلال ساعات. الضبّاط العرب يتسلّمون القيادة، والناس يحتفلون في الشوارع.',
    deadline: 0, defaultOption: 'ok', options: [{ id: 'ok', text: '', effects: () => [{ t: 'faction', k: 'officers', v: 5 }, { t: 'faction', k: 'nationalists', v: 8 }] }],
  },
];

function permitOf(s: GameState, personId: string): string {
  return s.municipality.permits.find((p) => p.personId === personId)?.id ?? '';
}

export type { Effect };
