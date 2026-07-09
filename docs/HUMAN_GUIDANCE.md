# Human guidance

Durable human preferences and stable project decisions for SwiftlyCodeEdit. Agents preserve
this guidance across planning and implementation work; see [REPO_STYLE.md](REPO_STYLE.md) for
the general purpose of this file.

## SwiftUI-first architecture principle

Decided 2026-07-09.

Build the editor as a SwiftUI-native Mac app. Default to SwiftUI for everything: app lifecycle,
document scenes, the Commands menu, chrome, settings, and panels. Prefer a Swift-native
implementation over wrapping AppKit.

Use AppKit only when a specific user-facing behavior cannot be achieved reliably in SwiftUI or
pure Swift (IME/text-input edge cases, native undo integration, accessibility gaps,
responder-chain behavior). Isolate every such use behind a replaceable adapter with a documented
swap-out path. "Less AppKit is better" is the north star; zero AppKit is not pretended practical
today.

Once the SwiftUI migration (milestone MS in
[docs/active_plans/active/scope_closure_plan.md](active_plans/active/scope_closure_plan.md))
lands, treat `NSDocument`, hand-built `NSMenu`, `NSWindowController`, and delegate-chain patterns
outside the isolated editor-surface adapter as defects. AppKit must never be the app
architecture.

See [CODE_ARCHITECTURE.md](CODE_ARCHITECTURE.md) for how this principle maps onto the current
component boundaries.

## Working style

- Evidence over rationalization: a claim closes only with a command plus its output artifact
  attached. Do not mark work complete on the strength of reasoning alone.
- Validation and manual testing use sandboxed fixture files, never real source files. Autosave
  writes to disk within about 2 seconds, so exercising the live app against a real file risks
  silent data loss.
