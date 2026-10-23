import { cn } from "cn";
import { Download } from "lucide-react";
import type { ReactNode } from "react";

import { captureEvent } from "@/lib/analytics";
import { dmgURL } from "@/lib/site";

/** The two hero-sized calls to action share one shape so they line up. */
const cta =
  "group relative isolate inline-flex h-13 items-center gap-2.5 rounded-full px-7 text-[1.05rem] font-semibold whitespace-nowrap transition duration-200 hover:-translate-y-0.5 focus-visible:outline-2 focus-visible:outline-offset-4";

/** The primary download, with a slowly turning ring-gradient glow that brightens and a sheen that sweeps on hover. */
export function DownloadButton({ placement, className }: { placement: string; className?: string }) {
  return (
    <a
      href={dmgURL}
      onClick={() => captureEvent("website_download_clicked", { placement })}
      className={cn(cta, "bg-ink text-white shadow-[0_14px_30px_-10px_rgb(20_24_41/0.45)]", className)}
    >
      <span aria-hidden="true" className="cta-glow absolute -inset-0.75 -z-10 rounded-full opacity-55 blur-[10px] transition-opacity duration-300 group-hover:opacity-100" />
      <span aria-hidden="true" className="cta-sheen absolute inset-0 -z-10 overflow-hidden rounded-full bg-ink" />
      <Download className="size-5 transition-transform duration-300 group-hover:translate-y-0.5" />
      Download for macOS
    </a>
  );
}

export function SecondaryButton({ href, children, className }: { href: string; children: ReactNode; className?: string }) {
  return (
    <a
      href={href}
      className={cn(cta, "bg-panel border-line hover:border-violet/50 border text-ink shadow-[0_8px_20px_-14px_rgb(20_24_41/0.4)]", className)}
    >
      {children}
    </a>
  );
}
