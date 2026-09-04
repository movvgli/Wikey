# Wikey landing page design QA

- Source visual truth: `/Users/shyoon/Wikey/website/design-reference.png`
- Implementation: `http://localhost:4173/`
- Implementation screenshot: Codex in-app Browser tab 2 capture at `http://localhost:4173/`
- Desktop viewport: 1440 x 1100 CSS px, device pixel ratio 1
- Mobile viewport: 390 x 844 CSS px, device pixel ratio 1
- Source pixels: 1435 x 1096
- Implementation capture pixels: 1440 x 1100
- Density normalization: none; both the source and desktop implementation were compared at 1x density and near-identical viewport dimensions
- State: light appearance, page top; additional checks at the features anchor and dark appearance

## Full-view comparison evidence

The implementation preserves the selected design's core composition: a compact utility header, a left-aligned two-line hero, one blue-violet download action, a large authentic Wikey window, generous white space, numbered editorial sections, and a restrained single-accent palette. The implementation uses the real 1120 x 760 Wikey workflow screenshot and real 1024 x 1024 app icon rather than reconstructed product artwork.

## Focused region comparison evidence

- Hero: heading scale, copy width, CTA hierarchy, metadata, and product-window balance were checked at 1440 x 1100.
- Product imagery: image crop, sharpness, border, radius, and shadow were checked at desktop and 390 px mobile widths.
- Feature narrative: section numbering, text wrapping, action sequence, dividers, and spacing were checked at the `#features` state.
- Navigation: sticky behavior, internal anchors, GitHub target, and download target were checked.
- Appearance control: light-to-dark and dark-to-light states were checked visually and through the active document theme.
- A separate focused crop was not needed because each high-detail region was large and readable in the viewport captures.

## Required fidelity surfaces

- Fonts and typography: system-native Korean font stack, optical weights, wrapping, line height, and hierarchy match the quiet editorial direction. No truncation was observed.
- Spacing and layout rhythm: 1200 px content frame, two-column hero, large section gaps, thin separators, radii, and restrained elevation match the source. Mobile collapses cleanly to one column.
- Colors and visual tokens: off-white background, charcoal text, muted gray copy, and one blue-violet accent remain consistent in light mode; dark mode maintains contrast without changing hierarchy.
- Image quality and asset fidelity: only authentic Wikey icon and product screenshots are used. Both assets load at full natural resolution without stretching or transparency halos.
- Copy and content: all product claims match implemented Wikey features; the primary CTA points to the latest GitHub release.

## Comparison history

### Pass 1

- P2: The product image showed a duplicated macOS traffic-light bar because the real screenshot already included window chrome. Fixed by removing the extra wrapper chrome.
- P2: The sticky header disappeared after internal navigation because the outer shell used clipping that created a scroll container, and the home anchor targeted the main element. Fixed by using horizontal clip behavior and moving the top anchor to the outer shell.
- P2: The first feature heading wrapped into too many short lines at desktop width. Fixed by widening the editorial text column and rebalancing the image column.

### Pass 2

- Re-captured the desktop hero, feature-anchor state, dark appearance, and mobile hero after the fixes.
- No actionable P0, P1, or P2 differences remain.

## Findings

- No blocking or moderate fidelity issues remain.

## Open questions

- None for the local prototype. Publishing destination is intentionally left for the user to choose.

## Implementation checklist

- [x] Authentic Wikey brand and product assets
- [x] Responsive desktop and mobile layout
- [x] Working navigation and internal anchors
- [x] Working latest-release download links
- [x] Working light and dark appearance control
- [x] Browser console free of warnings and errors
- [x] Production build and Sites packaging tests pass

## Follow-up polish

- P3: Add dedicated screenshots for the workflow editor, template editor, and layout editor after final release UI is installed, so later sections can show more product variety without simulated UI.

final result: passed
