// Port of lib/widgets/capsule/candle_ceremony.dart: _span, _openingAt, _sealingAt.
// Flutter Cubic evaluates x before y (these are NOT polynomial ease functions).
export const OPEN_MS = 6400;
export const SEAL_MS = 7000;
const curves = { inOut: [.645,.045,.355,1], out: [.215,.61,.355,1], in: [.55,.055,.675,.19], quad: [.55,.085,.68,.53] };
export function cubic(x, curve = 'inOut') {
  if (x <= 0 || x >= 1) return Math.max(0, Math.min(1, x));
  const [a,b,c,d] = curves[curve];
  const sample = (t, p, q) => 3 * (1-t) ** 2 * t * p + 3 * (1-t) * t*t*q + t*t*t;
  let low = 0, high = 1, t;
  // Flutter Cubic._cubicErrorBound = 0.001.
  while (true) { t=(low+high)/2;const estimate=sample(t,a,c);if(Math.abs(x-estimate)<.001)return sample(t,b,d);if(estimate<x)low=t;else high=t; }
}
const span = (t,a,b,c='inOut') => cubic(Math.max(0,Math.min(1,(t-a)/(b-a))),c);
const base = {fold1:0,fold3:0,ribbon:0,ribbonOff:0,letterIn:0,envelope:1,envelopeDrop:0,flapClosed:1,candle:0,drops:[0,0,0],pool:1,seal:1,emboss:1,stamp:0,glow:0,sealGlow:0,crack:0,photo:0,letterOut:0};
export function openingAt(t) { return {...base,
  fold1:1-span(t,.74,.86),fold3:1-span(t,.82,.94),ribbon:1,ribbonOff:span(t,.66,.74),letterIn:1,
  letterOut:span(t,.54,.66,'out'),envelope:1-span(t,.70,.92),envelopeDrop:span(t,.66,.92),
  flapClosed:1-span(t,.28,.38),glow:t<.12?.3+.7*span(t,0,.12):1-span(t,.24,.36),
  sealGlow:span(t,0,.14),crack:span(t,.12,.22,'out'),seal:1-span(t,.22,.30),photo:span(t,.38,.54,'out'),
}; }
export function sealingAt(t) { return {...base,
  fold3:span(t,.06,.16),fold1:span(t,.16,.26),ribbon:span(t,.26,.36,'out'),envelope:span(t,.34,.42,'out'),
  letterIn:span(t,.40,.52),flapClosed:span(t,.52,.60),candle:t<.6?0:t<.78?span(t,.6,.66):1-span(t,.78,.84),
  drops:[[.67,.71,.712],[.71,.75,.752],[.75,.79,.792]].map(([a,b,end])=>t>=a&&t<end?span(t,a,b,'quad'):0),
  pool:.45+.43*span(t,.70,.80)+.12*span(t,.89,.94),seal:t<.7?0:1,emboss:span(t,.89,.93),
  stamp:t<.82?0:t<.92?span(t,.84,.89,'in'):1-span(t,.92,.98,'out'),
  glow:t<.62?0:t<.7?span(t,.62,.70):1-.7*span(t,.84,1),
}; }
