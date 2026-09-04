# Wikey Workflow Card Design QA

## Comparison target

- Baseline workflow list: `$HOME/Pictures/Screenshots/스크린샷 2026-09-04 오후 1.48.32.webp`
- Source visual truth: `$HOME/Pictures/Screenshots/스크린샷 2026-09-04 오후 1.48.28.webp`
- Rendered implementation: `/private/tmp/wikey-workflow-card-installed.png`
- Normalized workflow-card crop: `/private/tmp/wikey-workflow-card-installed-detail.png`
- Combined comparison: `/private/tmp/wikey-workflow-card-installed-comparison.png`
- Window viewport: 1120 x 760 points in macOS light appearance
- Full implementation capture: 2240 x 1520 pixels at 2x density
- Source and normalized comparison regions: 1622 x 374 pixels at matching density
- State: installed app Home, two enabled workflows, one action each, normal enabled shortcut state

## Findings

- No actionable P0, P1, or P2 visual or interaction findings remain.
- Each workflow is now presented as its own rounded card rather than as a row inside one shared panel.
- Card width, radius, border, padding, icon tile, two-line text hierarchy, and 12-point vertical gap match the template cards.
- Workflow-specific controls intentionally replace template-specific content: the workflow card keeps its shortcut badge and independent run button instead of the template chevron.
- The installed-app comparison shows the normal Wikey accent bolt and enabled play controls. A separate development-build pass also confirmed the warning icon and disabled control appear for a real shortcut conflict.

## Required fidelity surfaces

- Fonts and typography: both surfaces use the same system headline and subheadline hierarchy, optical weight, line spacing, and single-line truncation.
- Spacing and layout rhythm: both use 18-point card padding, a 44-point icon tile, a 14-point continuous corner radius, and a 12-point gap between cards.
- Colors and visual tokens: both use the adaptive control background, separator border, subtle shadow, and Wikey accent treatment; warning orange appears only for a real conflict.
- Image and icon quality: no raster artwork is required. Standard SF Symbols remain sharp at native density and match the existing macOS interface.
- Copy and content: workflow names and action counts are preserved. Shortcut badges and run controls remain visible and functional according to workflow state.

## Interaction verification

- Clicking the first workflow card opened `신규 카톡방 개설` in the workflow editor.
- The card's full primary region, including the shortcut badge, is exposed as one edit button.
- The run button remains a separate control and does not trigger editor navigation.
- Back navigation returned to the same card list, and template navigation confirmed the shared visual dimensions.
- The installed app exposed both run buttons as enabled independent controls. The buttons were not activated during visual QA because doing so would execute the user's live KakaoTalk workflows.
- A separate development-state check confirmed that the disabled run state exposes the shortcut-conflict explanation instead of silently failing.
- Automated verification passed: 9 tests in 3 suites.

## Full-view and focused comparison evidence

- Full view: the 1120 x 760 implementation capture confirms the cards sit correctly beneath the existing header and permission notice without changing the surrounding page hierarchy.
- Focused region: the source template cards and implementation workflow cards were cropped to the same 1622 x 374 pixel region and stacked in one comparison image. Card geometry, spacing, text baseline, icon alignment, and trailing-control alignment match.
- No additional crop was required because the focused comparison keeps both complete cards and all important details legible.

## Comparison history

1. The baseline workflow design grouped both workflows inside one large shared panel with a divider.
2. The first implementation pass replaced the shared panel with separate cards and reused the template card measurements and visual tokens.
3. The same-size focused comparison found no actionable P0, P1, or P2 mismatch, so no corrective visual iteration was required.

## Implementation checklist

- [x] Separate card per workflow
- [x] Template-matched card geometry and spacing
- [x] Full primary card region opens the editor
- [x] Independent shortcut and run controls preserved
- [x] Hover, disabled, running, and conflict states preserved
- [x] Build and automated tests pass
- [x] Live macOS interaction checked

final result: passed
