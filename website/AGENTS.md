# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

## Selected visual direction

- Copy update (2026-09-07): keep the privacy section concise and focused on local storage and optional iCloud storage. Do not repeat fictional-demo explanations, two-Mac verification caveats, or Apple-account requirements in this section. Keep detailed limitations in linked privacy documentation and release notes; do not imply that unverified sync is verified. Existing fictional demo content and its caption remain unchanged.

- Hosting update (2026-09-07): the user requested GitHub Pages instead of Sites. The primary URL is https://movvgli.github.io/Wikey/. Publish only `dist/client` through `.github/workflows/pages.yml`; retain existing Sites metadata as a recovery option, not the primary publishing destination. Keep asset paths relative so the `/Wikey/` prefix works. Do not restore personal screenshots.

- The user selected the first generated landing-page direction on 2026-09-04.
- Preserve its quiet editorial layout: generous white space, concise Korean copy, a narrow left-aligned story column, and one blue-violet download action.
- Privacy update (2026-09-06): never publish actual user screenshots, workflows, template content, app lists, names, or local paths. Use clearly labeled fictional examples rendered from static public data. Audit all public assets, not just visible references. Explain workflows and installation in plain Korean; the supported minimum is macOS 14 from version 1.2.6.
- Use Sukurini only as structural inspiration. Do not copy its content or assets.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.
