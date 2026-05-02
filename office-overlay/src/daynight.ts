export interface DayNight {
  skyColor: number;
  windowColor: number;
  windowGlow: number;
  monitorBoost: number;
  ambientAlpha: number;
  ambientColor: number;
  label: string;
}

export function currentDayNight(date: Date = new Date()): DayNight {
  const h = date.getHours() + date.getMinutes() / 60;

  if (h >= 5 && h < 8) {
    const k = (h - 5) / 3;
    return {
      skyColor: lerpColor(0x0a0820, 0xff8c5a, k),
      windowColor: lerpColor(0x2a3a55, 0xffaa66, k),
      windowGlow: lerpColor(0x4466aa, 0xffcc88, k),
      monitorBoost: 1 - k * 0.4,
      ambientAlpha: 0.35 - k * 0.3,
      ambientColor: lerpColor(0x0a0820, 0xff7744, k),
      label: "alba",
    };
  }
  if (h >= 8 && h < 18) {
    return {
      skyColor: 0x88c0ff,
      windowColor: 0x88c0ff,
      windowGlow: 0xddeeff,
      monitorBoost: 0.5,
      ambientAlpha: 0,
      ambientColor: 0xffffff,
      label: "giorno",
    };
  }
  if (h >= 18 && h < 21) {
    const k = (h - 18) / 3;
    return {
      skyColor: lerpColor(0x88c0ff, 0x2a1530, k),
      windowColor: lerpColor(0x88c0ff, 0xff6644, k),
      windowGlow: lerpColor(0xddeeff, 0xff8855, k),
      monitorBoost: 0.5 + k * 0.4,
      ambientAlpha: k * 0.3,
      ambientColor: lerpColor(0xffffff, 0xff5522, k),
      label: "tramonto",
    };
  }
  return {
    skyColor: 0x0a0820,
    windowColor: 0x1a1a3a,
    windowGlow: 0x4466aa,
    monitorBoost: 1.0,
    ambientAlpha: 0.45,
    ambientColor: 0x1a1a3a,
    label: "notte",
  };
}

function lerpColor(a: number, b: number, k: number): number {
  k = Math.max(0, Math.min(1, k));
  const ar = (a >> 16) & 0xff, ag = (a >> 8) & 0xff, ab = a & 0xff;
  const br = (b >> 16) & 0xff, bg = (b >> 8) & 0xff, bb = b & 0xff;
  const r = Math.round(ar + (br - ar) * k);
  const g = Math.round(ag + (bg - ag) * k);
  const bl = Math.round(ab + (bb - ab) * k);
  return (r << 16) | (g << 8) | bl;
}
