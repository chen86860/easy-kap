import { cn } from "cn";
import { AnimatePresence, motion } from "motion/react";
import { type PointerEvent, useRef, useState } from "react";

import { AppleLogo } from "@/components/apple-logo";
import { useElementSize } from "@/hooks/useElementSize";
import { useNow } from "@/hooks/useNow";
import { fit, type Handle, handles, moved, pointSize, type Rect, resized } from "@/lib/selection";
import { timecode } from "@/lib/timecode";

/** The screen the demo stands in for: a 14-inch MacBook Pro at its default scaling. */
const screenPoints = 1512;
const menuBarHeight = 32;
const minimumSize = 40;
/** The menu bar clock, in the visitor's own language and time zone, as their Mac would show it. */
const clockFormat = new Intl.DateTimeFormat(undefined, { weekday: "short", hour: "numeric", minute: "2-digit" });

const handlePosition: Record<Handle, string> = {
  nw: "left-0 top-0 cursor-nwse-resize",
  n: "left-1/2 top-0 cursor-ns-resize",
  ne: "left-full top-0 cursor-nesw-resize",
  e: "left-full top-1/2 cursor-ew-resize",
  se: "left-full top-full cursor-nwse-resize",
  s: "left-1/2 top-full cursor-ns-resize",
  sw: "left-0 top-full cursor-nesw-resize",
  w: "left-0 top-1/2 cursor-ew-resize",
};

function defaultRect(width: number, height: number): Rect {
  const w = width * 0.62;
  return { x: (width - w) / 2, y: height * 0.17, w, h: Math.min((w * 9) / 16, height * 0.62) };
}

interface Drag {
  handle: Handle | "move";
  startX: number;
  startY: number;
  start: Rect;
}

/** A working copy of Easy Kap's area picker: drag the area, pull a handle, press record, stop from the menu bar. */
export function AreaPickerDemo() {
  const deskRef = useRef<HTMLDivElement>(null);
  const size = useElementSize(deskRef);
  const [custom, setCustom] = useState<Rect | null>(null);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [showsSaved, setShowsSaved] = useState(false);
  const drag = useRef<Drag | null>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const now = useNow(startedAt !== null);
  const clock = useNow(true, 10_000);

  const isRecording = startedAt !== null;
  const rect = size ? fit(custom ?? defaultRect(size.width, size.height), { ...size, top: menuBarHeight }, minimumSize) : null;
  const points = rect && size ? pointSize(rect, size.width, screenPoints) : { width: 1058, height: 595 };
  const elapsed = startedAt === null ? 0 : (now - startedAt) / 1000;

  function startDrag(event: PointerEvent<HTMLDivElement>) {
    if (isRecording || !rect) return;
    const handle = (event.target as HTMLElement).dataset.handle as Handle | undefined;
    drag.current = { handle: handle ?? "move", startX: event.clientX, startY: event.clientY, start: rect };
    event.currentTarget.setPointerCapture(event.pointerId);
    event.preventDefault();
  }

  function continueDrag(event: PointerEvent<HTMLDivElement>) {
    const current = drag.current;
    if (!current) return;
    const dx = event.clientX - current.startX;
    const dy = event.clientY - current.startY;
    setCustom(current.handle === "move" ? moved(current.start, dx, dy) : resized(current.start, current.handle, dx, dy, minimumSize));
  }

  function startRecording() {
    setShowsSaved(false);
    setStartedAt(Date.now());
  }

  function stopRecording() {
    if (!isRecording) return;
    setStartedAt(null);
    setShowsSaved(true);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setShowsSaved(false), 2600);
  }

  return (
    <div>
      <div
        ref={deskRef}
        className="bg-dots border-line-strong relative aspect-[4/5] max-w-full touch-none overflow-hidden rounded-3xl border shadow-[0_32px_64px_-32px_rgb(24_24_27/0.35)] select-none sm:aspect-[16/9.4]"
      >
        <div className="absolute inset-x-0 top-0 z-(--z-chrome) flex h-8 items-center justify-between bg-white/60 px-4 text-xs font-medium backdrop-blur-md">
          <div className="flex items-center gap-4">
            <AppleLogo className="-mt-px size-3.5" />
            <b>Easy Kap</b>
            <span>File</span>
            <span>Edit</span>
            <span className="hidden sm:inline">Window</span>
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={stopRecording}
              aria-label={isRecording ? "Stop recording" : "Easy Kap menu bar icon"}
              className="inline-flex items-center gap-2 rounded-md px-2 py-0.5 hover:bg-ink/10 transition-colors duration-300"
            >
              <span className={cn("relative size-3.5 rounded-full border-2", isRecording ? "border-rec" : "border-ink")}>
                {isRecording && <span className="bg-rec absolute inset-0.5 rounded-full" />}
              </span>
              {isRecording && <span className="font-mono tabular-nums">{timecode(elapsed)}</span>}
            </button>
            <span className="font-mono">{clockFormat.format(clock)}</span>
          </div>
        </div>

        {/* The window worth recording. */}
        <div
          aria-hidden="true"
          className="bg-surface border-line-strong absolute top-[12%] left-[6%] grid h-[46%] w-[74%] grid-rows-[32px_1fr] overflow-hidden rounded-xl border shadow-[0_24px_48px_-16px_rgb(24_24_27/0.25)] sm:top-[15%] sm:left-[9%] sm:h-[64%] sm:w-[58%]"
        >
          <header className="border-line flex items-center gap-2 border-b px-3">
            <i className="bg-line-strong size-2.5 rounded-full" />
            <i className="bg-line-strong size-2.5 rounded-full" />
            <i className="bg-line-strong size-2.5 rounded-full" />
            <span className="text-muted-foreground ml-2 text-xs">Q3 launch review</span>
          </header>
          <div className="grid content-start gap-[7%] px-[7%] py-[6%]">
            <div className="flex h-16 items-end gap-[5%]">
              {[40, 75, 55, 95, 65].map((height, index) => (
                <i
                  key={height}
                  className="chart-bar bg-accent flex-1 rounded-t-md rounded-b-sm"
                  style={{ height: `${height}%`, opacity: 0.4 + height / 160, animationDelay: `${-index * 0.6}s` }}
                />
              ))}
            </div>
            <div className="grid gap-2">
              <i className="bg-line-strong h-2 rounded" />
              <i className="bg-line-strong h-2 w-4/5 rounded" />
              <i className="bg-line-strong h-2 w-3/5 rounded" />
            </div>
          </div>
        </div>
        <div
          aria-hidden="true"
          className="bg-surface border-line text-muted-foreground absolute top-[58%] right-[5%] aspect-square w-[32%] rotate-3 rounded-lg border p-[3%] text-xs font-medium shadow-[0_16px_32px_-16px_rgb(24_24_27/0.3)] sm:top-[24%] sm:right-[8%] sm:w-[21%] lg:text-sm"
        >
          Record the new onboarding flow for the design review
        </div>

        {rect && (
          <div
            role="group"
            aria-label="Recording area. Drag to move, or drag a handle to resize."
            onPointerDown={startDrag}
            onPointerMove={continueDrag}
            onPointerUp={() => (drag.current = null)}
            onPointerCancel={() => (drag.current = null)}
            onClick={stopRecording}
            className={cn(
              "absolute z-(--z-overlay)",
              isRecording
                ? "marching cursor-default outline-2 outline-white outline-dashed"
                : "cursor-grab shadow-[0_0_0_9999px_rgb(24_24_27/0.22)] outline-[1.5px] outline-white outline-solid active:cursor-grabbing",
            )}
            style={{ left: rect.x, top: rect.y, width: rect.w, height: rect.h }}
          >
            <span className="absolute -top-8 left-0 bg-ink rounded-md px-2 py-1 font-mono text-xs whitespace-nowrap text-white tabular-nums">
              {points.width} × {points.height}
            </span>
            {!isRecording &&
              handles.map((handle) => (
                <span
                  key={handle}
                  data-handle={handle}
                  className={cn(
                    "absolute -m-1.5 size-3 rounded-full bg-white shadow-[0_0_0_1px_rgb(0_0_0/0.4)]",
                    handlePosition[handle],
                  )}
                />
              ))}
          </div>
        )}

        <ActionBar width={points.width} height={points.height} hidden={isRecording} onRecord={startRecording} />

        <AnimatePresence>
          {isRecording && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="pointer-events-none absolute bottom-[6%] left-1/2 z-(--z-toast) -translate-x-1/2 rounded-full bg-black/80 px-4 py-2 text-xs whitespace-nowrap text-white backdrop-blur-md sm:text-sm"
            >
              Recording · click the red ring in the menu bar to stop
            </motion.div>
          )}
          {showsSaved && (
            <motion.div
              role="status"
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              className="keycap absolute top-12 right-[3%] z-(--z-toast) flex items-center gap-3 rounded-xl px-4 py-3 text-sm"
            >
              <span className="bg-accent text-accent-foreground grid h-10 w-8 place-items-end justify-center rounded-sm pb-1 font-mono text-xs font-semibold">
                GIF
              </span>
              <span>
                <b className="block">Kapture 2026-10-23 at 18.47.02.gif</b>
                <span className="text-muted-foreground">Opening the editor…</span>
              </span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

function ActionBar({ width, height, hidden, onRecord }: { width: number; height: number; hidden: boolean; onRecord: () => void }) {
  const icon = "size-4.5 flex-none fill-none stroke-ink stroke-[1.8]";
  const field = "border-line-strong min-w-12 rounded-md border px-2 py-1 text-center font-mono text-xs tabular-nums";
  return (
    <div
      className={cn(
        "keycap ease-out-quint absolute bottom-[4%] left-1/2 z-(--z-chrome) flex -translate-x-1/2 items-center gap-2 rounded-full py-2 pr-2 pl-3 whitespace-nowrap transition duration-500 sm:bottom-[5%] sm:gap-3 sm:pl-4",
        hidden && "pointer-events-none translate-y-3 opacity-0",
      )}
    >
      <svg className={cn(icon, "hidden sm:block")} viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 6l12 12M18 6L6 18" />
      </svg>
      <span className="bg-line-strong hidden h-5 w-px sm:block" />
      <span className="hidden items-center gap-2 text-sm font-semibold sm:inline-flex">
        <svg className={icon} viewBox="0 0 24 24" aria-hidden="true">
          <rect x="5" y="11" width="14" height="9" rx="2" />
          <path d="M8 11V8a4 4 0 0 1 7.5-2" />
        </svg>
        Free
      </span>
      <span className={field}>{width}</span>
      <span aria-hidden="true">×</span>
      <span className={field}>{height}</span>
      <span className="bg-line-strong h-5 w-px" />
      <svg className={cn(icon, "hidden sm:block")} viewBox="0 0 24 24" aria-hidden="true">
        <rect x="3" y="4" width="18" height="12" rx="2" />
        <path d="M9 20h6M12 16v4" />
      </svg>
      <svg className={cn(icon, "hidden sm:block")} viewBox="0 0 24 24" aria-hidden="true">
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="M3 9h18" />
      </svg>
      <button
        type="button"
        onClick={onRecord}
        aria-label="Start recording"
        className="bg-rec ease-out-quint grid size-10 place-items-center rounded-full shadow-[0_8px_16px_-8px_rgb(255_69_58/0.7)] transition-transform duration-300 hover:scale-105 active:scale-[0.98]"
      >
        <span className="size-3 rounded-full bg-white" />
      </button>
    </div>
  );
}
