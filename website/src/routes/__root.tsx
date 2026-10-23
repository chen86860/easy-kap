import { createRootRoute, Outlet } from "@tanstack/react-router";
import { MotionConfig } from "motion/react";

export const Route = createRootRoute({
  component: () => (
    // Follows the visitor's Reduce Motion setting for every animation on the site.
    <MotionConfig reducedMotion="user">
      <Outlet />
    </MotionConfig>
  ),
});
