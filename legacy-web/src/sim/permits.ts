// The clerk's permit desk: request templates and what each desk action does.
import type { Effect } from './effects';
import { MALE_NAMES } from './data';
import { pick } from './rng';
import type { GameState, Permit } from './types';

export type DeskAction = 'approve' | 'delay' | 'lose' | 'escalate' | 'report';

export interface PermitTemplate {
  id: string;
  kind: string;
  applicant?: string; // fixed display name when there is no person
  tags: Permit['tags'];
  recurring: boolean;
  weight: number;
  effects: Partial<Record<DeskAction, Effect[]>>;
}

export const PERMIT_TEMPLATES: Record<string, PermitTemplate> = {
  shopLicense: {
    id: 'shopLicense', kind: 'ترخيص دكّان في السوق', recurring: false, weight: 0,
    tags: [{ text: 'عرض هدية', tone: 'gold' }, { text: 'حدث مفتوح', tone: 'blue' }],
    effects: {
      approve: [{ t: 'opinion', who: '$person', v: 10, reason: 'أنجزت ترخيصه', weeks: 52 }, { t: 'mood', k: 'merchants', v: 2 }, { t: 'xp', k: 'administration', v: 20 }],
      lose: [{ t: 'opinion', who: '$person', v: -25, reason: 'أضعت ملفه', weeks: 104 }, { t: 'scandal', v: 3 }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 4, reason: 'يحترم التسلسل', weeks: 26 }],
    },
  },
  well: {
    id: 'well', kind: 'حفر بئر لأهل الحيّ', recurring: false, weight: 0,
    tags: [{ text: 'صديق', tone: 'green' }, { text: 'أزمة المياه', tone: 'red' }],
    effects: {
      approve: [{ t: 'opinion', who: '$person', v: 12, reason: 'البئر', weeks: 104 }, { t: 'issue', k: 'water', v: -5 }, { t: 'rep', v: 3 }, { t: 'mood', k: 'palestinians', v: 2 }, { t: 'xp', k: 'administration', v: 20 }],
      lose: [{ t: 'opinion', who: '$person', v: -30, reason: 'خذلته', weeks: 104 }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 3, reason: 'يحترم التسلسل', weeks: 26 }, { t: 'opinion', who: '$person', v: -5, reason: 'تهرّبت', weeks: 26 }],
    },
  },
  widowFee: {
    id: 'widowFee', kind: 'إعفاء من رسوم المياه', applicant: 'أرملة أبي سالم', recurring: false, weight: 0,
    tags: [{ text: 'حالة إنسانية', tone: 'green' }],
    effects: {
      approve: [{ t: 'rep', v: 3 }, { t: 'mood', k: 'clergy', v: 2 }, { t: 'xp', k: 'administration', v: 15 }, { t: 'stress', v: -3 }],
      lose: [{ t: 'rep', v: -4 }, { t: 'stress', v: 4 }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 2, reason: 'يحترم التسلسل', weeks: 26 }],
    },
  },
  busLine: {
    id: 'busLine', kind: 'خطّ باص إلى عمّان', applicant: 'شركة باصات محلّية', recurring: false, weight: 0,
    tags: [{ text: 'يملكها قريب منافسك', tone: 'red' }],
    effects: {
      approve: [{ t: 'opinion', who: '$person', v: 6, reason: 'لم تعرقل خطّه', weeks: 26 }, { t: 'mood', k: 'merchants', v: 2 }, { t: 'rep', v: 1 }, { t: 'xp', k: 'administration', v: 15 }],
      lose: [{ t: 'opinion', who: '$person', v: -15, reason: 'عرقلت خطّه', weeks: 52 }, { t: 'scandal', v: 4 }, { t: 'hiddenRisk', text: 'قد يكتشف أنك أضعته' }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 2, reason: 'يحترم التسلسل', weeks: 26 }],
    },
  },
  hallBooking: {
    id: 'hallBooking', kind: 'قاعة لاجتماع عامّ', applicant: 'جمعية الشباب العربي', recurring: false, weight: 0,
    tags: [{ text: 'القوميون العرب', tone: 'blue' }, { text: 'الشرطة تراقب', tone: 'red' }],
    effects: {
      approve: [{ t: 'faction', k: 'nationalists', v: 6 }, { t: 'mood', k: 'nationalists', v: 4 }, { t: 'opinion', who: 'police', v: -8, reason: 'سمحت باجتماع القوميين', weeks: 52 }, { t: 'xp', k: 'administration', v: 10 }],
      report: [{ t: 'opinion', who: 'police', v: 15, reason: 'أبلغتنا عن الجمعية', weeks: 104 }, { t: 'faction', k: 'nationalists', v: -8 }, { t: 'faction', k: 'leftists', v: -4 }, { t: 'xp', k: 'integrity', v: -20 }, { t: 'favorToMe', who: 'police', size: 'small', reason: 'معلومة عن الجمعية' }],
      lose: [{ t: 'faction', k: 'nationalists', v: -3 }],
    },
  },
  landDispute: {
    id: 'landDispute', kind: 'نزاع على حدود أرض', applicant: 'مزارعان من أطراف المدينة', recurring: false, weight: 0,
    tags: [{ text: 'قضية عشائرية', tone: 'gold' }],
    effects: {
      approve: [{ t: 'xp', k: 'diplomacy', v: 40 }, { t: 'faction', k: 'tribes', v: 2 }, { t: 'rep', v: 2 }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 2, reason: 'يحترم التسلسل', weeks: 26 }],
    },
  },
  building: {
    id: 'building', kind: 'ترخيص بناء بيت', recurring: true, weight: 4,
    tags: [{ text: 'روتيني', tone: 'blue' }],
    effects: {
      approve: [{ t: 'rep', v: 1 }, { t: 'xp', k: 'administration', v: 12 }],
      lose: [{ t: 'rep', v: -2 }],
    },
  },
  garbage: {
    id: 'garbage', kind: 'شكوى من تراكم النفايات', recurring: true, weight: 3,
    tags: [{ text: 'خدمات', tone: 'blue' }],
    effects: {
      approve: [{ t: 'issue', k: 'cleanliness', v: -4 }, { t: 'rep', v: 1 }, { t: 'xp', k: 'administration', v: 10 }],
      lose: [{ t: 'issue', k: 'cleanliness', v: 2 }],
    },
  },
  jobRequest: {
    id: 'jobRequest', kind: 'طلب وظيفة عامل في البلدية', recurring: true, weight: 3,
    tags: [{ text: 'واسطة', tone: 'gold' }],
    effects: {
      approve: [{ t: 'faction', k: 'tribes', v: 1 }, { t: 'rep', v: 1 }, { t: 'xp', k: 'administration', v: 8 }],
      escalate: [{ t: 'opinion', who: 'mayor', v: 2, reason: 'يحترم التسلسل', weeks: 26 }],
    },
  },
  cafeLicense: {
    id: 'cafeLicense', kind: 'رخصة مقهى', recurring: true, weight: 2,
    tags: [{ text: 'علماء الدين يعترضون', tone: 'red' }],
    effects: {
      approve: [{ t: 'mood', k: 'merchants', v: 2 }, { t: 'mood', k: 'clergy', v: -2 }, { t: 'xp', k: 'administration', v: 10 }],
      lose: [{ t: 'mood', k: 'clergy', v: 1 }],
    },
  },
  neighbourComplaint: {
    id: 'neighbourComplaint', kind: 'شكوى بين جارين', recurring: true, weight: 2,
    tags: [{ text: 'وساطة', tone: 'blue' }],
    effects: {
      approve: [{ t: 'xp', k: 'diplomacy', v: 25 }, { t: 'rep', v: 1 }],
    },
  },
  waterTheft: {
    id: 'waterTheft', kind: 'بلاغ عن سرقة مياه من الخزّان', recurring: true, weight: 2,
    tags: [{ text: 'أزمة المياه', tone: 'red' }, { text: 'الشرطة', tone: 'blue' }],
    effects: {
      approve: [{ t: 'issue', k: 'water', v: -2 }, { t: 'xp', k: 'administration', v: 10 }],
      report: [{ t: 'issue', k: 'water', v: -3 }, { t: 'opinion', who: 'police', v: 5, reason: 'تعاون', weeks: 26 }, { t: 'mood', k: 'palestinians', v: -2 }],
    },
  },
};

const AREAS = ['من حيّ القلعة', 'من حيّ السوق', 'من حيّ العين', 'من الضاحية الشرقية', 'من حيّ الخضر'];

export function makePermit(state: GameState, templateId: string, personId?: string, waited = 0): Permit {
  const t = PERMIT_TEMPLATES[templateId];
  const applicant = personId ? state.people[personId].name : t.applicant ?? `${pick(state, MALE_NAMES)} ${pick(state, AREAS)}`;
  return {
    id: `p${state.week}_${templateId}_${Math.floor(state.rng >>> 8) % 100000}`,
    applicant, personId, kind: t.kind, waited, tags: t.tags.map((x) => ({ ...x })), template: templateId,
  };
}

export function availableActions(p: Permit): DeskAction[] {
  const t = PERMIT_TEMPLATES[p.template];
  const out: DeskAction[] = ['approve', 'delay'];
  if (t.effects.lose) out.push('lose');
  if (t.effects.escalate) out.push('escalate');
  if (t.effects.report) out.push('report');
  return out;
}

export const DESK_LABEL: Record<DeskAction, string> = {
  approve: 'أنجِز', delay: 'أجِّل', lose: 'أضِع الملف', escalate: 'ارفعه للرئيس', report: 'أبلغ الشرطة',
};
