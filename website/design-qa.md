# Wikey landing page validation — 2026-09-06

## Direction

Quiet editorial layout, restrained violet accent, concise Korean explanations.
Public examples in `src/examples.js` are fictional. The old product captures and
design reference were removed from current source and public build inputs because
they contained personal workflows. No replacement actual-user captures are used.

## Validation

- Production build and Sites worker contract tests.
- Public-asset allowlist, no private capture filenames or user-directory paths in output.
- Server-rendered content checks for all three example views and privacy labeling.
- Theme storage failures do not prevent rendering.
- Responsive CSS includes narrow-screen layouts, keyboard focus outlines, a skip link,
  and reduced-motion support.
- Local HTTP preview handed off at `http://localhost:4173/`.

These are source/build/render checks, not a claim of browser visual or interaction QA.
The previous screenshot-comparison report does not apply to this redesigned page.
Deleting files from the current tree does not erase historical Git commits or copies.
