import { cn } from "cn";
import { motion } from "motion/react";
import type { ReactNode } from "react";

/** Rises a little as it scrolls in. It never starts hidden, so the page reads fine before any animation runs. */
function Reveal({ id, labelledBy, className, children }: { id: string; labelledBy: string; className?: string; children: ReactNode }) {
  return (
    <motion.section
      id={id}
      aria-labelledby={labelledBy}
      className={cn("scroll-mt-24 pt-24 pb-24", className)}
      initial={{ y: 32 }}
      whileInView={{ y: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
    >
      {children}
    </motion.section>
  );
}

/** A section under a two tone heading: the claim in ink, the reason in gray, read as one sentence pair. */
export function Section({ id, title, lede, children }: { id: string; title: string; lede: string; children: ReactNode }) {
  const headingID = `${id}-title`;
  return (
    <Reveal id={id} labelledBy={headingID}>
      <SectionHeading id={headingID} title={title} lede={lede} className="mx-auto mb-16 text-center" />
      {children}
    </Reveal>
  );
}

export function SectionHeading({ id, title, lede, className }: { id?: string; title: string; lede: string; className?: string }) {
  return (
    <div className={cn("grid max-w-170 gap-1 text-xl font-medium tracking-tight text-balance sm:text-2xl", className)}>
      <h2 id={id} className="font-medium">
        {title}
      </h2>
      <p className="text-muted-foreground text-balance">{lede}</p>
    </div>
  );
}

/** A raised white panel with an optional picture on top, in the manner of a feature card. */
export function Frame({
  title,
  icon,
  visual,
  children,
  className,
}: {
  title: string;
  icon?: ReactNode;
  visual?: ReactNode;
  children?: ReactNode;
  className?: string;
}) {
  return (
    <article className={cn("keycap grid content-start overflow-hidden rounded-2xl", className)}>
      {visual && <div className="bg-dots border-line grid min-h-56 place-items-center border-b p-10">{visual}</div>}
      <div className="grid content-start gap-6 p-8 sm:p-10">
        <h3 className="flex items-center gap-3 text-xl font-medium">
          {icon}
          {title}
        </h3>
        {children}
      </div>
    </article>
  );
}

export function Points({ items }: { items: ReactNode[] }) {
  return (
    <ul className="text-muted-foreground [&_b]:text-foreground grid gap-4 [&_b]:font-medium">
      {items.map((item, index) => (
        // Static copy: the order is the identity.
        <li key={index} className="grid grid-cols-[16px_1fr] gap-3">
          <span aria-hidden="true" className="bg-accent mt-2 size-1.5 rounded-xs" />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}
