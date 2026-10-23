import { describe, expect, it } from "vitest";
import { fit, pointSize, resized } from "./selection";

describe("resized", () => {
  const rect = { x: 100, y: 100, w: 200, h: 100 };

  it("moves only the dragged edges", () => {
    expect(resized(rect, "nw", -20, -10, 40)).toEqual({ x: 80, y: 90, w: 220, h: 110 });
    expect(resized(rect, "e", 30, 999, 40)).toEqual({ x: 100, y: 100, w: 230, h: 100 });
  });

  it("keeps the opposite edge fixed at the minimum size", () => {
    expect(resized(rect, "w", 500, 0, 40)).toEqual({ x: 260, y: 100, w: 40, h: 100 });
  });
});

describe("fit", () => {
  it("keeps the selection below the menu bar and inside the desk", () => {
    expect(fit({ x: -50, y: 0, w: 2000, h: 50 }, { width: 800, height: 500, top: 30 }, 40)).toEqual({ x: 0, y: 30, w: 800, h: 50 });
  });
});

describe("pointSize", () => {
  it("scales from demo pixels to screen points", () => {
    expect(pointSize({ x: 0, y: 0, w: 500, h: 250 }, 1000, 1512)).toEqual({ width: 756, height: 378 });
  });
});
