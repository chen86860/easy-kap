import { cn } from "cn";

/** Kap's gradient ring, the mark Easy Kap keeps from the original. */
export function KapRing({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn("bg-kap-ring inline-block aspect-square rounded-full", className)}
      style={{ mask: "radial-gradient(circle, transparent 58%, #000 60%)" }}
    />
  );
}
