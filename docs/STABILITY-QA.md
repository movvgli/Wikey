# Wikey stability QA — 2026-09-06

Scope: native macOS workflow execution, app and layout shortcuts, and consistency across the app's tabs. This record does not assert App Store review, notarization, public release, or compatibility with every destination app.

## Confirmed validation

- Final integration run: **67 automated tests in 9 suites passed**, repeated at 22:20 KST before public-release preparation, including the final app-error and monitor-picker corrections.
- Local signed **1.2.6 (1002006)** build and signature verification succeeded. Team: `WQK7GH6P5Y`; installed at `/Applications/Wikey.app`.
- The macOS 14 release candidate compiled successfully as a universal app (`arm64` and `x86_64`). Its minimum-OS metadata was checked for macOS 14.0. This is build and artifact validation, not an execution test on macOS 14 or an Intel Mac.
- Live recorder check captured **⌃⌘9** and persisted it.
- Release-candidate input check passed in a disposable TextEdit document: launch → paste ALPHA → Shift+Enter → wait → nested paste BETA → Enter. The actual document contained `ALPHA\nBETA\n` and Wikey reported completion.
- Existing **Accessibility and Input Monitoring permissions remained granted** after the signed app replacement.
- Live failure-path workflow stopped before paste; the disposable target document remained unchanged and Wikey showed the failure.
- Manual layout apply succeeded in the final build. The actual TextEdit window frame matched the requested right half within the 2-point tolerance (requested `900,39,900,1051`; observed `900,39,900,1050`). Before correction, AX returned success while the old `656 × 422` size remained unchanged.
- App-list direct launch completed. Korean `텍스트` and English `TextEdit` both found the localized TextEdit row after rebuilding.
- A 30-second wait displayed the current action and one queued workflow. Clicking Stop cancelled the wait and removed the queued workflow before it launched.
- Live recorder clear-while-recording ended recording, and recording `⌃⌘9` again persisted the new value. Global delivery after editing still needs a physical-key check.
- Workflow, template, app, layout and settings surfaces were inspected at normal or minimum window sizes. Back navigation, editable disabled workflows, template delete/cancel prompt and visible primary actions were checked.
- `git diff --check`, shell syntax checks, plist lint and final build passed. No new Wikey crash report appeared during these checks.

## Automated coverage in the passing run

| Area | Covered behavior |
| --- | --- |
| Workflow queue | Rapid submissions have one worker; duplicate runs are ignored; queued runs preserve their original input target. |
| Execution target | Opening an app or URL updates the input target; nested workflows retain and update that same target. |
| Failure handling | A failed app launch, missing template, nested failure, empty workflow, or cycle stops subsequent actions and reports the failing action. |
| Clipboard sequencing | Paste completion precedes Enter and the next clipboard write; text, image, and file clipboard representations are covered. |
| Cancellation and waits | Cancel stops the active sequence, clears queued runs, interrupts explicit waits, and prevents later input; invalid wait durations fail. |
| Keyboard input | Modifier key-state release, timeout, permission checks, target focus checks, exact Enter/Shift+Enter modifiers, synthetic event release, target-process routing, and post-paste settling are covered. |
| Shortcut routing | Conflicts across workflows/apps/layouts, shared sequence prefixes, disabled workflows, second-key consumption, wrong-key cancellation, and Escape are covered. |
| Window placement | Focused/main/minimized window choice, external-display coordinates, restore-before-resize, retry and verification, full-screen failure, cancellation, and enhanced UI restoration are covered. |
| Persistence | Existing configurations and legacy layouts load; new layout shortcuts round-trip; template/workflow deletion removes references; corrupt-state backup is covered. |

The automation service tests use controlled substitutes for destination apps, keyboard posting, and window behavior. They establish sequencing and failure semantics, not live behavior in every third-party app.

## Final source-review corrections

- Disabled workflows remain editable in the workflow collection; their global shortcut is disabled while manual test execution remains available.
- Workflow/template/layout delete prompts describe dependent action removal. Layout edits resolve placements by ID, and all editors reset local state when their item ID changes.
- Missing installed apps expose explicit shortcut cleanup. Removing or reassigning an app shortcut clears stale app-launch errors.
- App errors are now restricted to app runs, with bundle-ID lookup for direct app launches even when no shortcut is saved. Workflow/layout failures remain in the execution summary instead of being mislabeled as app errors.
- The Korean-first app now declares Korean as its development/supported localization. App search also accepts the saved shortcut name and underlying application filename. Both Korean and English searches passed live verification.
- Monitor pickers use the stable display UUID, not the localized display name. Existing layouts with an English saved name correctly show the connected Korean-named display without rewriting user configuration.
- Synthetic key pairs go directly to the validated target process instead of re-entering global shortcut dispatch. The transport and exact event order are tested; real Carbon-collision verification remains pending.
- Recorder teardown, Escape, recording completion, mode changes, first-responder loss, and key-window loss all end recording and restore suspended hotkeys. Actual post-cancellation shortcut delivery remains a live acceptance check.

`WikeyRuntimeTests.onlyApplicationRunsPopulateApplicationLaunchErrors` passed: non-app failures do not enter the app error list, and successful app retries clear the prior error.

## Live acceptance status

| Check | Required evidence | Status |
| --- | --- | --- |
| Single app shortcut | Press a saved shortcut from another app; intended app comes forward once; repeat after recording cancellation/tab change. | Physical global Carbon input remains unverified. Recorder persistence and direct app launch passed separately. |
| Two-step shortcut | First chord + second key executes once, without inserting the matched key into the destination app; Escape/wrong key cancels. | Physical global input remains unverified; routing and consumption have automated coverage. |
| Workflow input sequence | In a disposable local document: launch target → paste → Shift+Enter/Enter → next paste; confirm order and exact destination. | Passed in TextEdit with `ALPHA\nBETA\n`; includes nested workflow. |
| Image/file attachment workflow | Use a non-sending test surface; verify attachment completion before subsequent Enter, with configurable wait when needed. | Pending |
| Layout application | From a shortcut and manual apply: verify intended app window, final frame, minimized restore, monitor choice, and visible failure for unsupported/full-screen windows. | Manual apply and final frame passed; physical shortcut and external display hardware pending. Restore/full-screen/failure paths covered by tests. |
| Cross-tab UI | Browse tabs at normal/minimum window size; verify search, disabled workflow recovery, back/delete controls and run status. | Inspected; app/settings at 920-point width, template/workflow at 1120, layout at both. No clipped primary actions in observed states. |
| Korean app search | Find TextEdit by `텍스트` and `TextEdit`. | Passed |
| Final integrated validation | Re-run tests and signed build after final corrections. | 67 tests / 9 suites passed; signed local 1.2.6 verified. |
| macOS 14 build compatibility | Compile both supported architectures and inspect the final minimum-OS metadata. | Universal compilation and macOS 14.0 minimum-OS check passed; live macOS 14 and Intel hardware testing not performed. |

Earlier live keyboard automation encountered a left-Command key state (`keyCode 55`) remaining held. Quartz key-state tables alone cannot distinguish a real hold from a synthetic latch. Input correctly stopped before pasting with a release-the-shortcut warning. Later read-only checks confirmed all modifier keys released, and the complete TextEdit input sequence passed. This does not replace the pending physical global-shortcut acceptance checks. No workaround forcibly releases a user's held key.

## Scope and remaining limits

- Original user configuration was not used for execution or editing. Its checksum was unchanged after QA.
- Test fixtures used a separate store through `--test-store /absolute/test/path`. After QA, the test app was quit and relaunched normally; the original three workflows and shortcuts were visibly restored. The temporary TextEdit document was saved only in the test directory and closed.
- No KakaoTalk messages were sent. Text, image and file data paths have automated coverage, but attachment upload completion is destination-app dependent. Add a **잠시 기다리기** action before Enter for apps that need more preparation time; the app cannot guarantee arbitrary third-party upload readiness.
- Cancelling a Launch Services open waits for its completion callback; later input is still prevented. A supported app window must allow the requested size; full-screen/unsupported windows and disconnected monitors produce actionable errors.
- Existing signing identity and permissions were retained; no privacy permissions were reset. Signing and local execution evidence above does not establish Apple notarization or public publication. Those are verified separately for the exact release artifact.
- Build compatibility with macOS 14 and both architectures does not establish live compatibility on macOS 14 or Intel hardware; those checks remain outstanding.

## Implementation references

- Window resize ordering and temporary enhanced-accessibility handling were checked against [Rectangle's AccessibilityElement implementation](https://github.com/rxhanson/Rectangle/blob/main/Rectangle/AccessibilityElement.swift).
- Direct event routing uses Apple's [CGEvent.postToPid](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)) after foreground validation, avoiding global-HID re-entry by design. Live collision behavior is not asserted above.
