// Player actions outside events: the permit desk, the network, the council.
import type { Effect } from './effects';
import { applyEffects } from './effects';
import { addOpinion, hasTrait, log, opinionOf } from './helpers';
import { PERMIT_TEMPLATES, type DeskAction } from './permits';
import { nextRandom } from './rng';
import type { GameState, Person } from './types';

export interface ActionResult { ok: boolean; message: string }

// ------------------------------------------------------------ permit desk
export function deskAction(s: GameState, permitId: string, action: DeskAction): ActionResult {
  const m = s.municipality;
  const permit = m.permits.find((p) => p.id === permitId);
  if (!permit) return { ok: false, message: 'الطلب غير موجود' };
  if (s.player.office !== 'clerk') return { ok: false, message: 'لم يعد مكتب الطلبات من عملك' };
  if (action === 'delay') {
    log(s, `أجّلت طلب ${permit.applicant}: ${permit.kind}.`);
    permit.tags = permit.tags.filter((t) => t.text !== 'مؤجَّل');
    permit.tags.push({ text: 'مؤجَّل', tone: 'blue' });
    return { ok: true, message: 'أُجّل الطلب إلى الأسبوع القادم' };
  }
  if (s.permitsLeft <= 0) return { ok: false, message: 'لا وقت لطلبات أخرى هذا الأسبوع' };
  const effects = PERMIT_TEMPLATES[permit.template].effects[action];
  if (!effects) return { ok: false, message: 'لا يمكن هذا الإجراء' };
  s.permitsLeft--;
  m.permits = m.permits.filter((p) => p.id !== permitId);
  applyEffects(s, effects, { person: permit.personId ?? '' });
  if (action === 'lose' && nextRandom(s) < 0.2) {
    applyEffects(s, [{ t: 'scandal', v: 6 }]);
    log(s, 'لاحظ أحدهم أنّ الملف اختفى من مكتبك.');
  }
  const verb = { approve: 'أنجزت', lose: 'أضعت ملف', escalate: 'رفعت إلى الرئيس', report: 'أبلغت الشرطة عن', delay: 'أجّلت' }[action];
  log(s, `${verb} طلب ${permit.applicant}: ${permit.kind}.`);
  return { ok: true, message: `${verb} الطلب` };
}

// ------------------------------------------------------------ network
export type NetAction = 'visit' | 'gift' | 'sponsor' | 'dig' | 'lobby' | 'callFavor' | 'repay';

export interface NetActionInfo {
  id: NetAction;
  label: string;
  hint: string;
  tone: 'green' | 'gold' | 'red';
  locked?: string;
}

export function networkActions(s: GameState, personId: string): NetActionInfo[] {
  const p = s.people[personId];
  if (!p || personId === 'me') return [];
  const op = opinionOf(p);
  const ap = s.actionPoints;
  const out: NetActionInfo[] = [];
  const noAp = ap <= 0 ? 'لا نقاط فعل هذا الأسبوع' : undefined;
  out.push({ id: 'visit', label: 'زُره وقوِّ العلاقة', hint: 'رأيه +، تعتمد على الكاريزما', tone: 'green', locked: noAp });
  out.push({ id: 'gift', label: 'قدّم له هديّة', hint: '−8 د. · رأيه +10', tone: 'green', locked: noAp ?? (s.player.wealth < 8 ? 'لا تملك 8 دنانير' : undefined) });
  if (['patron', 'mayor', 'mukhtar', 'doctor', 'teacher', 'member1', 'member2'].includes(personId) && !p.sponsor) {
    out.push({ id: 'sponsor', label: 'اطلب دعمه لترشّحك', hint: 'يحتاج رأيه فيك +50', tone: 'gold', locked: noAp ?? (op < 50 ? `رأيه الآن ${op >= 0 ? '+' : ''}${op}` : undefined) });
  }
  const vote = s.municipality.vote;
  if (vote && !vote.resolved && vote.positions[personId] && vote.positions[personId] !== 'for' && personId !== 'mayor') {
    out.push({ id: 'lobby', label: `أقنعه بالتصويت على «${vote.title}»`, hint: 'تعتمد على الدبلوماسية', tone: 'gold', locked: noAp });
  }
  if (s.player.favorsOwedToMe.some((f) => f.personId === personId)) {
    out.push({ id: 'callFavor', label: 'اطلب منه ردّ الفضل', hint: vote && !vote.resolved && vote.positions[personId] ? 'يصوّت معك' : 'رأيه لا ينقص · تستهلك الفضل', tone: 'gold', locked: noAp });
  }
  if (s.player.favorsIOwe.some((f) => f.personId === personId)) {
    out.push({ id: 'repay', label: 'اعرض أن تردّ له الجميل', hint: 'قد يطلب شيئاً صعباً', tone: 'gold', locked: noAp });
  }
  if (!s.player.filesHeld.includes(personId) && p.tie !== 'family') {
    out.push({ id: 'dig', label: 'ابحث عن أسراره', hint: 'دهاء · مخاطرة', tone: 'red', locked: noAp });
  }
  return out;
}

export function networkAction(s: GameState, personId: string, action: NetAction): ActionResult {
  const info = networkActions(s, personId).find((a) => a.id === action);
  if (!info) return { ok: false, message: 'غير متاح' };
  if (info.locked) return { ok: false, message: info.locked };
  const p = s.people[personId];
  s.actionPoints--;
  const st = s.player.stats;
  const roll = nextRandom(s);
  const eff: Effect[] = [];
  let message = '';
  switch (action) {
    case 'visit': {
      const gain = 4 + Math.round(st.charisma / 3) + (hasTrait(s, 'generous') ? 2 : 0);
      addOpinion(p, gain, 'زيارات ودّية', 26);
      eff.push({ t: 'xp', k: 'charisma', v: 15 }, { t: 'wealth', v: -1 });
      message = `زرت ${p.name}. رأيه فيك +${gain}.`;
      break;
    }
    case 'gift':
      addOpinion(p, 10, 'هدايا', 52);
      eff.push({ t: 'wealth', v: -8 });
      message = `قدّمت هديّة إلى ${p.name}.`;
      break;
    case 'sponsor':
      p.sponsor = true;
      if (!s.player.patronId) s.player.patronId = personId;
      eff.push({ t: 'favorIOwe', who: personId, size: 'small', reason: 'دعم ترشّحك' });
      message = `وعدك ${p.name} بدعم ترشّحك.`;
      break;
    case 'lobby': {
      const pChance = Math.min(0.9, 0.2 + st.diplomacy * 0.035 + opinionOf(p) / 200);
      if (roll < pChance) {
        s.municipality.vote!.positions[personId] = 'for';
        s.flags.helpedVote = true;
        addOpinion(p, 3, 'حوار مفيد', 26);
        eff.push({ t: 'xp', k: 'diplomacy', v: 40 });
        message = `اقتنع ${p.name} وسيصوّت مع المشروع.`;
      } else {
        addOpinion(p, -4, 'ألحّ عليّ', 26);
        eff.push({ t: 'xp', k: 'diplomacy', v: 15 });
        message = `لم يقتنع ${p.name}.`;
      }
      break;
    }
    case 'callFavor': {
      const i = s.player.favorsOwedToMe.findIndex((f) => f.personId === personId);
      s.player.favorsOwedToMe.splice(i, 1);
      const vote = s.municipality.vote;
      if (vote && !vote.resolved && vote.positions[personId]) {
        vote.positions[personId] = 'for';
        s.flags.helpedVote = true;
        message = `ردّ ${p.name} الفضل: سيصوّت معك.`;
      } else {
        addOpinion(p, 0, 'ردّ الفضل');
        eff.push({ t: 'rep', v: 2, scope: 'notables' });
        message = `ردّ ${p.name} الفضل بتزكيتك عند الوجهاء.`;
      }
      break;
    }
    case 'repay': {
      const i = s.player.favorsIOwe.findIndex((f) => f.personId === personId);
      const big = s.player.favorsIOwe[i].size === 'large';
      if (big && personId === 'patron' && !s.firedOnce.includes('patronFavor')) {
        s.flags.queued_patronFavor = s.week + 1;
        message = `سيستدعيك ${p.name} قريباً ليطلب ما يريد.`;
        s.actionPoints++; // no cost: the event carries the cost
      } else {
        s.player.favorsIOwe.splice(i, 1);
        eff.push({ t: 'wealth', v: big ? -15 : -5 }, { t: 'stress', v: -3 });
        addOpinion(p, 8, 'وفى بالجميل', 104);
        message = `رددت الجميل إلى ${p.name}.`;
      }
      break;
    }
    case 'dig': {
      const pChance = Math.min(0.85, 0.15 + st.intrigue * 0.03 + (hasTrait(s, 'deceitful') ? 0.1 : 0));
      if (roll < pChance) {
        s.player.filesHeld.push(personId);
        p.known = secretFor(p);
        eff.push({ t: 'xp', k: 'intrigue', v: 50 });
        message = `وجدت شيئاً عن ${p.name}: ${p.known}`;
      } else {
        addOpinion(p, -20, 'تجسّس عليّ', 104);
        eff.push({ t: 'scandal', v: 5 }, { t: 'xp', k: 'intrigue', v: 15 });
        message = `انكشف بحثك. ${p.name} غاضب.`;
      }
      break;
    }
  }
  applyEffects(s, eff);
  log(s, message);
  return { ok: true, message };
}

function secretFor(p: Person): string {
  const bank: Record<string, string> = {
    mayor: 'يحصل على عمولة من مقاول طريق السوق.',
    rival: 'زوّر شهادة الخبرة التي قدّمها للبلدية.',
    member1: 'سجّل أرضاً للدولة باسم ابنه.',
    member2: 'يهرّب الأقمشة من سوريا دون رسوم.',
    merchant: 'يخلط الطحين بالنخالة ويبيعه بسعر الأبيض.',
    police: 'يغضّ الطرف عن مقامرة في مقهى معروف.',
    doctor: 'يعالج فقراء الحيّ مجاناً ويأخذ الدواء من مستوصف الحكومة.',
    teacher: 'عضو سرّي في حلقة قومية.',
    mukhtar: 'يأخذ «هديّة» على كلّ شهادة يوقّعها.',
    patron: 'وضع يده على أرض مشاع للعشيرة.',
    friend: 'مدين لتاجر بمبلغ كبير.',
  };
  return bank[p.id] ?? 'لديه دين قديم يخفيه.';
}
