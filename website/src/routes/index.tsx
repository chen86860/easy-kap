import { createFileRoute } from "@tanstack/react-router";
import { ArrowDown } from "lucide-react";
import { motion } from "motion/react";
import type { CSSProperties } from "react";

import { AreaPickerDemo } from "@/components/area-picker-demo";
import { DownloadButton, SecondaryButton } from "@/components/download-button";
import { KapRing } from "@/components/kap-ring";
import { Frame, Points, Section } from "@/components/section";
import { TrimDemo } from "@/components/trim-demo";
import { buttonVariants } from "@/components/ui/button";
import { kapURL, releasesURL, repositoryURL } from "@/lib/site";

export const Route = createFileRoute("/")({ component: Home });

const headline: { word: string; ring?: boolean }[] = [
  { word: "The" },
  { word: "Kap", ring: true },
  ...["you", "loved,", "rebuilt", "native", "for", "Apple", "Silicon."].map((word) => ({ word })),
];

const formats = [
  { name: "GIF", engine: "ImageIO · up to 50 fps", summary: "For READMEs and chats. Loops forever by default." },
  { name: "MP4", engine: "VideoToolbox · H.264", summary: "Plays everywhere. System audio and microphone are mixed into one track." },
  { name: "HEVC", engine: "VideoToolbox · H.265", summary: "The same picture as MP4 in a smaller file." },
  { name: "APNG", engine: "ImageIO · up to 60 fps", summary: "Animated PNG with full color and no dithering." },
];

const scaleOptions = ["1280 x 720 (Original)", "960 x 540 (75%)", "640 x 360 (50%)", "422 x 237 (33%)", "320 x 180 (25%)"];

const comparison = [
  { area: "App", kap: "Electron 13 and React", easyKap: "Swift 6, SwiftUI and AppKit" },
  { area: "Recording engine", kap: "AVFoundation, through aperture", easyKap: "ScreenCaptureKit" },
  { area: "Conversion", kap: "Bundled ffmpeg and gifsicle", easyKap: "VideoToolbox and ImageIO, built into macOS" },
  { area: "System audio", kap: "Not available", easyKap: "Yes, alongside the microphone", better: true },
  { area: "Formats", kap: "GIF, MP4, HEVC, APNG, WebM, AV1", easyKap: "GIF, MP4, HEVC, APNG" },
  { area: "Plugins", kap: "Giphy, Streamable and more", easyKap: "Not yet" },
];

function Home() {
  return (
    <div className="mx-auto max-w-280">
      <header className="flex items-center justify-between gap-4 py-5.5">
        <a href="#top" className="font-display flex items-center gap-3 text-[1.05rem] font-bold" aria-label="Easy Kap home">
          <span className="bg-panel border-line grid size-8.5 place-items-center rounded-[10px] border shadow-[0_6px_18px_rgb(20_24_41/0.08)]">
            <KapRing className="size-5" />
          </span>
          Easy Kap
        </a>
        <nav aria-label="Primary" className="flex items-center gap-5.5 font-medium">
          {[
            ["#capture", "Capture"],
            ["#editor", "Editor"],
            ["#export", "Export"],
          ].map(([href, label]) => (
            <a key={href} href={href} className="text-muted-foreground hover:text-foreground hidden sm:inline">
              {label}
            </a>
          ))}
          <a href={repositoryURL} className={buttonVariants({ variant: "outline", className: "bg-panel border-line h-9 rounded-full px-4 shadow-xs" })}>
            GitHub
          </a>
        </nav>
      </header>

      <main id="top">
        <section aria-labelledby="hero-title" className="relative isolate grid gap-12 pt-9 pb-18">
          {/* Drifting light in the ring's two colors. */}
          <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 -top-24 -z-10 h-[620px]">
            <span className="orb bg-violet/25 absolute top-0 -left-24 size-[420px] rounded-full blur-[90px]" />
            <span
              className="orb bg-teal/25 absolute top-24 right-[-8%] size-[380px] rounded-full blur-[90px]"
              style={{ "--drift-x": "-50px", "--drift-y": "40px", animationDelay: "-6s" } as CSSProperties}
            />
          </div>

          <div className="grid max-w-215 gap-6">
            <motion.span
              className="text-muted-foreground font-mono text-xs tracking-[0.08em] uppercase"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4 }}
            >
              Screen recorder for macOS · inspired by Kap
            </motion.span>
            <h1 id="hero-title" aria-label="The Kap you loved, rebuilt native for Apple Silicon." className="text-[clamp(2.4rem,1.3rem+4.4vw,4.6rem)] leading-[1.06]">
              {headline.map(({ word, ring }, index) => (
                <motion.span
                  key={word}
                  aria-hidden="true"
                  className={ring ? "text-kap-ring inline-block" : "inline-block"}
                  initial={{ opacity: 0, y: "0.4em", filter: "blur(10px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  transition={{ duration: 0.6, delay: 0.08 + index * 0.06, ease: [0.22, 1, 0.36, 1] }}
                >
                  {word}
                  {index < headline.length - 1 && "\u00a0"}
                </motion.span>
              ))}
            </h1>
            <motion.div
              className="grid gap-7"
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.6, ease: "easeOut" }}
            >
              <p className="text-muted-foreground max-w-[60ch] text-xl">
                Draw a box around anything on your screen, press Return, and get a GIF, MP4, HEVC or APNG you can drop straight into a pull
                request, a chat or a doc.
              </p>
              <div className="flex flex-wrap items-center gap-4">
                <DownloadButton />
                <SecondaryButton href="#install">
                  How to install
                  <ArrowDown className="text-violet size-4.5 transition-transform duration-300 group-hover:translate-y-0.5" />
                </SecondaryButton>
              </div>
            <div className="text-muted-foreground flex flex-wrap gap-x-4.5 gap-y-2 text-sm">
              {["macOS 15 or later", "Apple Silicon and Intel", "Free and open source, MIT"].map((fact) => (
                <span key={fact} className="inline-flex items-center gap-2">
                  <span aria-hidden="true" className="bg-teal size-1.5 rounded-full" />
                  {fact}
                </span>
              ))}
            </div>
            </motion.div>
          </div>
          {/* The desk tips up into place, like a window opening. It stays fully visible throughout. */}
          <motion.div
            style={{ transformPerspective: 1400 }}
            initial={{ rotateX: 16, y: 48, scale: 0.96 }}
            animate={{ rotateX: 0, y: 0, scale: 1 }}
            transition={{ duration: 1.1, delay: 0.5, ease: [0.22, 1, 0.36, 1] }}
          >
            <AreaPickerDemo />
          </motion.div>
        </section>

        <Section
          id="capture"
          eyebrow="Capture"
          title="Pick exactly what to record"
          lede="Easy Kap records with ScreenCaptureKit and writes H.264 straight to disk, so what you see in the editor is the file itself."
        >
          <div className="grid gap-5.5 md:grid-cols-2">
            <Frame title="The area picker">
              <Points
                items={[
                  "Drag any rectangle, or type an exact size such as 1280 × 720.",
                  "Lock 16:9, 4:3, 1:1 and other ratios while you resize.",
                  "Choose a whole screen, or an app's window from a list with its icon.",
                  "Opens on the area you recorded last time, even after a restart.",
                ]}
              />
            </Frame>
            <Frame title="While it records">
              <Points
                items={[
                  "Pause and resume from the menu bar. The pieces are joined without re-encoding.",
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
          eyebrow="Editor"
          title="Trim it while it loops"
          lede="The recording plays on repeat as soon as you stop. Hover to reveal the trim bar, and hover the track to see that frame before you commit."
        >
          <div className="grid items-start gap-5.5 md:grid-cols-2">
            <TrimDemo />
            <Frame title="Everything Kap's editor did">
              <Points
                items={[
                  "Drag the two handles to keep only the part that matters. Press I or O to set them at the playhead.",
                  "Resize with real numbers: every scale option shows the size you'll get.",
                  "Set the frame rate up to the recording's own, 30 or 60 fps.",
                  "Mute the audio, then convert with ⌘E.",
                  "Closing an unexported recording asks first, so nothing disappears by accident.",
                ]}
              />
            </Frame>
          </div>
        </Section>

        <Section
          id="export"
          eyebrow="Export"
          title="Four formats, no ffmpeg"
          lede="Conversion runs on frameworks already in macOS: VideoToolbox for video, ImageIO for animated images. Nothing to download, nothing to update."
        >
          <div className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-4">
            {formats.map((format) => (
              <div
                key={format.name}
                className="bg-panel border-line hover:border-violet/40 grid content-start gap-2 rounded-[18px] border p-5.5 transition duration-300 hover:-translate-y-1 hover:shadow-[0_24px_40px_-24px_rgb(100_88_245/0.45)]"
              >
                <span className="text-violet font-mono text-xs">{format.engine}</span>
                <b className="font-display text-2xl tracking-tight">{format.name}</b>
                <p className="text-muted-foreground text-[0.95rem]">{format.summary}</p>
              </div>
            ))}
          </div>
          <div className="mt-5.5 grid gap-5.5 md:grid-cols-2">
            <Frame title="Scale with the result in front of you">
              <div
                aria-label="Scale options for a 1280 × 720 recording"
                className="bg-panel border-line grid gap-0.5 rounded-[14px] border p-1.5 font-mono text-sm tabular-nums shadow-[0_20px_40px_-24px_rgb(20_24_41/0.4)]"
              >
                {scaleOptions.map((option, index) => (
                  <div key={option} className={index === 0 ? "bg-violet relative rounded-lg py-2.5 pr-3 pl-8 text-white" : "py-2.5 pr-3 pl-8"}>
                    {index === 0 && <span className="absolute left-3">✓</span>}
                    {option}
                  </div>
                ))}
              </div>
            </Frame>
            <Frame title="Send it where it's going">
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
          eyebrow="Kap 3.6 and Easy Kap"
          title="What changed under the hood"
          lede="Kap's last release came out in October 2022. Easy Kap keeps its workflow and rebuilds the rest on current macOS frameworks."
        >
          <div className="bg-panel border-line overflow-x-auto rounded-[20px] border">
            <table className="w-full min-w-140 border-collapse text-left">
              <thead>
                <tr className="text-muted-foreground font-mono text-xs tracking-[0.08em] uppercase">
                  <th scope="col" className="px-5.5 py-4">
                    <span className="sr-only">Area</span>
                  </th>
                  <th scope="col" className="px-5.5 py-4 font-medium">
                    Kap 3.6
                  </th>
                  <th scope="col" className="px-5.5 py-4 font-medium">
                    Easy Kap
                  </th>
                </tr>
              </thead>
              <tbody>
                {comparison.map((row) => (
                  <tr key={row.area} className="border-line border-t align-top">
                    <td className="w-[26%] px-5.5 py-4 font-semibold">{row.area}</td>
                    <td className="text-muted-foreground px-5.5 py-4">{row.kap}</td>
                    <td className={row.better ? "px-5.5 py-4 font-semibold text-[#0c8f7e]" : "px-5.5 py-4"}>{row.easyKap}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Section>

        <Section
          id="install"
          eyebrow="Install"
          title="Download, drag, record"
          lede="Easy Kap ships as a disk image. Each release is built from the public source by GitHub Actions."
        >
          <div className="grid items-start gap-5.5 md:grid-cols-2">
            <Frame title="Install from the disk image">
              <ol className="grid gap-3.5">
                {[
                  <>
                    Download <b>EasyKap.dmg</b> from the latest release.
                  </>,
                  "Open it and drag Easy Kap into Applications.",
                  <>
                    Open Easy Kap. It isn't notarized by Apple yet, so macOS blocks the first launch. Go to{" "}
                    <b>System Settings → Privacy &amp; Security</b> and click <b>Open Anyway</b>.
                  </>,
                  "Record once and allow Screen Recording when macOS asks, then reopen Easy Kap.",
                ].map((step, index) => (
                  // Static copy: the order is the identity.
                  <li key={index} className="grid grid-cols-[28px_1fr] gap-3">
                    <span className="bg-ink grid size-7 place-items-center rounded-full font-mono text-xs text-white">{index + 1}</span>
                    <span className="pt-0.5">{step}</span>
                  </li>
                ))}
              </ol>
              <div className="flex flex-wrap gap-3 pt-2">
                <DownloadButton />
                <SecondaryButton href={releasesURL}>All releases</SecondaryButton>
              </div>
            </Frame>
            <div className="grid gap-5.5">
              <Frame title="Good to know">
                <Points
                  items={[
                    "Click the ring in the menu bar to start, or set a shortcut in Settings.",
                    "Exported recordings land in ~/Movies/Kaptures, the same folder Kap used.",
                    "To update, download the new disk image and replace the app in Applications.",
                  ]}
                />
              </Frame>
              <pre className="bg-ink overflow-x-auto rounded-2xl p-5.5 font-mono text-sm leading-[1.8] text-[#e9ecff]">
                <span className="text-[#8e97b8]"># or build it from source</span>
                {"\n"}
                <span className="text-teal select-none">$ </span>git clone {repositoryURL}
                {"\n"}
                <span className="text-teal select-none">$ </span>cd easy-kap && make install
              </pre>
            </div>
          </div>
        </Section>

        <section aria-labelledby="credit-title" className="py-18">
          <div className="bg-panel border-line grid items-center gap-7 rounded-3xl border p-8.5 sm:grid-cols-[auto_1fr]">
            <span
              aria-hidden="true"
              className="ring-spin block size-24 rounded-full"
              style={{
                background: "conic-gradient(from 210deg, var(--violet), var(--teal), var(--violet))",
                mask: "radial-gradient(circle, transparent 36px, #000 37px)",
              }}
            />
            <div>
              <h2 id="credit-title" className="mb-2.5 text-2xl">
                Made because of Kap
              </h2>
              <p className="text-muted-foreground max-w-[68ch]">
                Easy Kap exists because{" "}
                <a className="text-foreground underline underline-offset-3" href={kapURL}>
                  Kap
                </a>{" "}
                by{" "}
                <a className="text-foreground underline underline-offset-3" href="https://wulkano.com">
                  Wulkano
                </a>{" "}
                set the bar for a small, friendly screen recorder. It's an independent project, not affiliated with or endorsed by Wulkano, and it's
                MIT licensed like the original.
              </p>
            </div>
          </div>
        </section>
      </main>

      <footer className="text-muted-foreground flex flex-wrap justify-between gap-x-6 gap-y-3 pt-10 pb-14 text-sm">
        <span>Easy Kap · MIT License</span>
        <a href={repositoryURL}>github.com/chen86860/easy-kap</a>
      </footer>
    </div>
  );
}
