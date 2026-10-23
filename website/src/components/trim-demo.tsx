import { useReducedMotion } from "motion/react";
import { type PointerEvent, useEffect, useRef, useState } from "react";

import { timecode } from "@/lib/timecode";

const duration = 6;
const minimumLength = 0.4;
const clamp = (value: number, lower: number, upper: number) => Math.min(Math.max(value, lower), upper);
const percent = (seconds: number) => `${(seconds / duration) * 100}%`;

/** Easy Kap's editor trim bar: the clip loops between the handles, and hovering the track previews that frame. */
export function TrimDemo() {
  const trackRef = useRef<HTMLDivElement>(null);
  const [trim, setTrim] = useState({ start: 0.8, end: 5.2 });
  const [playhead, setPlayhead] = useState(0.8);
  const [hoverTime, setHoverTime] = useState<number | null>(null);
  const reducedMotion = useReducedMotion();

  // Plays the clip in a loop inside the trimmed range, like the editor does.
  useEffect(() => {
    if (reducedMotion) return;
    let frame = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const delta = (now - last) / 1000;
      last = now;
      setPlayhead((time) => (time + delta >= trim.end || time < trim.start ? trim.start : time + delta));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [reducedMotion, trim.start, trim.end]);

  function timeAt(clientX: number) {
    const bounds = trackRef.current?.getBoundingClientRect();
    if (!bounds) return 0;
    return clamp((clientX - bounds.left) / bounds.width, 0, 1) * duration;
  }

  function dragHandle(edge: "start" | "end") {
    return {
      onPointerDown: (event: PointerEvent<HTMLSpanElement>) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        event.stopPropagation();
      },
      onPointerMove: (event: PointerEvent<HTMLSpanElement>) => {
        if (!event.currentTarget.hasPointerCapture(event.pointerId)) return;
        const time = timeAt(event.clientX);
        setTrim((current) =>
          edge === "start"
            ? { ...current, start: clamp(time, 0, current.end - minimumLength) }
            : { ...current, end: clamp(time, current.start + minimumLength, duration) },
        );
      },
    };
  }

  const shown = clamp(playhead, trim.start, trim.end);

  return (
    <div className="relative aspect-video overflow-hidden rounded-[14px] bg-[#10142a]">
      <div
        aria-hidden="true"
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(60% 80% at 20% 30%, #3c33b8 0%, transparent 60%), radial-gradient(60% 70% at 85% 60%, #0f9c8b 0%, transparent 60%)",
        }}
      />
      <p className="absolute inset-x-0 top-3 text-center text-sm font-semibold text-white/90">Kapture 2026-10-23 at 17.17.02</p>

      <div className="absolute inset-x-0 bottom-0 flex items-center gap-3.5 bg-gradient-to-b from-transparent to-black/70 px-4.5 pt-7 pb-3.5 font-mono text-xs text-white tabular-nums">
        <span>{timecode(shown - trim.start)}</span>
        <div
          ref={trackRef}
          role="slider"
          tabIndex={0}
          aria-label="Playhead"
          aria-valuemin={0}
          aria-valuemax={duration}
          aria-valuenow={Math.round(shown * 10) / 10}
          className="group relative h-6.5 flex-1 cursor-pointer"
          onPointerMove={(event) => setHoverTime(timeAt(event.clientX))}
          onPointerLeave={() => setHoverTime(null)}
          onClick={(event) => setPlayhead(clamp(timeAt(event.clientX), trim.start, trim.end))}
          onKeyDown={(event) => {
            const step = event.key === "ArrowRight" ? 0.5 : event.key === "ArrowLeft" ? -0.5 : 0;
            if (step === 0) return;
            event.preventDefault();
            setPlayhead((time) => clamp(time + step, trim.start, trim.end));
          }}
        >
          <span className="absolute inset-x-0 top-[11px] h-1 rounded-full bg-white/25" />
          <span className="absolute top-[11px] h-1 bg-white/50" style={{ left: percent(trim.start), width: percent(trim.end - trim.start) }} />
          <span className="bg-kap-ring absolute top-[11px] h-1" style={{ left: percent(trim.start), width: percent(shown - trim.start) }} />
          {(["start", "end"] as const).map((edge) => (
            <span
              key={edge}
              aria-hidden="true"
              {...dragHandle(edge)}
              className="absolute top-1 -ml-[3px] h-[18px] w-1.5 cursor-ew-resize rounded-[3px] bg-white shadow-[0_1px_3px_rgb(0_0_0/0.4)]"
              style={{ left: percent(trim[edge]) }}
            />
          ))}
          {hoverTime !== null && (
            <span
              className="pointer-events-none absolute bottom-8.5 -ml-15 grid aspect-video w-30 place-items-end justify-center overflow-hidden rounded-lg border border-white/40 pb-1.5"
              style={{
                left: `${clamp((hoverTime / duration) * 100, 8, 92)}%`,
                background:
                  "radial-gradient(70% 90% at 30% 30%, #4b41d6, transparent 65%), radial-gradient(60% 80% at 90% 70%, #13b5a1, transparent 60%), #151a35",
              }}
            >
              <span className="rounded-[5px] bg-black/55 px-1.5 py-0.5">
                {timecode(Math.max(0, hoverTime - trim.start))} ({timecode(hoverTime)})
              </span>
            </span>
          )}
        </div>
        <span>{timecode(trim.end - trim.start)}</span>
      </div>
    </div>
  );
}
