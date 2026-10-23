import { expect, it } from "vitest";
import { timecode } from "./timecode";

it("formats seconds as m:ss", () => {
  expect(timecode(0)).toBe("0:00");
  expect(timecode(2.9)).toBe("0:02");
  expect(timecode(125)).toBe("2:05");
  expect(timecode(-3)).toBe("0:00");
});
