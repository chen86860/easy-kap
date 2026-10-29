import { CheckIcon, CopyIcon } from "@phosphor-icons/react";
import { cn } from "cn";
import { useRef, useState } from "react";

import { captureEvent } from "@/lib/analytics";

/** A shell command on one line with a copy button; when the clipboard is unavailable the command is selected for ⌘C instead. */
export function CopyCommand({ command, className }: { command: string; className?: string }) {
  const [state, setState] = useState<"idle" | "copied" | "select">("idle");
  const textRef = useRef<HTMLElement>(null);
  const resetTimer = useRef<ReturnType<typeof setTimeout>>(undefined);

  async function copy() {
    clearTimeout(resetTimer.current);
    try {
      await navigator.clipboard.writeText(command);
      setState("copied");
      captureEvent("website_command_copied", { command });
    } catch {
      if (textRef.current) window.getSelection()?.selectAllChildren(textRef.current);
      setState("select");
    }
    resetTimer.current = setTimeout(() => setState("idle"), 2000);
  }

  return (
    <div className={cn("keycap flex max-w-full items-center gap-2 rounded-xl py-1 pr-1 pl-4 font-mono text-sm", className)}>
      <span aria-hidden="true" className="text-accent select-none">
        $
      </span>
      <code ref={textRef} className="min-w-0 overflow-x-auto py-2 whitespace-nowrap">
        {command}
      </code>
      <button
        type="button"
        onClick={copy}
        aria-label="Copy the Homebrew command"
        className="text-muted-foreground hover:text-foreground hover:bg-ink/5 grid size-9 flex-none place-items-center rounded-lg transition-colors duration-300 active:scale-[0.98]"
      >
        {state === "copied" ? <CheckIcon className="text-accent size-4" weight="bold" aria-hidden="true" /> : <CopyIcon className="size-4" aria-hidden="true" />}
      </button>
      <span role="status" className="sr-only">
        {state === "copied" ? "Copied to the clipboard." : state === "select" ? "Couldn't copy. The command is selected, press ⌘C." : ""}
      </span>
    </div>
  );
}
