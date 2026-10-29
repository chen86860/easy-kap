import {
  AppWindowIcon,
  ArrowsClockwiseIcon,
  CursorClickIcon,
  CopyIcon,
  FilmStripIcon,
  FloppyDiskIcon,
  FolderSimpleIcon,
  GithubLogoIcon,
  type Icon,
  PauseIcon,
  ScissorsIcon,
  SelectionIcon,
  WaveformIcon,
} from "@phosphor-icons/react";
import { createFileRoute } from "@tanstack/react-router";
import { cn } from "cn";
import { motion } from "motion/react";
import type { PointerEvent, ReactNode } from "react";

import { AreaPickerDemo } from "@/components/area-picker-demo";
import { CopyCommand } from "@/components/copy-command";
import { DownloadButton } from "@/components/download-button";
import { KapRing } from "@/components/kap-ring";
import { Frame, Points, Section, SectionHeading } from "@/components/section";
import { TrimDemo } from "@/components/trim-demo";
import { useActiveSection } from "@/hooks/useActiveSection";
import { captureEvent } from "@/lib/analytics";
import { changelogURL, kapURL, licenseURL, releasesURL, repositoryURL } from "@/lib/site";

export const Route = createFileRoute("/")({ component: Home });

const ease = [0.22, 1, 0.36, 1] as const;

const navigation = [
  ["features", "Features"],
  ["editor", "Editor"],
  ["export", "Export"],
  ["install", "Install"],
] as const;

/** Six keys in two staggered rows, like a keyboard: a bold claim, then the plain reason. */
const keys: { icon: Icon; title: string; text: string }[] = [
  { icon: SelectionIcon, title: "Any area.", text: "Drag a box, type a size, or pick a window." },
  { icon: WaveformIcon, title: "Both sides.", text: "System audio and your microphone, in sync." },
  { icon: PauseIcon, title: "Pause.", text: "Carry on later without encoding twice." },
  { icon: ScissorsIcon, title: "Trim.", text: "Two handles and a looping preview." },
  { icon: FilmStripIcon, title: "Four formats.", text: "GIF, MP4, HEVC and APNG." },
  { icon: ArrowsClockwiseIcon, title: "Current.", text: "Updates arrive in the background." },
];

const formats = [
  { name: "GIF", engine: "ImageIO · up to 50 fps", summary: "For READMEs and chats. Loops forever by default." },
  { name: "MP4", engine: "VideoToolbox · H.264", summary: "Plays everywhere. System audio and microphone are mixed into one track." },
  { name: "HEVC", engine: "VideoToolbox · H.265", summary: "The same picture as MP4 in a smaller file." },
  { name: "APNG", engine: "ImageIO · up to 60 fps", summary: "Animated PNG with full color and no dithering." },
];

const scaleOptions = ["1280 x 720 (Original)", "960 x 540 (75%)", "640 x 360 (50%)", "422 x 237 (33%)"];

/** Moves the dot field's teal spotlight to the pointer, by CSS variables so nothing re-renders. */
function followPointer(event: PointerEvent<HTMLElement>) {
  if (event.pointerType !== "mouse") return;
  const bounds = event.currentTarget.getBoundingClientRect();
  event.currentTarget.style.setProperty("--x", `${event.clientX - bounds.left}px`);
  event.currentTarget.style.setProperty("--y", `${event.clientY - bounds.top}px`);
}

function DotField() {
  return <div aria-hidden="true" className="dot-field pointer-events-none absolute inset-0 -z-10" />;
}

function Key({ children, active, className }: { children: ReactNode; active?: boolean; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex h-8 items-center gap-2 rounded-lg px-3 text-sm font-medium",
        active ? "keycap-ink" : "keycap text-muted-foreground",
        className,
      )}
    >
      {children}
    </span>
  );
}

function Home() {
  const active = useActiveSection(navigation.map(([id]) => id));
  return (
    <>
      <a
        href="#main"
        className="keycap-ink fixed top-4 left-4 z-(--z-nav) -translate-y-24 rounded-lg px-3 py-2 text-sm font-semibold transition-transform duration-300 focus:translate-y-0"
      >
        Skip to content
      </a>

      {/* Floats just off the top edge and stays with the page. */}
      <header className="sticky top-[calc(env(safe-area-inset-top,0px)+16px)] z-(--z-nav) mx-auto mt-4 grid max-w-300 grid-cols-[1fr_auto] items-center gap-4 rounded-2xl border border-white/80 bg-white/70 py-2 pr-2 pl-4 shadow-[0_0_0_1px_rgb(24_24_27/0.06),0_8px_24px_-12px_rgb(24_24_27/0.18)] backdrop-blur-xl md:grid-cols-[1fr_auto_1fr]">
        <a href="#top" className="flex items-center gap-2 justify-self-start rounded-lg py-1 font-semibold" aria-label="Easy Kap home">
          <KapRing className="size-5" />
          Easy Kap
        </a>
        <nav aria-label="Primary" className="hidden items-center gap-1 text-sm font-medium md:flex">
          {navigation.map(([id, label]) => (
            <a
              key={id}
              href={`#${id}`}
              aria-current={active === id ? "location" : undefined}
              className={cn(
                "rounded-lg px-3 py-1.5 transition-colors duration-300",
                active === id ? "text-foreground bg-ink/5" : "text-muted-foreground hover:text-foreground",
              )}
            >
              {label}
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-2 justify-self-end">
          <a
            href={repositoryURL}
            onClick={() => captureEvent("website_github_clicked", { placement: "header" })}
            aria-label="Easy Kap on GitHub"
            className="text-muted-foreground hover:text-foreground hover:bg-ink/5 grid size-9 place-items-center rounded-lg transition-colors duration-300"
          >
            <GithubLogoIcon className="size-5" aria-hidden="true" />
          </a>
          <DownloadButton placement="header" size="sm" />
        </div>
      </header>

      <div className="mx-auto max-w-300">
        <main id="main">
          <section id="top" aria-labelledby="hero-title" onPointerMove={followPointer} className="relative isolate pt-24 pb-16 text-center sm:pt-32">
            <DotField />
            <motion.div
              className="mx-auto grid max-w-170 justify-items-center gap-6"
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease }}
            >
              <h1 id="hero-title" className="text-hero text-5xl font-semibold tracking-[-0.04em] sm:text-7xl">
                Record any part of your Mac.
              </h1>
              <p className="text-muted-foreground max-w-[52ch] text-lg sm:text-xl">
                A fast, native screen recorder. Pick an area, a window or a screen, trim it, and share a crisp GIF or MP4 in seconds.
              </p>
              <DownloadButton placement="hero" className="mt-4" />
              <div className="text-muted-foreground grid gap-2 font-mono text-xs text-balance">
                <span>Free and open source · macOS 15 or later · Apple Silicon and Intel</span>
                <span className="flex items-center justify-center gap-2">
                  <a href="#download" className="hover:text-foreground transition-colors duration-300">
                    Install via Homebrew
                  </a>
                  <span aria-hidden="true">|</span>
                  <a href={releasesURL} className="hover:text-foreground transition-colors duration-300">
                    All releases
                  </a>
                </span>
              </div>
            </motion.div>
          </section>

          <section aria-labelledby="demo-title" className="pb-24">
            <SectionHeading
              id="demo-title"
              title="Take the shot, not the detour."
              lede="The area picker on this page works the way it does on your Mac."
              className="mx-auto mb-16 text-center"
            />
            {/* The desk tips up into place, like a lid opening. It stays fully visible throughout. */}
            <motion.div
              className="keycap rounded-4xl p-2"
              style={{ transformPerspective: 1400 }}
              initial={{ rotateX: 16, y: 48, scale: 0.96 }}
              animate={{ rotateX: 0, y: 0, scale: 1 }}
              transition={{ duration: 1.1, delay: 0.3, ease }}
            >
              <AreaPickerDemo />
            </motion.div>
            <p className="text-muted-foreground mt-4 flex items-center justify-center gap-2 text-center text-sm">
              <CursorClickIcon className="size-4 flex-none" aria-hidden="true" />
              Interactive demo. Drag the area, pull a handle, then press the red button to record.
            </p>
          </section>

          <Section id="features" title="It's not about recording more." lede="It's about sharing what you meant to show, the first time.">
            {/* Two staggered rows, like keys on a keyboard. */}
            <ul className="grid gap-6">
              {[keys.slice(0, 3), keys.slice(3)].map((row, rowIndex) => (
                <li key={rowIndex} className={cn("grid gap-6 sm:grid-cols-3", rowIndex === 0 ? "lg:pr-16" : "lg:pl-16")}>
                  {row.map(({ icon: Icon, title, text }) => (
                    <article
                      key={title}
                      className="keycap ease-out-quint grid content-between gap-6 rounded-xl p-8 transition-transform duration-500 hover:-translate-y-1 sm:min-h-48"
                    >
                      <Icon className="text-muted-foreground size-7" aria-hidden="true" />
                      <p className="text-muted-foreground text-lg">
                        <b className="text-foreground font-medium">{title}</b> {text}
                      </p>
                    </article>
                  ))}
                </li>
              ))}
            </ul>
          </Section>

          <Section
            id="capture"
            title="Pick exactly what to record."
            lede="ScreenCaptureKit writes H.264 straight to disk, so what you see in the editor is the file itself."
          >
            <div className="grid gap-6 md:grid-cols-2">
              <Frame
                title="The area picker"
                icon={<SelectionIcon className="size-5" aria-hidden="true" />}
                visual={
                  <div className="grid justify-items-center gap-4">
                    <div className="flex flex-wrap justify-center gap-2">
                      <Key>Free</Key>
                      <Key active>16:9</Key>
                      <Key>4:3</Key>
                      <Key>1:1</Key>
                    </div>
                    <Key className="font-mono tabular-nums">1280 × 720</Key>
                  </div>
                }
              >
                <Points
                  items={[
                    "Drag any rectangle, or type an exact size such as 1280 × 720.",
                    "Lock 16:9, 4:3, 1:1 and other ratios while you resize.",
                    "Choose a whole screen, or an app's window from a list with its icon.",
                    "Opens on the area you recorded last time, even after a restart.",
                  ]}
                />
              </Frame>
              <Frame
                title="While it records"
                icon={<WaveformIcon className="size-5" aria-hidden="true" />}
                visual={
                  <div className="keycap flex items-center gap-3 rounded-xl px-4 py-2 text-sm">
                    <span className="border-rec relative size-4 rounded-full border-2">
                      <span className="bg-rec absolute inset-0.5 rounded-full" />
                    </span>
                    <span className="font-mono tabular-nums">00:42</span>
                    <span className="bg-line h-4 w-px" />
                    <PauseIcon className="text-muted-foreground size-4" weight="fill" aria-hidden="true" />
                    <span className="text-muted-foreground">Pause</span>
                  </div>
                }
              >
                <Points
                  items={[
                    "Pause and resume from the menu bar, with the time recorded so far.",
                    "Record system audio, your microphone, or both.",
                    "Show the cursor and highlight clicks, drawn by the system itself.",
                    "Easy Kap's own windows never appear in the recording.",
                  ]}
                />
              </Frame>
            </div>
          </Section>

          <Section
            id="editor"
            title="Trim it while it loops."
            lede="The recording plays on repeat as soon as you stop. Hover the track to see a frame before you commit."
          >
            <article className="keycap grid items-center gap-12 rounded-2xl p-8 sm:p-10 lg:grid-cols-12 lg:gap-16">
              <div className="grid content-start gap-6 lg:col-span-5">
                <h3 className="flex items-center gap-3 text-xl font-medium">
                  <ScissorsIcon className="size-5" aria-hidden="true" />
                  Quick edits, no timeline
                </h3>
                <Points
                  items={[
                    "Drag the two handles to keep only the part that matters. Press I or O to set them at the playhead.",
                    "Resize with real numbers: every scale option shows the size you'll get.",
                    "Set the frame rate up to the recording's own, 30 or 60 fps.",
                    "Mute the audio, then convert with ⌘E.",
                    "Closing an unexported recording asks first, so nothing disappears by accident.",
                  ]}
                />
              </div>
              <div className="lg:col-span-7">
                <TrimDemo />
              </div>
            </article>
          </Section>

          <Section
            id="export"
            title="Four formats, no extra downloads."
            lede="VideoToolbox for video, ImageIO for animated images. Both already ship with macOS."
          >
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              {formats.map((format) => (
                <article key={format.name} className="keycap grid content-start gap-3 rounded-xl p-8">
                  <span className="text-muted-foreground font-mono text-xs">{format.engine}</span>
                  <b className="text-3xl font-semibold tracking-tight">{format.name}</b>
                  <p className="text-muted-foreground">{format.summary}</p>
                </article>
              ))}
            </div>
            <div className="mt-6 grid gap-6 md:grid-cols-2">
              <Frame
                title="Scale with the result in front of you"
                visual={
                  <div
                    aria-label="Scale options for a 1280 × 720 recording"
                    className="keycap grid w-full max-w-72 gap-0.5 rounded-xl p-1 font-mono text-sm tabular-nums"
                  >
                    {scaleOptions.map((option, index) => (
                      <div
                        key={option}
                        className={index === 0 ? "bg-ink relative rounded-lg py-2 pr-3 pl-8 text-white" : "text-muted-foreground py-2 pr-3 pl-8"}
                      >
                        {index === 0 && <span className="absolute left-3">✓</span>}
                        {option}
                      </div>
                    ))}
                  </div>
                }
              />
              <Frame
                title="Send it where it's going"
                visual={
                  <div className="flex flex-wrap justify-center gap-2">
                    <Key>
                      <FloppyDiskIcon className="size-4" aria-hidden="true" />
                      Save to Disk
                    </Key>
                    <Key active>
                      <CopyIcon className="size-4" aria-hidden="true" />
                      Copy
                    </Key>
                    <Key>
                      <AppWindowIcon className="size-4" aria-hidden="true" />
                      Open With
                    </Key>
                  </div>
                }
              >
                <Points
                  items={[
                    <>
                      <b>Save to Disk</b>, named after the moment you recorded it.
                    </>,
                    <>
                      <b>Copy to Clipboard</b>, ready to paste into Slack, GitHub or Mail.
                    </>,
                    <>
                      <b>Open With</b> any app that opens the format, with your default app first.
                    </>,
                  ]}
                />
              </Frame>
            </div>
          </Section>

          <Section
            id="install"
            title="Download, drag, record."
            lede="A signed, notarized disk image, built from the public source by GitHub Actions."
          >
            <ol className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              {[
                <>
                  Download <b className="text-foreground font-medium">EasyKap.dmg</b> from the latest release.
                </>,
                "Open it and drag Easy Kap into Applications.",
                "Open Easy Kap. Apple has notarized it, so it opens like any other app.",
                "Allow Screen Recording when macOS asks, then reopen Easy Kap.",
              ].map((step, index) => (
                // Static copy: the order is the identity.
                <li key={index} className="keycap grid content-start gap-8 rounded-xl p-8">
                  <Key className="size-8 justify-center px-0 font-mono text-xs">{index + 1}</Key>
                  <p className="text-muted-foreground">{step}</p>
                </li>
              ))}
            </ol>
            <ul className="text-muted-foreground mt-16 grid gap-8 text-sm md:grid-cols-3">
              {(
                [
                  [CursorClickIcon, "Click the ring in the menu bar to start, or set a shortcut in Settings."],
                  [FolderSimpleIcon, "Exports land in ~/Movies/Kaptures."],
                  [ArrowsClockwiseIcon, "Updates install themselves, or choose Check for Updates from the menu bar."],
                ] as const
              ).map(([Icon, tip]) => (
                <li key={tip} className="grid grid-cols-[20px_1fr] gap-3">
                  <Icon className="text-foreground mt-0.5 size-5" aria-hidden="true" />
                  {tip}
                </li>
              ))}
            </ul>
          </Section>

          <section
            aria-labelledby="closing-title"
            onPointerMove={followPointer}
            id="download"
            className="relative isolate grid scroll-mt-24 justify-items-center gap-8 pt-24 pb-32 text-center"
          >
            <DotField />
            <span className="keycap grid size-20 place-items-center rounded-2xl">
              <KapRing className="size-10" />
            </span>
            <SectionHeading id="closing-title" title="Record your first clip." lede="Free, open source, and installed in under a minute." />
            <div className="grid w-full justify-items-center gap-4">
              <DownloadButton placement="closing" />
              <span className="text-muted-foreground font-mono text-xs">or with Homebrew</span>
              <CopyCommand command="brew install --cask chen86860/tap/easy-kap" />
            </div>
          </section>
        </main>

        <footer className="text-muted-foreground border-line grid gap-8 border-t pt-12 pb-16 text-sm sm:grid-cols-[1fr_auto] sm:items-end">
          <div className="grid gap-3">
            <span className="text-foreground flex items-center gap-2 text-base font-semibold">
              <KapRing className="size-5" />
              Easy Kap
            </span>
            <p className="max-w-[44ch]">
              A free, native screen recorder for macOS. Inspired by{" "}
              <a className="hover:text-foreground underline underline-offset-4 transition-colors duration-300" href={kapURL}>
                Kap
              </a>
              .
            </p>
          </div>
          <nav aria-label="Footer" className="flex flex-wrap gap-x-6 gap-y-2">
            <a
              href={repositoryURL}
              onClick={() => captureEvent("website_github_clicked", { placement: "footer" })}
              className="hover:text-foreground transition-colors duration-300"
            >
              GitHub
            </a>
            <a href={releasesURL} className="hover:text-foreground transition-colors duration-300">
              Releases
            </a>
            <a href={changelogURL} className="hover:text-foreground transition-colors duration-300">
              Changelog
            </a>
            <a href={licenseURL} className="hover:text-foreground transition-colors duration-300">
              MIT License
            </a>
          </nav>
        </footer>
      </div>
    </>
  );
}
