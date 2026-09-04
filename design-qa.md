# Wikey 1.2.0 Design QA

## Comparison target

- Source visual truth: selected Flow Canvas concept image
- Final installed-app screenshot: local QA capture
- Combined comparison: local side-by-side QA capture
- Viewport: native macOS window at 1120 x 760 points in light appearance
- Source dimensions: 1488 x 1058 px, aspect-fitted without cropping into the comparison panel
- Implementation dimensions: Retina capture normalized from 2240 x 1520 px to 1120 x 760 px for the 1120 x 760-point window
- Tested state: first real workflow selected, shortcut `⌥2`, one template-copy action, idle

## Required fidelity surfaces

- Native macOS traffic-light controls with content extending into the title-bar area
- Custom left sidebar with brand, primary navigation, workflow collection, shortcut badges, and trash action
- Back control, editable title, autosave state, time, and workflow overflow menu
- Separate shortcut card and shortcut editor
- Purple trigger, vertical connector, numbered action cards, and compact action menus
- Full-width dashed add-action control and persistent bottom test-run bar

## Findings

- No actionable P0, P1, or P2 visual or interaction findings remain.
- The final implementation follows the selected Flow Canvas hierarchy rather than the previous form-style editor.
- Sidebar selection, workflow selection, trigger marker, connector, action marker, and primary action share the selected indigo treatment.
- Card radius, border weight, shadow softness, spacing rhythm, typography hierarchy, and persistent bottom bar match the visual source at the tested window size.
- The final installed app preserves real user content. The source contains five example workflows and four example actions; the implementation shows the user's two workflows and the selected workflow's one real action. This is an intentional data difference, not a layout mismatch.
- The source's small pencil glyph beside the workflow title is intentionally omitted by the user's explicit follow-up request. The title remains directly editable.
- All visible primary controls remain functional: navigation, workflow selection, shortcut editing, workflow menu, action menu, add-action menu, and test run.
- Every primary sidebar row and saved-workflow row now exposes its full 232-point width as the pointer target instead of limiting interaction to rendered text and icons.
- The trash action was reduced from a 64-point card treatment to a compact 42-point footer control, preserving a comfortable hit target while matching the source's lighter visual weight.
- The updater is not started in an unconfigured development build, preventing the recurring `Unable to Check For Updates` alert. The signed installed build retains its configured update feed.

## Visual evidence

- Full view: the combined comparison places the selected source and final installed Wikey capture in one image. Sidebar density, footer scale, title hierarchy, shortcut card, flow rail, action card, add control, and bottom run bar were judged together.
- Focused regions: no extra crop was needed because the complete sidebar and its 42-point trash footer remain legible at the normalized 760-pixel height. Accessibility bounds supplied the exact hit-region measurements that a screenshot cannot show.

## Comparison history

1. Initial implementation reused the existing editor structure and only borrowed the concept's color and card styling. This was a P1 fidelity failure.
2. Rebuilt the editor around the selected visual: exact custom sidebar, separate shortcut card, flow trigger, numbered connector, compact action cards, dashed add control, and bottom run bar.
3. The next comparison found P2 issues in the title-bar gap, menu placement, sidebar toggle, flow spacing, and short add-action region.
4. Removed the title text and unused sidebar toolbar control while preserving native traffic lights; moved the workflow menu beside autosave; aligned vertical spacing; extended the add-action card and connector endpoint.
5. The final installed-app comparison shows no remaining P0, P1, or P2 issue. Only user-data count, workflow name, and current time differ from the illustrative source.
6. Follow-up usability pass found P1 interaction friction because sidebar hit testing followed only rendered label content, plus a P2 oversized trash footer. Added rectangular content shapes and full-width button frames to both sidebar row types, then reduced the trash container to 42 points.
7. Post-fix interaction evidence: clicking the far-right empty area of the layout row opened the layout collection, and clicking the far-right empty area of the first workflow row opened `신규 카톡방 개설`. The final installed-app comparison confirms the smaller trash control remains aligned with the source.
8. User-requested follow-up removed the pencil glyph beside the workflow title without changing title editing. The final installed-app capture confirms the title alignment closes cleanly with no gap or wrapping regression.

## Verification

- [x] Source and implementation reviewed in one side-by-side comparison image
- [x] Native 1120 x 760 window checked in the same selected workflow state
- [x] Real workflow data preserved
- [x] Navigation and workflow rows verified using clicks in empty space away from their labels
- [x] Sidebar accessibility bounds verified at 232 x 36 points for navigation and 232 x 38 points for workflows
- [x] Trash footer reduced and visually rechecked at 42 points tall
- [x] Workflow-title pencil glyph removed while direct title editing remains available
- [x] Recurring development updater alert removed and manually rechecked
- [x] Full automated suite passed: 9 tests in 3 suites
- [x] Installed version verified: 1.2.0 (1002000)
- [x] Installed bundle passed strict deep code-signature verification

## Distribution verification

- Apple notarization completed successfully for the signed Wikey 1.2.0 DMG.
- The notarization ticket is stapled to the DMG and passes Gatekeeper assessment as a Notarized Developer ID build.

final result: passed
