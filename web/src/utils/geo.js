// Pure geo helpers for the in-app map - shared by MapPage and Landing.
export const KANSANGA = { lat: 0.3236, lng: 32.5866 };

const EARTH_KM = 6371;

export function haversineKm(a, b) {
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_KM * Math.asin(Math.sqrt(s));
}

export function bearingDeg(a, b) {
  const toRad = (d) => (d * Math.PI) / 180;
  const toDeg = (r) => (r * 180) / Math.PI;
  const dLng = toRad(b.lng - a.lng);
  const y = Math.sin(dLng) * Math.cos(toRad(b.lat));
  const x =
    Math.cos(toRad(a.lat)) * Math.sin(toRad(b.lat)) -
    Math.sin(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.cos(dLng);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

const CARDINALS = [
  "north", "north-east", "east", "south-east",
  "south", "south-west", "west", "north-west",
];

export function cardinal(deg) {
  return CARDINALS[Math.round(deg / 45) % 8];
}

export function directionsSteps(origin, target) {
  const km = haversineKm(origin, target);
  const deg = bearingDeg(origin, target);
  const dir = cardinal(deg);
  const steps = [
    `Head ${dir} from your position (bearing ${Math.round(deg)}°).`,
  ];
  if (km < 0.1) {
    steps.push("The drop-off point is essentially here - look for the collection bay.");
  } else if (km < 1) {
    steps.push(`Continue for about ${Math.round(km * 1000)} m; you should arrive in ~${Math.max(1, Math.round(km * 12))} min on foot.`);
  } else {
    steps.push(`Follow the road ${dir} for about ${km.toFixed(1)} km (~${Math.round(km * 12)} min on foot or a short boda ride).`);
  }
  steps.push("Hand your e-waste to the certified attendant and collect your drop-off reference in EcoTrace.");
  return { km, deg, dir, steps };
}
