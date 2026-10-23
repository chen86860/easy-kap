/** `m:ss`, as Easy Kap shows it beside the trim bar and in the menu bar. */
export function timecode(seconds: number): string {
  const whole = Math.floor(Math.max(0, seconds));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}
