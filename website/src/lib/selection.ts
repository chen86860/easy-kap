export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export type Handle = "nw" | "n" | "ne" | "e" | "se" | "s" | "sw" | "w";

export const handles: Handle[] = ["nw", "n", "ne", "e", "se", "s", "sw", "w"];

const clamp = (value: number, lower: number, upper: number) => Math.min(Math.max(value, lower), Math.max(lower, upper));

/** Keeps the rect inside the desk, below its menu bar, and no smaller than `minimum`. */
export function fit(rect: Rect, bounds: { width: number; height: number; top: number }, minimum: number): Rect {
  const w = clamp(rect.w, minimum, bounds.width);
  const h = clamp(rect.h, minimum, bounds.height - bounds.top);
  return { w, h, x: clamp(rect.x, 0, bounds.width - w), y: clamp(rect.y, bounds.top, bounds.height - h) };
}

export function moved(rect: Rect, dx: number, dy: number): Rect {
  return { ...rect, x: rect.x + dx, y: rect.y + dy };
}

/** Drags one handle; the opposite edge stays put, even when the rect would shrink below `minimum`. */
export function resized(rect: Rect, handle: Handle, dx: number, dy: number, minimum: number): Rect {
  let { x, y, w, h } = rect;
  if (handle.includes("e")) w = rect.w + dx;
  if (handle.includes("w")) {
    w = rect.w - dx;
    x = rect.x + dx;
  }
  if (handle.includes("s")) h = rect.h + dy;
  if (handle.includes("n")) {
    h = rect.h - dy;
    y = rect.y + dy;
  }
  if (w < minimum) {
    if (handle.includes("w")) x = rect.x + rect.w - minimum;
    w = minimum;
  }
  if (h < minimum) {
    if (handle.includes("n")) y = rect.y + rect.h - minimum;
    h = minimum;
  }
  return { x, y, w, h };
}

/** The selection's size in the points of the screen the demo stands in for. */
export function pointSize(rect: Rect, deskWidth: number, screenPoints: number) {
  const scale = screenPoints / deskWidth;
  return { width: Math.round(rect.w * scale), height: Math.round(rect.h * scale) };
}
