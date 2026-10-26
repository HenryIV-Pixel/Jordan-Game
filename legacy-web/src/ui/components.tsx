// Small shared UI pieces in the mockup style.
import type { ComponentChildren, CSSProperties } from 'preact';
import type { Tone } from '../sim/effects';
import type { Portrait as PortraitData } from '../sim/types';

export function Card(props: { title?: string; right?: ComponentChildren; gold?: boolean; class?: string; style?: CSSProperties; children?: ComponentChildren }) {
  return (
    <section class={`card ${props.gold ? 'gold' : ''} ${props.class ?? ''}`} style={props.style}>
      {props.title !== undefined && (
        <div class="card-title">
          <span>{props.title}</span>
          <span>{props.right}</span>
        </div>
      )}
      {props.children}
    </section>
  );
}

export function Bar(props: { value: number; color?: string; height?: number; max?: number }) {
  const pct = Math.max(0, Math.min(100, (props.value / (props.max ?? 100)) * 100));
  return (
    <div class="bar" style={{ height: `${props.height ?? 6}px` }}>
      <div style={{ width: `${pct}%`, background: props.color ?? 'var(--gold)' }} />
    </div>
  );
}

export function Tag(props: { tone: Tone | 'green' | 'red' | 'gold' | 'blue'; children: ComponentChildren }) {
  return <span class={`tag ${props.tone}`}>{props.children}</span>;
}

export function Tags(props: { items: { text: string; tone: Tone }[] }) {
  return (
    <span class="tags">
      {props.items.map((t, i) => (
        <Tag key={i} tone={t.tone}>{t.text}</Tag>
      ))}
    </span>
  );
}

export function Chip(props: { label: string; value: ComponentChildren; color?: string; title?: string }) {
  return (
    <div class="chip" title={props.title}>
      <span class="label">{props.label}</span>
      <span class="value" style={{ color: props.color }}>{props.value}</span>
    </div>
  );
}

export function Crown(props: { size?: number }) {
  const s = props.size ?? 22;
  return (
    <svg viewBox="0 0 40 32" width={s} height={s * 0.8} aria-hidden="true">
      <path d="M4 26 L8 10 L14 18 L20 6 L26 18 L32 10 L36 26 Z" fill="var(--gold)" />
    </svg>
  );
}

export function Lock(props: { size?: number; color?: string }) {
  const c = props.color ?? 'var(--faint)';
  return (
    <svg viewBox="0 0 24 24" width={props.size ?? 13} height={props.size ?? 13} aria-hidden="true">
      <rect x="5" y="11" width="14" height="10" rx="2" fill="none" stroke={c} stroke-width="2" />
      <path d="M8 11 V7 a4 4 0 0 1 8 0 V11" fill="none" stroke={c} stroke-width="2" />
    </svg>
  );
}

export function Check() {
  return (
    <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
      <circle cx="8" cy="8" r="7" fill="var(--green)" />
      <path d="M4.8 8.2 L7 10.3 L11.2 5.8" fill="none" stroke="#0f1318" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  );
}

export function Circle() {
  return (
    <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#6b7580" stroke-width="1.5" />
    </svg>
  );
}

const SKIN = ['#d9b08c', '#b98a63', '#8a5f3e', '#5e3f29'];

/** Placeholder portrait built from parts (headwear, face, beard, skin). */
export function Portrait(props: { p?: PortraitData; size?: number; border?: string; label?: string; female?: boolean; silhouette?: boolean }) {
  const w = props.size ?? 76;
  const h = Math.round(w * 1.2);
  const border = props.border ?? 'var(--gold-line)';
  if (props.silhouette || !props.p) {
    const c = props.female ? '#6b5a70' : '#56626f';
    return (
      <svg viewBox="0 0 100 120" width={w} height={h} role="img" aria-label={props.label ?? 'صورة مؤقتة'}>
        <rect x="1.5" y="1.5" width="97" height="117" rx="12" fill="#222a33" stroke={border} stroke-width="2" />
        <path d="M17 118 Q20 80 50 76 Q80 80 83 118 Z" fill="#46525f" />
        <circle cx="50" cy="50" r="16" fill={c} />
        {props.female && <path d="M32 50 Q32 28 50 28 Q68 28 68 50 L70 76 Q50 66 30 76 Z" fill="#3a3340" />}
      </svg>
    );
  }
  const p = props.p;
  const skin = SKIN[p.skin % SKIN.length];
  const faceRx = 30 + (p.face % 4) * 1.5;
  const faceRy = 36 + (p.face % 3) * 2;
  return (
    <svg viewBox="0 0 200 240" width={w} height={h} role="img" aria-label={props.label ?? 'صورة الشخصية'}>
      <rect x="1.5" y="1.5" width="197" height="237" rx="16" fill="#222a33" stroke={border} stroke-width="2" />
      <path d="M30 238 Q36 160 100 150 Q164 160 170 238 Z" fill="#3d4855" />
      <path d="M78 150 L100 196 L122 150" fill="none" stroke="#d9d2c2" stroke-width="3" />
      <ellipse cx="100" cy="106" rx={faceRx} ry={faceRy} fill={skin} />
      {p.headwear === 0 && (
        <g>
          <path d="M58 100 Q100 40 142 100 L150 150 Q130 132 120 118 Q100 112 80 118 Q70 132 50 150 Z" fill="#ece6d8" />
          <path d="M64 96 Q100 70 136 96" fill="none" stroke="#c0453a" stroke-width="2" stroke-dasharray="5 4" />
          <path d="M62 84 Q100 58 138 84" fill="none" stroke="#15191e" stroke-width="7" stroke-linecap="round" />
          <path d="M64 94 Q100 68 136 94" fill="none" stroke="#15191e" stroke-width="6" stroke-linecap="round" />
        </g>
      )}
      {p.headwear === 1 && <path d="M72 82 L76 52 Q100 44 124 52 L128 82 Q100 76 72 82 Z" fill="#8e2b1e" />}
      {p.headwear === 2 && <path d="M70 92 Q72 62 100 60 Q128 62 130 92 Q118 76 100 76 Q82 76 70 92 Z" fill="#2a2116" />}
      <circle cx="88" cy="106" r="3" fill="#2a2116" />
      <circle cx="112" cy="106" r="3" fill="#2a2116" />
      {p.beard === 0 && <path d="M84 124 Q100 116 116 124 Q100 130 84 124 Z" fill="#2a2116" />}
      {p.beard === 1 && <path d="M88 124 Q100 120 112 124" fill="none" stroke="#2a2116" stroke-width="3" />}
    </svg>
  );
}

export function PersonIcon(props: { size?: number; color?: string }) {
  const s = props.size ?? 34;
  return (
    <span style={{ width: `${s}px`, height: `${s}px`, borderRadius: '8px', background: '#2a323c', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <svg viewBox="0 0 24 24" width={s * 0.55} height={s * 0.55} aria-hidden="true">
        <circle cx="12" cy="9" r="4" fill={props.color ?? '#8a929b'} />
        <path d="M4 21 Q5 14 12 14 Q19 14 20 21 Z" fill={props.color ?? '#8a929b'} />
      </svg>
    </span>
  );
}

export function signed(n: number) {
  return n > 0 ? `+${n}` : `${n}`;
}
