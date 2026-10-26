// The kingdom map: real borders and features from Natural Earth, towns from game data.
import { MAP } from '../data/mapData';
import { MUNICIPALITIES, OTHER_TOWNS } from '../sim/data';

export function project(lon: number, lat: number): [number, number] {
  return [(lon - MAP.lon0) * MAP.kx, (MAP.lat1 - lat) * MAP.ky];
}

const COUNTRY_LABELS: { name: string; lon: number; lat: number; size: number }[] = [
  { name: 'سوريا', lon: 37.35, lat: 33.12, size: 16 }, { name: 'العراق', lon: 39.45, lat: 32.75, size: 15 },
  { name: 'السعودية', lon: 38.15, lat: 29.55, size: 16 }, { name: 'إسرائيل', lon: 34.55, lat: 30.95, size: 14 },
  { name: 'مصر', lon: 33.95, lat: 29.55, size: 14 }, { name: 'لبنان', lon: 35.35, lat: 33.42, size: 12 },
];

const ANCHOR: Record<string, 'start' | 'end'> = {
  irbid: 'end', salt: 'end', aqaba: 'start', karak: 'start', maan: 'start', amman: 'start', zarqa: 'start',
  madaba: 'start', mafraq: 'start', jerash: 'start',
  'عجلون': 'end', 'الشوبك': 'end', 'وادي موسى': 'end', 'القدس': 'end', 'الخليل': 'end', 'جنين': 'end',
  'رام الله': 'end', 'طولكرم': 'end', 'حيفا': 'end', 'تل أبيب': 'end', 'غزة': 'end', 'بئر السبع': 'end', 'إيلات': 'end',
};

function Label(props: { x: number; y: number; text: string; anchor?: 'start' | 'end' | 'middle'; size?: number; weight?: number; color?: string; halo?: boolean }) {
  const a = props.anchor ?? 'start';
  const style = { fontFamily: 'var(--font)', fontSize: `${props.size ?? 11}px`, fontWeight: props.weight ?? 400, textAnchor: a } as const;
  return (
    <g>
      {props.halo !== false && (
        <text x={props.x} y={props.y} style={style} fill="#0f1318" stroke="#0f1318" stroke-width="3.5" stroke-linejoin="round" aria-hidden="true">{props.text}</text>
      )}
      <text x={props.x} y={props.y} style={style} fill={props.color ?? '#c4ccd2'}>{props.text}</text>
    </g>
  );
}

export interface JordanMapProps {
  /** The player's own municipality (gold ring). */
  home?: string;
  /** Currently selected municipality. */
  selected?: string | null;
  onSelect?: (id: string) => void;
  /** Municipality ids that may be selected; others render as plain towns. */
  selectable?: string[];
  viewBox?: string;
  label?: string;
}

export function JordanMap(props: JordanMapProps) {
  const sel = props.selected;
  const selectable = new Set(props.selectable ?? []);
  return (
    <svg viewBox={props.viewBox ?? `0 0 ${MAP.width} ${MAP.height}`} preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} role="img" aria-label={props.label ?? 'خريطة المملكة الأردنية الهاشمية عام 1953'}>
      <defs>
        <pattern id="wbHatch" patternUnits="userSpaceOnUse" width="7" height="7" patternTransform="rotate(45)">
          <rect x="0" y="0" width="7" height="7" fill="#2a4350" />
          <line x1="0" y1="0" x2="0" y2="7" stroke="#4d6b79" stroke-width="2" />
        </pattern>
      </defs>
      <rect x="0" y="0" width={MAP.width} height={MAP.height} fill="var(--sea)" />
      {MAP.neighbours.map((n) => <path key={n.id} d={n.d} fill="#19222a" stroke="#3b4955" stroke-width="1" stroke-linejoin="round" />)}
      <path d={MAP.eastBank} fill="#263c48" />
      <path d={MAP.westBank} fill="url(#wbHatch)" />
      <path d={MAP.districtLines} fill="none" stroke="#4f6a78" stroke-width="0.9" stroke-dasharray="3 3" />
      <path d={MAP.kingdomBorder} fill="none" stroke="#9cc0cf" stroke-width="1.8" stroke-linejoin="round" />
      {MAP.sea.map((d, i) => <path key={`s${i}`} d={d} fill="var(--sea)" stroke="#2a4b5c" stroke-width="1" />)}
      {MAP.lakes.map((d, i) => <path key={`l${i}`} d={d} fill="#1d5873" stroke="#4fa3c7" stroke-width="1" />)}
      {MAP.rivers.map((d, i) => <path key={`r${i}`} d={d} fill="none" stroke="#4fa3c7" stroke-width="1.4" stroke-linecap="round" />)}
      {MAP.roads.map((d, i) => <path key={`o${i}`} d={d} fill="none" stroke="#5c6c78" stroke-width="0.8" stroke-linecap="round" />)}
      {MAP.rail.map((d, i) => (
        <g key={`t${i}`}>
          <path d={d} fill="none" stroke="#0f2230" stroke-width="3.2" stroke-linecap="round" />
          <path d={d} fill="none" stroke="#b9a27a" stroke-width="1.6" stroke-dasharray="5 3" />
        </g>
      ))}
      {COUNTRY_LABELS.map((c) => {
        const [x, y] = project(c.lon, c.lat);
        return <Label key={c.name} x={x} y={y} text={c.name} anchor="middle" size={c.size} weight={500} color="#7f8b95" halo={false} />;
      })}
      {(() => { const [x, y] = project(37.7, 32.12); return <Label x={x} y={y} text="البادية الأردنية" anchor="middle" size={15} weight={500} color="#5e7b88" halo={false} />; })()}
      {(() => { const [x, y] = project(34.05, 32.35); return <Label x={x} y={y} text="البحر المتوسط" anchor="middle" size={12} color="#4f7d93" halo={false} />; })()}

      {OTHER_TOWNS.map((t) => {
        const [x, y] = project(t.lon, t.lat);
        const a = ANCHOR[t.name] ?? 'start';
        return (
          <g key={t.name}>
            <circle cx={x} cy={y} r={t.neighbour ? 2.2 : 2.4} fill={t.neighbour ? '#7f8b95' : '#c4ccd2'} stroke="#0f1318" stroke-width="1.2" />
            <Label x={x + (a === 'start' ? 7 : -7)} y={y + 4} text={t.name} anchor={a} size={11} color={t.neighbour ? '#8d98a2' : '#c4ccd2'} />
          </g>
        );
      })}
      {MUNICIPALITIES.map((m) => {
        const [x, y] = project(m.lon, m.lat);
        const isHome = props.home === m.id;
        const isSel = sel === m.id;
        const canPick = selectable.has(m.id);
        const a = ANCHOR[m.id] ?? 'start';
        const capital = m.id === 'amman';
        const color = isHome || isSel ? '#e8c47a' : '#e3e8eb';
        return (
          <g key={m.id} style={{ cursor: canPick ? 'pointer' : 'default' }} onClick={canPick ? () => props.onSelect?.(m.id) : undefined}
            role={canPick ? 'button' : undefined} aria-label={canPick ? `اختر ${m.name}` : undefined} tabIndex={canPick ? 0 : undefined}
            onKeyDown={canPick ? (e) => { if (e.key === 'Enter') props.onSelect?.(m.id); } : undefined}>
            {canPick && <circle cx={x} cy={y} r="14" fill="transparent" />}
            {(isHome || isSel) && <circle cx={x} cy={y} r="11" fill="#d4a94e" fill-opacity="0.22" stroke="#d4a94e" stroke-width="1.5" />}
            {capital && !isHome && !isSel
              ? <rect x={x - 4} y={y - 4} width="8" height="8" rx="1.5" fill="#fff" stroke="#0f1318" stroke-width="1.5" />
              : <circle cx={x} cy={y} r={isHome || isSel ? 4 : 3.2} fill={isHome || isSel ? '#d4a94e' : '#e3e8eb'} stroke="#0f1318" stroke-width="1.2" />}
            <Label x={x + (a === 'start' ? (isHome || isSel ? 15 : 8) : (isHome || isSel ? -15 : -8))} y={y + 5} text={m.name} anchor={a}
              size={capital || isHome || isSel ? 14 : 12.5} weight={700} color={color} />
          </g>
        );
      })}
    </svg>
  );
}
