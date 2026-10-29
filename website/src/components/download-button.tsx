import { cn } from "cn";

import { AppleLogo } from "@/components/apple-logo";
import { captureEvent } from "@/lib/analytics";
import { dmgURL } from "@/lib/site";

/** The one filled button on the page: a dark keycap that lifts a little on hover and presses in on click. */
export function DownloadButton({ placement, size = "base", className }: { placement: string; size?: "base" | "sm"; className?: string }) {
  return (
    <a
      href={dmgURL}
      onClick={() => captureEvent("website_download_clicked", { placement })}
      className={cn(
        "keycap-ink ease-out-quint inline-flex items-center gap-2 rounded-lg px-3 py-2 font-semibold whitespace-nowrap transition duration-300 hover:-translate-y-px hover:bg-[color-mix(in_oklch,var(--ink),white_12%)] active:translate-y-px active:scale-[0.98] focus-visible:outline-offset-4",
        size === "base" ? "text-base" : "text-sm",
        className,
      )}
    >
      <AppleLogo className={cn("-mt-0.5", size === "base" ? "size-4.5" : "size-4")} />
      {size === "base" ? "Download for Mac" : "Download"}
    </a>
  );
}
