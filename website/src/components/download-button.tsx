import { cn } from "cn";
import { Download } from "lucide-react";

import { buttonVariants } from "@/components/ui/button";
import { dmgURL } from "@/lib/site";

export function DownloadButton({ className }: { className?: string }) {
  return (
    <a href={dmgURL} className={cn(buttonVariants({ size: "lg" }), "h-12 rounded-full px-5 text-base shadow-[0_10px_24px_rgb(20_24_41/0.22)]", className)}>
      <Download data-icon="inline-start" />
      Download for macOS
    </a>
  );
}
