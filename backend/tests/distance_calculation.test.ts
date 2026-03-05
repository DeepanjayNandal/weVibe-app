import { describe, expect, test } from '@jest/globals';
import { calculateDistanceKm } from '../src/utils/distance';

describe('calculateDistanceKm', () => {
  test('returns 0 for identical coordinates', () => {
    const distance = calculateDistanceKm(
      { latitude: 25.033, longitude: 121.5654 },
      { latitude: 25.033, longitude: 121.5654 },
    );

    expect(distance).toBeCloseTo(0, 8);
  });

  test('calculates distance between Taipei 101 and Taipei Main Station', () => {
    const taipei101 = { latitude: 25.033968, longitude: 121.564468 };
    const taipeiMainStation = { latitude: 25.047924, longitude: 121.517081 };

    const distance = calculateDistanceKm(taipei101, taipeiMainStation);

    expect(distance).toBeCloseTo(5.04, 1);
  });

  test('throws for out-of-range latitude', () => {
    expect(() =>
      calculateDistanceKm(
        { latitude: 91, longitude: 121.5654 },
        { latitude: 25.033, longitude: 121.5654 },
      ),
    ).toThrow(RangeError);
  });

  test('throws for out-of-range longitude', () => {
    expect(() =>
      calculateDistanceKm(
        { latitude: 25.033, longitude: 121.5654 },
        { latitude: 25.047924, longitude: -181 },
      ),
    ).toThrow(RangeError);
  });

  test('throws for non-finite numbers', () => {
    expect(() =>
      calculateDistanceKm(
        { latitude: Number.NaN, longitude: 121.5654 },
        { latitude: 25.047924, longitude: 121.517081 },
      ),
    ).toThrow(TypeError);
  });
});
