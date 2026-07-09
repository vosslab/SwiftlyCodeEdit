# Document lifecycle audit

Date: 2026-07-09

Read-only pre-migration audit of the live document lifecycle paths ahead of milestone MS
(SwiftUI migration). Scope: autosave semantics, external-change reload, save-path encoding
round trip, undo integration, window/document teardown, and error surfacing. All citations
are to compiled, live code. `Features/Documents/WorkspaceDocument/` and
`Features/Editor/Models/` (including `UndoManagerRegistration.swift`) are excluded from the
SwiftPM target build (`Package.swift:44,50,56`) and are not part of the live lifecycle, so
findings below cite the code that actually runs: `CodeFileDocument.swift`, `CodeEditApp.swift`
(`PlainEditorActionRouter`, wired through `TextView.undoManager`), and
`Features/Editor/Views/CodeFileView.swift` / `PlainTextEditorView.swift`.

## Finding count by severity

- HIGH: 4
- MEDIUM: 2
- LOW: 2

## Findings

### Finding 1 (HIGH) -- undo/redo never clears the document's dirty flag

`CodeFileView.swift:61-69` calls `codeFile.updateChangeCount(.changeDone)` on every
`onTextChange` callback, with no distinction between a forward edit and an undo/redo replaying
through the same `TextView.textDidChangeNotification` path (`PlainTextEditorView.swift:57-61`).
`NSDocument.updateChangeCount(.changeDone)` is called unconditionally, never `.changeUndone` or
`.changeCleared`. Undo/redo is driven entirely by `TextView.undoManager`
(`CodeEditApp.swift:294-303`), a manager NSDocument never observes.

Failure scenario: a user types, then presses Undo until the buffer is byte-identical to the
saved file. The document is still `isDocumentEdited == true`, the 2-second autosave timer
(`CodeFileDocument.swift:216-236`) still fires, and the file's mtime is rewritten with no
content change -- an unnecessary disk write with no way to reach a "clean" state short of an
explicit Save.

Owning package: new WP candidate -- undo/dirty-flag integration correctness.

### Finding 2 (HIGH) -- external-change conflict is silently dropped when the document has unsaved edits

`CodeFileDocument.swift:247-263`:

```swift
override func presentedItemDidChange() {
    let currentModificationDate = getModificationDate()
    Task { @MainActor [weak self] in
        guard let self else { return }
        if fileModificationDate != currentModificationDate {
            guard isDocumentEdited else {
                fileModificationDate = currentModificationDate
                if let fileURL, let fileType {
                    try? self.read(from: fileURL, ofType: fileType)
                }
                return
            }
        }
    }
}
```

If `isDocumentEdited == true` when an external change is detected, the `guard` succeeds and the
method falls straight through: `fileModificationDate` is left stale, no reload happens, and no
alert or banner tells the user their in-memory edits now conflict with a newer file on disk.

Failure scenario: the next autosave (2 seconds after any further keystroke) or a manual Save
silently overwrites the external change with no version awareness -- a classic lost-update, and
the exact shape of today's incident (`docs/CHANGELOG.md:40`) generalizes to any external writer,
not just careless paste testing.

Owning package: new WP candidate -- external-change conflict handling and reload error
surfacing.

### Finding 3 (HIGH) -- reload silently swallows decode failures via `try?`

Same method, clean-document branch: `CodeFileDocument.swift:257` calls
`try? self.read(from: fileURL, ofType: fileType)`. `read(from:ofType:)` throws
`CodeFileError.failedToDecode` when the new bytes match no supported encoding
(`CodeFileDocument.swift:150-158`); `try?` swallows that error entirely.

Failure scenario: an external tool rewrites the file in an unsupported encoding while the
document is clean. `fileModificationDate` has already been advanced to the new mtime, the
window keeps showing the old in-memory text, and no alert appears -- silently violating the
"always real text or an explicit error alert, never a silent blank" contract documented at
`CodeFileDocument.swift:143-149`, which as written only actually covers the initial `open`
path, not reload.

Owning package: new WP candidate -- external-change conflict handling and reload error
surfacing (same WP as Finding 2).

### Finding 4 (HIGH) -- reload does not reset the `TextView`'s undo stack

`CodeFileDocument.swift:159-168` reloads by mutating the shared `NSTextStorage` directly
(`content.mutableString.setString(decoded.text)`), deliberately chosen to keep the same storage
object alive across a reload (comment at `CodeFileDocument.swift:162-166` explains this is
needed so highlighting fires). But `TextView.undoManager` (`CodeEditApp.swift:294-298`) is a
separate object that is never told about the reload; its previously recorded undo operations
reference offsets/substrings of the pre-reload text.

Failure scenario: a user edits the document, an external tool changes the file on disk while
the document is clean, `presentedItemDidChange` reloads new content into the same storage, and
the user then presses Undo -- `CEUndoManager` applies a stale operation against content it does
not match, which can silently produce corrupted text at the wrong offset or crash on an
out-of-range replace. No test exercises this path (see
`CodeEditTests/PackageSmoke/CodeFileDocumentLifecycleTests.swift`, which covers only the
encoding matrix, never `presentedItemDidChange` or undo).

Owning package: new WP candidate -- reload-vs-undo-stack correctness (same owning group as
Findings 2/3 since all three stem from the reload path).

### Finding 5 (MEDIUM) -- no dirty-state indicator in the app's own UI

The status bar (`PlainEditorChromeModel`, `CodeFileView.swift:242-273`) exposes cursor,
line/word/character counts, indentation, encoding, and line-ending labels, but has no
dirty/modified field at all. The only dirty-state surface visible to the user before a write
happens is the system window-close-button "modified" dot that AppKit derives automatically from
`isDocumentEdited`. Combined with Finding 1, that one system-provided dot is also unreliable as
a "will this get written" signal, since undo never clears the dirty flag it is driven from.

Owning package: new WP candidate -- autosave dirty-state UI.

### Finding 6 (MEDIUM) -- no round-trip test for the legacy-encoding save direction

`data(ofType:)` re-encodes `content.string` using `sourceEncoding.nsValue`
(`CodeFileDocument.swift:130-137`), so a file opened as Windows-1252 or Latin-1 saves back using
that same `NSStringEncoding`, which should be a correct byte-for-byte round trip for the
encoding family. The existing `lifecyclePersistsSyntheticEdit` test
(`CodeFileDocumentLifecycleTests.swift:15-48`) only exercises the UTF-8 save direction; every
other test in the suite (`latin1FileDecodesToRealText`, `windows1252FileDecodesToRealText`,
`bomlessUTF16*`, `utf8WithBOMDecodesWithBOMStripped`, `undecodableFileThrowsInsteadOfBlankWindow`,
`singleRejectedWindows1252ByteThrows`, `windows1252SmartQuotesReportWindows1252Encoding`)
exercises only the decode direction. A save-path regression in the legacy encodings (Windows-1252,
Latin-1) would go undetected by the current suite.

Owning package: new WP candidate -- test coverage backfill (legacy-encoding save round trip).

### Finding 7 (LOW) -- encoding re-detection on reload is not surfaced to the user

`read(from:ofType:)` reruns `Self.decode(data:)` on every reload rather than reusing the
previously stored `sourceEncoding` (`CodeFileDocument.swift:150-168, 189-209`), which is correct
behavior in isolation, but the status bar's encoding label (`PlainEditorChromeModel.refresh`,
`CodeFileView.swift:253-271`) is only invoked from SwiftUI callbacks in `CodeFileView`, not from
the reload path itself. `presentedItemDidChange` never triggers a chrome refresh directly; it
relies on the `@Published`/`@ObservedObject` update cycle picking up the change indirectly. Not
confirmed as broken, but not proven correct either -- the encoding label can change out from
under the user on an external reload with no explicit notice that the encoding changed.

Owning package: new WP candidate -- reload-triggered status refresh verification (folds into the
external-change WP above as a lower-priority item).

### Finding 8 (LOW) -- no explicit observer teardown in `PlainTextEditorView.Coordinator`

`PlainTextEditorView.Coordinator` (`PlainTextEditorView.swift:27-62`) registers two
`NotificationCenter` observers via `attachNotifications(to:)`, calling
`NotificationCenter.default.removeObserver(self)` at the top of that method before re-adding
(`PlainTextEditorView.swift:37-49`), which correctly prevents duplicate registrations across
`makeNSViewController`/`updateNSViewController` calls. There is no explicit `deinit` removing
observers when the `Coordinator` itself is deallocated. Modern `NotificationCenter` does not
require this for crash-safety, and the `Coordinator` is scoped to the
`NSViewControllerRepresentable` context lifetime, so no evidence of an actual leak or
callback-after-free was found; flagged only for completeness since window/document teardown was
an explicit audit axis. Likely a non-issue, not a bug.

Owning package: none proposed -- documented for completeness, no action recommended.

## UndoManagerRegistration dead-code note

`UndoManagerRegistration.swift` is **not part of the live undo path**. It lives under the
excluded `Features/Editor/Models/` tree (`Package.swift:56`) and is only referenced from
`WorkspaceDocument.swift` and `OpenQuicklyPreviewView.swift`, both also excluded
(`Package.swift:50, 64`). Its own test file (`UndoManagerRegistrationTests.swift`) is exercising
dead-relative-to-the-live-app code. This is worth noting so the MS migration does not assume
`UndoManagerRegistration` is the real undo persistence mechanism it will be building on -- the
real mechanism is the ad hoc `TextView.undoManager` wiring described in Findings 1 and 4, wired
only through `PlainEditorActionRouter` in `CodeEditApp.swift:294-303`.

## Recommended follow-up test

Recommend a dedicated E2E test (per `docs/E2E_TESTS.md`, since this requires real file I/O and
is not a good pytest/XCTest candidate as a fast unit test) that: opens a document, edits it,
externally modifies the file, and asserts the document is not silently overwritten and the user
is notified. There is currently no coverage of this scenario at any test tier.
