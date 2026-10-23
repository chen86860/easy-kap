import { motion } from "motion/react";
import type { ReactNode } from "react";

export function Section({ id, eyebrow, title, children, lede }: { id?: string; eyebrow: string; title: string; lede: string; children: ReactNode }) {
  const headingID = `${id ?? eyebrow.toLowerCase().replace(/\W+/g, "-")}-title`;
  return (
    // Rises a little as it scrolls in. It never starts hidden, so the page reads fine before any animation runs.
    <motion.section
      id={id}
      aria-labelledby={headingID}
      className="scroll-mt-6 py-18"
      initial={{ y: 28 }}
      whileInView={{ y: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
    >
      <div className="mb-10 grid max-w-180 gap-3.5">
        <span className="text-muted-foreground font-mono text-xs tracking-[0.08em] uppercase">{eyebrow}</span>
        <h2 id={headingID} className="text-[clamp(1.6rem,1.2rem+1.6vw,2.3rem)] leading-tight">
          {title}
        </h2>
        <p className="text-muted-foreground text-lg">{lede}</p>
      </div>
      {children}
    </motion.section>
  );
}

export function Frame({ title, children }: { title: string; children: ReactNode }) {
  return (
    <article className="bg-panel border-line grid content-start gap-4 rounded-[20px] border p-7">
      <h3 className="text-lg">{title}</h3>
      {children}
    </article>
  );
}

export function Points({ items }: { items: ReactNode[] }) {
  return (
    <ul className="grid gap-2.5">
      {items.map((item, index) => (
        // Static copy: the order is the identity.
        <li key={index} className="grid grid-cols-[18px_1fr] gap-2.5">
          <span aria-hidden="true" className="border-violet mt-[7px] size-2.5 rounded-full border-2" />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}
