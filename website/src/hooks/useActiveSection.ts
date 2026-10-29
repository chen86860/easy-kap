import { useEffect, useState } from "react";

/** The id of the section crossing the middle of the viewport, for marking the matching link in the navigation. */
export function useActiveSection(ids: string[]) {
  const [active, setActive] = useState<string | null>(null);
  const key = ids.join(" ");
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const id = entry.target.id;
          setActive((current) => (entry.isIntersecting ? id : current === id ? null : current));
        }
      },
      // A thin band across the middle of the screen: only one section can sit in it at a time.
      { rootMargin: "-50% 0px -50% 0px" },
    );
    for (const id of key.split(" ")) {
      const element = document.getElementById(id);
      if (element) observer.observe(element);
    }
    return () => observer.disconnect();
  }, [key]);
  return active;
}
