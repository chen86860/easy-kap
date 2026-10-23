import { createRootRoute, Outlet } from "@tanstack/react-router";
import { MotionConfig } from "motion/react";
import { useEffect } from "react";

import { startAnalyticsWhenIdle } from "@/lib/analytics";

export const Route = createRootRoute({ component: Root });

function Root() {
  useEffect(startAnalyticsWhenIdle, []);
  return (
    // Follows the visitor's Reduce Motion setting for every animation on the site.
    <MotionConfig reducedMotion="user">
      <Outlet />
    </MotionConfig>
  );
}
