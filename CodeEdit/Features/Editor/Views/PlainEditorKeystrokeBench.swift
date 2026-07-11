//
//  PlainEditorKeystrokeBench.swift
//  CodeEdit
//
//  Created for the keystroke latency harness.
//

import Foundation
import CodeEditTextView

#if DEBUG
/// Debug-only keystroke latency benchmark, active only when
/// CODEEDIT_KEYSTROKE_BENCH is set to a positive edit count.
///
/// Drives single-character insertions through the same `TextView.replaceCharacters`
/// path a real keystroke takes, then waits for the highlight pass that edit
/// triggered to fully complete -- span compute AND applyHighlight's attribute
/// painting and layoutLines, both of which land on later main-actor turns
/// outside the synchronous mutation. Each `KEYSTROKE_MS=<float>` line therefore
/// times the whole end-to-end window (mutation + status refresh + span compute
/// + paint), not just the synchronous slice, so a future bounded-rehighlight
/// improvement becomes visible in this baseline.
@MainActor
enum PlainEditorKeystrokeBench {
    private static var didSchedule = false

    // Flipped true the moment the first real bench edit begins. The one cold-open
    // full pass that runs before any edit stays unmarked, so the highlighter's
    // per-edit sub-phase markers (KEYSTROKE_SCHED_MS / KEYSTROKE_SPAN_MS /
    // KEYSTROKE_PAINT_MS) are exactly one set per measured edit, not one extra for
    // the cold pass (floor attribution).
    static var editsStarted = false

    // Whether the highlighter should emit its per-edit sub-phase markers. Gated on
    // both the bench being requested and the first edit having started, so the
    // markers never fire in a normal DEBUG run, the command self-test, or the cold
    // open pass. DEBUG-only measurement seam.
    static var phaseMarkersEnabled: Bool {
        editsStarted && requestedEditCount() != nil
    }

    static func scheduleIfRequested(textView: TextView) {
        guard let editCount = requestedEditCount(), !didSchedule else {
            return
        }
        didSchedule = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            run(textView: textView, editCount: editCount)
        }
    }

    private static func requestedEditCount() -> Int? {
        guard let rawValue = ProcessInfo.processInfo.environment["CODEEDIT_KEYSTROKE_BENCH"],
              let editCount = Int(rawValue), editCount > 0 else {
            return nil
        }
        return editCount
    }

    private static func run(textView: TextView, editCount: Int) {
        textView.window?.makeFirstResponder(textView)
        // Drain the initial whole-document cold highlight (kicked off at
        // onTextViewReady) before timing any edit, so the first measured edit
        // is not inflated by that one-time startup pass still running.
        PlainSyntaxHighlighter.onHighlightSettled(storage: textView.textStorage) {
            performEdit(textView: textView, editIndex: 0, editCount: editCount)
        }
    }

    // Each edit mutates the document, then waits for the highlight pass that
    // mutation triggered to settle (paint + layout complete) before recording
    // its time and scheduling the next edit. The completion callback runs on a
    // later main-actor turn, so the run loop keeps pumping between edits (a
    // tight synchronous for-loop would starve both the run loop and the app's
    // --kill-after backstop timer across hundreds of multi-second edits); the
    // next edit is still scheduled one-per-turn via DispatchQueue.main.async.
    private static func performEdit(textView: TextView, editIndex: Int, editCount: Int) {
        guard editIndex < editCount else {
            debugRuntimeLog("KEYSTROKE_BENCH_DONE=\(editCount)")
            return
        }

        // From the first real edit on, the highlighter emits per-edit sub-phase
        // markers; the cold-open pass that already ran stays unmarked so the
        // phase-marker stream is exactly one set per measured edit.
        editsStarted = true

        let documentLength = (textView.string as NSString).length
        // Spread insertion offsets across the whole document. Advancing by a
        // full stride (documentLength / editCount) per edit means editCount
        // edits touch the entire fixture, not just the first couple percent
        // an editIndex-scaled small step would reach. A small prime offset
        // keeps edits off exact line boundaries. The document grows by one
        // character per edit, so the stride is recomputed from the current
        // length each time.
        let stride = max(1, documentLength / editCount)
        let insertionOffset = documentLength == 0 ? 0 : min(documentLength, editIndex * stride + 13)
        let insertedCharacter = String(UnicodeScalar(UInt8(97 + editIndex % 26)))

        let startTime = DispatchTime.now()
        textView.replaceCharacters(
            in: NSRange(location: insertionOffset, length: 0),
            with: insertedCharacter
        )
        // The synchronous mutation slice ends here, before any async highlight hop
        // runs: it covers the edit apply, the status refresh (STATUS_REFRESH_MS),
        // and the synchronous highlight scheduling up to Task creation. This is the
        // work a real keystroke blocks on to show the typed character; timing it on
        // its own lets the async highlight floor be attributed apart from the real
        // synchronous keystroke cost.
        let mutationMs = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
        debugRuntimeLog("KEYSTROKE_MUTATION_MS=\(mutationMs)")
        // Waiting captures the generation this edit just bumped, so the timer
        // stops only after that generation's span compute and paint finish.
        PlainSyntaxHighlighter.onHighlightSettled(storage: textView.textStorage) {
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
            debugRuntimeLog("KEYSTROKE_MS=\(elapsedMs)")

            DispatchQueue.main.async {
                performEdit(textView: textView, editIndex: editIndex + 1, editCount: editCount)
            }
        }
    }
}
#endif
