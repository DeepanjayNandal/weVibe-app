const EARTH_RADIUS_KM = 6371;

export interface Coordinates {
  latitude: number;
  longitude: number;
}

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

function assertFiniteNumber(value: number, fieldName: string): void {
  if (!Number.isFinite(value)) {
    throw new TypeError(`${fieldName} must be a finite number`);
  }
}

function validateCoordinates(point: Coordinates, label: string): void {
  assertFiniteNumber(point.latitude, `${label}.latitude`);
  assertFiniteNumber(point.longitude, `${label}.longitude`);

  if (point.latitude < -90 || point.latitude > 90) {
    throw new RangeError(`${label}.latitude must be between -90 and 90`);
  }

  if (point.longitude < -180 || point.longitude > 180) {
    throw new RangeError(`${label}.longitude must be between -180 and 180`);
  }
}

export function calculateDistanceKm(from: Coordinates, to: Coordinates): number {
  validateCoordinates(from, 'from');
  validateCoordinates(to, 'to');

  const fromLatitudeRad = toRadians(from.latitude);
  const toLatitudeRad = toRadians(to.latitude);

  const deltaLatitudeRad = toRadians(to.latitude - from.latitude);
  const deltaLongitudeRad = toRadians(to.longitude - from.longitude);

  const a =
    Math.sin(deltaLatitudeRad / 2) ** 2 +
    Math.cos(fromLatitudeRad) * Math.cos(toLatitudeRad) * Math.sin(deltaLongitudeRad / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_KM * c;
}
