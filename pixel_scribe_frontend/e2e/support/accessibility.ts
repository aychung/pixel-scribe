import AxeBuilder from "@axe-core/playwright";
import type { Page } from "@playwright/test";

export function runAccessibilityScan(page: Page) {
  return new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
}
