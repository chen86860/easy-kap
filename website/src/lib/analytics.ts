const posthogProjectToken = "phc_9biiBNdgbqZlxcJdISohgz7VWJnC83jCexzXhrMKnd";
const idleDelay = 2_000;

type PostHogClient = (typeof import("posthog-js"))["default"];

let clientPromise: Promise<PostHogClient> | undefined;

/** Loads the SDK on first use, so it never sits on the critical rendering path. Shared with easy-complete.emmmm.dev. */
function loadPostHog() {
  if (typeof window === "undefined") return;
  clientPromise ??= import("posthog-js").then(({ default: posthog }) => {
    posthog.init(posthogProjectToken, {
      api_host: "https://a.emmmm.dev",
      defaults: "2026-05-30",
      loaded: (client) => client.register({ product: "easy-kap-website", environment: import.meta.env.MODE }),
    });
    return posthog;
  });
  return clientPromise;
}

export function captureEvent(event: string, properties?: Record<string, unknown>) {
  void loadPostHog()?.then((posthog) => posthog.capture(event, properties));
}

/**
 * Starts analytics once the page is idle, or right away on the first interaction, so a deliberate visit is
 * still recorded. Returns the cleanup for an effect.
 */
export function startAnalyticsWhenIdle() {
  let delayID: number | undefined;
  let idleID: number | undefined;

  const cancel = () => {
    if (delayID !== undefined) window.clearTimeout(delayID);
    if (idleID !== undefined) window.cancelIdleCallback?.(idleID);
    window.removeEventListener("load", schedule);
    for (const type of ["pointerdown", "keydown", "touchstart"]) window.removeEventListener(type, start);
  };

  function start() {
    cancel();
    void loadPostHog();
  }

  function schedule() {
    delayID = window.setTimeout(() => {
      if ("requestIdleCallback" in window) idleID = window.requestIdleCallback(start, { timeout: 2_000 });
      else start();
    }, idleDelay);
  }

  for (const type of ["pointerdown", "keydown", "touchstart"]) window.addEventListener(type, start, { once: true, passive: true });
  if (document.readyState === "complete") schedule();
  else window.addEventListener("load", schedule, { once: true });

  return cancel;
}
