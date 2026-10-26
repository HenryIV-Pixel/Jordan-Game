class_name Content
extends RefCounted
## All slice content as data: people, places, approaches, schemes, rumours, newspaper lines.
## Days of week: 0 = Saturday ... 5 = Thursday, 6 = Friday (2 May 1953 was a Saturday).

const WORKDAYS := [0, 1, 2, 3, 4, 5]
const EVERYDAY := [0, 1, 2, 3, 4, 5, 6]

const TRAITS := {
	"proud": {"name": "معتدّ بنفسه", "hint": "يحبّ أن يُقدَّر، ويكره أن يُضغط عليه"},
	"greedy": {"name": "طمّاع", "hint": "المصلحة أقرب طريق إلى قلبه"},
	"principled": {"name": "صاحب مبدأ", "hint": "يحترم الحجّة، وتهينه الرشوة"},
	"tribal": {"name": "عشائري", "hint": "الدم والقرابة عنده قبل كل شيء"},
	"pious": {"name": "متديّن", "hint": "يقدّر الأمانة ويكره الكسب الحرام"},
	"cautious": {"name": "حذر", "hint": "يصغي طويلاً قبل أن يقرّر"},
	"pragmatic": {"name": "عملي", "hint": "يقتنع بالأرقام والحلول لا بالكلام"},
	"ambitious": {"name": "طموح", "hint": "يرى في كل لقاء سُلَّماً"},
}

## Approaches in a meeting. base = mood gain, mods = per-trait adjustments, stat = which of your stats helps.
const APPROACHES := {
	"flatter": {"name": "مجاملة", "desc": "أثنِ عليه وعلى مكانته", "base": 7, "stat": "charisma",
		"mods": {"proud": 11, "principled": -5, "pragmatic": -3, "cautious": -2}},
	"competence": {"name": "حجّة وأرقام", "desc": "اعرض خطة واضحة وأرقاماً", "base": 6, "stat": "administration",
		"mods": {"pragmatic": 11, "cautious": 5, "proud": -2, "tribal": -3}},
	"kin": {"name": "القرابة والعشيرة", "desc": "ذكّره بالدم والجيرة والعِشرة", "base": 4, "stat": "charisma",
		"mods": {"tribal": 14, "pious": 3, "pragmatic": -3, "principled": -2}},
	"principle": {"name": "المصلحة العامة", "desc": "خاطب ضميره ومصلحة البلد", "base": 5, "stat": "diplomacy",
		"mods": {"principled": 12, "pious": 6, "greedy": -5, "pragmatic": -2}},
	"offer": {"name": "عرض مصلحة", "desc": "قدّم هدية أو وعداً بخدمة (٥ دنانير)", "base": 9, "stat": "diplomacy", "cost": 5,
		"mods": {"greedy": 13, "pragmatic": 4, "principled": -16, "pious": -7}},
	"pressure": {"name": "ضغط بملفّ", "desc": "لمّح إلى ما تعرفه عنه", "base": 22, "stat": "intrigue", "needs_secret": true,
		"mods": {"proud": -18, "cautious": 8, "greedy": 2}},
	"listen": {"name": "إصغاء", "desc": "اسمع أكثر مما تتكلم — تكشف شيئاً من طبعه", "base": 3, "stat": "diplomacy",
		"mods": {"cautious": 6, "proud": 3}},
}

## What you can ask for at the end of a meeting. target = mood needed.
const ASKS := {
	"chat": {"name": "توطيد العلاقة", "desc": "لا طلب — فقط كسب الودّ", "target": 0},
	"pledge": {"name": "ادعم ترشيحي", "desc": "تأييد علني في الانتخابات", "target": 70},
	"letter": {"name": "خطاب توصية إلى عمّان", "desc": "يفتح لك باب وزارة الداخلية", "target": 60},
	"funds": {"name": "تمويل إصلاح الخزّان", "desc": "ينهي أزمة المياه في السلط", "target": 76},
	"well": {"name": "افتح بئرك للناس", "desc": "حلّ سريع لأزمة المياه — بثمن", "target": 62},
	"ally": {"name": "كن عيني في البلد", "desc": "يساعدك في التقصّي والدسائس", "target": 56},
	"publish": {"name": "انشر الفضيحة", "desc": "يحتاج ملفاً عن منافسك", "target": 56},
	"profile": {"name": "اكتب عني", "desc": "مقال يرفع سمعتك", "target": 62},
}

## People of the slice. weight = how many votes their backing moves in the by-election.
const PEOPLE := {
	"mayor": {"name": "الحاج زياد", "role": "رئيس بلدية السلط", "town": "salt", "traits": ["proud", "pragmatic"],
		"opinion": 15, "rival_op": 22, "weight": 6, "asks": ["chat", "pledge", "letter"],
		"look": {"hw": 2, "skin": 1, "beard": 1, "old": true},
		"sched": [{"place": "baladiya", "days": WORKDAYS, "from": 8, "to": 14}],
		"secret": {"text": "أحال عقد ترميم السوق على صهر ابنه دون مناقصة", "sev": 2}},
	"sheikh": {"name": "الشيخ فالح", "role": "شيخ العشيرة · عمّ أبيك", "town": "salt", "traits": ["tribal", "pious"],
		"opinion": 38, "rival_op": 8, "weight": 9, "asks": ["chat", "pledge"],
		"look": {"hw": 0, "skin": 2, "beard": 0, "old": true},
		"sched": [{"place": "madafa", "days": EVERYDAY, "from": 16, "to": 23}]},
	"merchant": {"name": "أبو خليل", "role": "تاجر حبوب وصاحب بئر", "town": "salt", "traits": ["greedy", "cautious"],
		"opinion": 0, "rival_op": 38, "weight": 6, "asks": ["chat", "pledge", "well"],
		"look": {"hw": 1, "skin": 1, "beard": 1, "old": true},
		"sched": [{"place": "market", "days": WORKDAYS, "from": 7, "to": 19}],
		"secret": {"text": "يبيع ماء بئره بأضعاف ثمنه ويخزّن القمح ليرفع سعره", "sev": 2}},
	"teacher": {"name": "الأستاذ فيصل", "role": "معلّم في مدرسة السلط الثانوية", "town": "salt", "traits": ["principled", "ambitious"],
		"opinion": 6, "rival_op": 10, "weight": 4, "asks": ["chat", "pledge"],
		"look": {"hw": -1, "skin": 0, "beard": 2, "old": false},
		"sched": [{"place": "school", "days": WORKDAYS, "from": 7, "to": 13}, {"place": "cafe", "days": EVERYDAY, "from": 17, "to": 21}]},
	"doctor": {"name": "الدكتور هاني", "role": "طبيب وعضو في المجلس البلدي", "town": "salt", "traits": ["cautious", "pragmatic"],
		"opinion": 10, "rival_op": 14, "weight": 5, "asks": ["chat", "pledge"],
		"look": {"hw": -1, "skin": 0, "beard": 1, "old": false},
		"sched": [{"place": "clinic", "days": WORKDAYS, "from": 9, "to": 15}, {"place": "cafe", "days": [3, 4], "from": 18, "to": 21}]},
	"police": {"name": "الملازم مازن", "role": "آمر مخفر السلط", "town": "salt", "traits": ["greedy", "pragmatic"],
		"opinion": 0, "rival_op": 5, "weight": 0, "asks": ["chat", "ally"],
		"look": {"hw": 1, "skin": 2, "beard": 1, "old": false, "uniform": true},
		"sched": [{"place": "police", "days": EVERYDAY, "from": 8, "to": 20}],
		"secret": {"text": "يأخذ «إتاوة» شهرية من أصحاب الدكاكين", "sev": 2}},
	"official": {"name": "رفعت بك", "role": "مدير في وزارة الداخلية — عمّان", "town": "amman", "traits": ["proud", "cautious"],
		"opinion": -5, "rival_op": 0, "weight": 0, "asks": ["chat", "funds"],
		"look": {"hw": 1, "skin": 0, "beard": 1, "old": true},
		"sched": [{"place": "interior", "days": WORKDAYS, "from": 9, "to": 14}]},
	"journalist": {"name": "جميل", "role": "محرّر في جريدة «الصباح» — عمّان", "town": "amman", "traits": ["ambitious", "principled"],
		"opinion": 0, "rival_op": 0, "weight": 0, "asks": ["chat", "publish", "profile"],
		"look": {"hw": -1, "skin": 1, "beard": 2, "old": false},
		"sched": [{"place": "paper", "days": EVERYDAY, "from": 10, "to": 20}]},
}

const RIVAL := {"id": "issa", "name": "عيسى الحدّاد", "role": "كاتب في البلدية ومنافسك على المقعد",
	"look": {"hw": -1, "skin": 1, "beard": 1, "old": false},
	"secret": {"text": "يختلس من رسوم المعاملات ويزوّر الإيصالات", "sev": 3}}

## Places per town. Towns not listed get DEFAULT_PLACES.
const PLACES := {
	"salt": [
		{"id": "baladiya", "name": "دار البلدية", "open": [7, 15], "days": WORKDAYS, "actions": ["paperwork", "archives", "trucks"]},
		{"id": "market", "name": "سوق شارع الحمّام", "open": [7, 19], "days": WORKDAYS, "actions": ["gift"]},
		{"id": "cafe", "name": "مقهى العين", "open": [7, 23], "days": EVERYDAY, "actions": ["listen", "round"]},
		{"id": "madafa", "name": "مضافة الشيخ فالح", "open": [16, 23], "days": EVERYDAY, "actions": ["majlis"]},
		{"id": "school", "name": "مدرسة السلط الثانوية", "open": [7, 13], "days": WORKDAYS, "actions": []},
		{"id": "clinic", "name": "عيادة الدكتور هاني", "open": [9, 15], "days": WORKDAYS, "actions": []},
		{"id": "police", "name": "مخفر السلط", "open": [0, 24], "days": EVERYDAY, "actions": []},
		{"id": "home", "name": "البيت", "open": [0, 24], "days": EVERYDAY, "actions": ["advice", "sleep"]},
	],
	"amman": [
		{"id": "interior", "name": "وزارة الداخلية", "open": [8, 14], "days": WORKDAYS, "actions": []},
		{"id": "paper", "name": "جريدة «الصباح»", "open": [9, 21], "days": EVERYDAY, "actions": []},
		{"id": "cafe", "name": "مقهى في وسط البلد", "open": [7, 24], "days": EVERYDAY, "actions": ["listen"]},
		{"id": "hotel", "name": "فندق فيلادلفيا", "open": [0, 24], "days": EVERYDAY, "actions": ["sleep_inn"]},
	],
	"irbid": [
		{"id": "wedding", "name": "عرس آل الناصر", "open": [16, 23], "days": [5], "actions": ["wedding"], "flag": "wedding_open"},
		{"id": "cafe", "name": "مقهى البلدة", "open": [7, 23], "days": EVERYDAY, "actions": ["listen"]},
		{"id": "inn", "name": "خان المسافرين", "open": [0, 24], "days": EVERYDAY, "actions": ["sleep_inn"]},
	],
}
const DEFAULT_PLACES := [
	{"id": "cafe", "name": "مقهى البلدة", "open": [7, 23], "days": EVERYDAY, "actions": ["listen"]},
	{"id": "inn", "name": "خان المسافرين", "open": [0, 24], "days": EVERYDAY, "actions": ["sleep_inn"]},
]

const ACTIONS := {
	"paperwork": {"name": "أنجز معاملات اليوم", "hours": 3, "desc": "عمل الكاتب: تواقيع وأختام ومراجعون"},
	"archives": {"name": "تفحّص دفاتر الإيصالات", "hours": 2, "desc": "يسهّل التقصّي عن أي موظف في البلدية"},
	"trucks": {"name": "استأجر صهاريج ماء", "hours": 2, "desc": "٢٥ ديناراً من جيبك — يخفّف العطش", "cost": 25},
	"gift": {"name": "اشترِ هدية", "hours": 1, "desc": "٥ دنانير — تفتح باب «عرض مصلحة» دون مال", "cost": 5},
	"listen": {"name": "استمع لأحاديث المقهى", "hours": 1, "desc": "إشاعات وأخبار وما يخفيه الناس"},
	"round": {"name": "ادفع جولة شاي", "hours": 1, "desc": "دينارين — الناس يتذكرون الكرم", "cost": 2},
	"majlis": {"name": "احضر مجلس الشيخ", "hours": 2, "desc": "يقرّبك من العشيرة"},
	"advice": {"name": "اسأل أباك النصيحة", "hours": 1, "desc": "أبوك يعرف السلط جيداً"},
	"sleep": {"name": "نم حتى الصباح", "hours": 0, "desc": "تقديم الوقت إلى السابعة صباحاً"},
	"sleep_inn": {"name": "بِت الليلة هنا", "hours": 0, "desc": "دينار واحد — حتى السابعة صباحاً", "cost": 1},
	"wedding": {"name": "احضر العرس", "hours": 4, "desc": "الشيخ سيرى من حضر ومن غاب"},
}

const SCHEMES := {
	"dig": {"name": "تقصَّ عن سرّ", "desc": "ابحث عن شيء يدينه", "days": 3, "odds": 22, "disc": 14},
	"rumour": {"name": "أطلق إشاعة", "desc": "شوّه سمعة منافسك", "days": 2, "odds": 55, "disc": 18},
	"bribe": {"name": "رشوة", "desc": "١٥ ديناراً مقابل تأييده", "days": 1, "odds": 30, "disc": 22, "cost": 15},
	"leak": {"name": "سرّب الملف للصحافة", "desc": "يحتاج سرّاً في خزانتك وصحفياً يثق بك", "days": 2, "odds": 85, "disc": 8},
}

## Weekly newspaper — national lines by issue number (1 = Saturday 9 May).
const NATIONAL := {
	1: ["حكومة فوزي الملقي تؤدي اليمين أمام جلالة الملك", "الحكومة الجديدة تعد بانفتاح سياسي وحرية أوسع للصحافة"],
	2: ["الملك الحسين يتفقّد قطعات الجيش العربي", "ارتفاع أسعار القمح في الأسواق"],
	3: ["حوادث على خطوط الهدنة وقلق في قرى الحدود", "وفود اللاجئين تطالب بتحسين أوضاع المخيمات"],
	4: ["موجة حرّ مبكرة تضرب المملكة", "شكاوى من شحّ المياه في المدن الجبلية"],
	5: ["الأحزاب تستعد لموسم سياسي ساخن", "إذاعة القاهرة تجذب المستمعين في المقاهي"],
	6: ["اليوم: الاقتراع على مقعد السلط البلدي", "الحكومة: الانتخابات ستجري بنزاهة"],
}
