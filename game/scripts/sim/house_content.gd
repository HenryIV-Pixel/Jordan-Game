class_name HouseContent
extends RefCounted
## Data for the parliament scenario "The Pact" (December 1955). The 40 deputies are fictional people in a
## realistic House: 20 East Bank and 20 West Bank seats, with Christian, Circassian and Bedouin seats.
## Names of real people appear only for public figures of the time (the King, the prime minister, Templer, Nasser).

const START_DAY := 15 # 15 December 1955 (a Thursday)
const DAYS := 6 # the vote is on the evening of the 6th day (20 December)
const AP_PER_DAY := 4
const SLOTS := ["الصباح", "الظهر", "العصر", "المساء"]

const BLOCS := {
	"bedouin": {"name": "مقاعد البدو", "color": Color("c9a24e"), "base": 55, "spread": 10, "street": 0.0},
	"east_tribal": {"name": "مستقلّو الضفة الشرقية", "color": Color("b98a4a"), "base": 18, "spread": 22, "street": 0.15},
	"east_urban": {"name": "تجّار عمّان والمقاعد المخصّصة", "color": Color("8fb6c9"), "base": 8, "spread": 16, "street": 0.25},
	"west_notable": {"name": "وجهاء الضفة الغربية", "color": Color("9ab08a"), "base": -8, "spread": 18, "street": 0.55},
	"west_indep": {"name": "مستقلّو الضفة الغربية", "color": Color("7f9a8c"), "base": -24, "spread": 14, "street": 0.75},
	"opposition": {"name": "المعارضة القومية والإخوان", "color": Color("c0453a"), "base": -68, "spread": 10, "street": 0.3},
}

## What each deputy wants most. Known only after you sit with him or ask around.
const WANTS := {
	"post": {"name": "منصب وزاري أو وظيفة لقريب", "short": "منصب"},
	"road": {"name": "طريق معبّد لقضائه", "short": "طريق"},
	"school": {"name": "مدرسة ثانوية في بلدته", "short": "مدرسة"},
	"water": {"name": "مشروع ماء لقراه", "short": "ماء"},
	"money": {"name": "المال، بلا مواربة", "short": "مال"},
	"pardon": {"name": "عفو عن قريب موقوف", "short": "عفو"},
	"egypt": {"name": "أن تُستشار القاهرة أولاً", "short": "استشارة مصر"},
	"tribe": {"name": "كلمة من الملك لعشيرته", "short": "كلمة الملك"},
}

const SECRETS := [
	"يتلقى «إعانات» شهرية من قنصلية أجنبية",
	"باع أرضاً لا يملكها لتاجر من يافا قبل الحرب",
	"له زوجة ثانية في دمشق لا تعرفها عائلته",
	"شارك في تهريب سلاح عبر الحدود السورية",
	"زوّر شهادة إعفاء ابنه من الخدمة",
	"مدين بمبلغ كبير لصرّاف في القدس",
	"اختلس من صندوق جمعية خيرية يرأسها",
]

const TOWNS_EAST := ["karak", "karak", "salt", "salt", "madaba", "tafila", "maan", "ajloun", "ajloun", "irbid", "irbid", "irbid", "jerash", "mafraq", "zarqa", "amman", "amman", "amman", "aqaba", "ramtha"]
const TOWNS_WEST := ["jerusalem", "jerusalem", "jerusalem", "hebron", "hebron", "hebron", "nablus", "nablus", "nablus", "jenin", "jenin", "tulkarm", "tulkarm", "ramallah", "ramallah", "jericho", "jerusalem", "hebron", "nablus", "ramallah"]

const FIRST := ["عبد الرحمن", "محمود", "سعيد", "فارس", "عبد الله", "خليل", "يوسف", "عارف", "حسن", "نمر", "صالح", "عيسى", "إبراهيم", "سليمان", "مصطفى",
	"توفيق", "أنور", "رشيد", "كامل", "حمدي", "شوكت", "عادل", "فؤاد", "جميل", "راغب", "ممدوح", "ذيب", "مثقال", "عودة", "قاسم", "حافظ", "زكي",
	"وصفي", "نعيم", "شفيق", "رفيق", "مدحت", "عزت", "بشير", "عوني"]
const FAMILY_EAST := ["المجالي", "الطراونة", "الحياري", "العربيات", "الشوابكة", "الصرايرة", "البطاينة", "التل", "الخصاونة", "الروسان", "الفايز", "الزبن",
	"الدعجة", "الكايد", "النعيمات", "العدوان", "الحمود", "المعشر", "قعوار", "شابسوغ"]
const FAMILY_WEST := ["الدجاني", "النشاشيبي", "الحسيني", "الخالدي", "الجعبري", "القواسمي", "طوقان", "الشكعة", "عبد الهادي", "النابلسي", "جرّار", "الحنّون",
	"البرغوثي", "الخطيب", "العلمي", "الشوا", "دبّاغ", "صلاح", "حمّاد", "الطويل"]

## Layout of the 40 seats by bloc, east first then west (each list is [bloc, count, bank]).
const COMPOSITION := [["bedouin", 3, "east"], ["east_tribal", 13, "east"], ["east_urban", 4, "east"],
	["west_notable", 10, "west"], ["west_indep", 4, "west"], ["opposition", 6, "west"]]

## Real public figures who speak in the scenario's events. Photos load when the portrait downloader has run.
const FIGURES := {
	"king": {"name": "الملك الحسين", "role": "ملك الأردن، في العشرين من عمره", "photo": "hussein_bin_talal", "look": {"hw": -1, "skin": 1, "beard": 1}},
	"pm": {"name": "هزّاع المجالي", "role": "رئيس الوزراء المكلّف", "photo": "hazza_al_majali", "look": {"hw": 0, "skin": 1, "beard": 1, "old": false}},
	"templer": {"name": "الجنرال تمبلر", "role": "رئيس هيئة الأركان الإمبراطورية البريطانية", "photo": "gerald_templer", "look": {"hw": 2, "skin": 0, "beard": 1, "old": true}},
	"nasser": {"name": "جمال عبد الناصر", "role": "رئيس وزراء مصر — صوته في كل مذياع", "photo": "gamal_abdel_nasser", "look": {"hw": -1, "skin": 1, "beard": 1}},
	"glubb": {"name": "غلوب باشا", "role": "قائد الجيش العربي", "photo": "john_bagot_glubb", "look": {"hw": 1, "skin": 0, "beard": 1, "old": true, "uniform": true}},
}

const GLOBAL_ACTIONS := {
	"statement": {"name": "بيان في الصحف الموالية", "desc": "يهدّئ الشارع قليلاً", "ap": 1},
	"aid": {"name": "اطلب ضمانات بريطانية مكتوبة", "desc": "معاهدة معدّلة ومزيد من المساعدات: يقنع العمليين", "ap": 1, "once": true},
	"cairo": {"name": "أرسل مبعوثاً إلى القاهرة", "desc": "يطمئن وجهاء الضفة الغربية… ويغضب الإنجليز والقصر", "ap": 1, "once": true},
	"curfew": {"name": "اطلب من الجيش فرض منع التجوّل", "desc": "يُسكت الشارع بالقوة — بثمن", "ap": 1, "once": true},
	"whips": {"name": "أرسل رجالك يسألون في الكواليس", "desc": "تكشف ما يريده ثلاثة نواب لا تعرفهم", "ap": 1},
}

const DEPUTY_ACTIONS := {
	"meet": {"name": "اجلس معه", "desc": "لقاء وجهاً لوجه", "ap": 1},
	"post": {"name": "عِده بمنصب", "desc": "المناصب قليلة", "ap": 0},
	"project": {"name": "عِده بمشروع لقضائه", "desc": "طريق أو مدرسة أو ماء", "ap": 0},
	"pay": {"name": "ادفع من المخصّصات السرية", "desc": "٥٠ ديناراً", "ap": 0},
	"palace": {"name": "اطلب له كلمة من الملك", "desc": "يُستدعى إلى القصر", "ap": 1},
	"dig": {"name": "تقصَّ عنه", "desc": "رجالك يبحثون في ماضيه", "ap": 1},
	"file": {"name": "واجهه بملفّه", "desc": "يصوّت كما تريد… أو ينفجر في وجهك", "ap": 0},
}
