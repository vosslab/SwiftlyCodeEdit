//
//  PlainSyntaxHighlighter.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditLanguages
import CodeEditSyntaxDefinitions
import CodeEditTextView

// Entry point and orchestrator for plain-editor syntax coloring. Cold open,
// theme change, and reload take the whole-document `HighlightFullPass`; each
// keystroke takes the bounded `rehighlight` path, which reinterprets only a
// region around the edit. The supporting concerns live in sibling
// types: per-storage state and the DEBUG completion seam in `HighlightStateStore`,
// region math in `HighlightRegionPlanner`, and attribute application in
// `HighlightPainter`.
@MainActor
enum PlainSyntaxHighlighter {
    // MARK: - Full-document highlight (cold open, theme change, reload)

    static func highlight(textView: TextView, language: CodeLanguage) {
        HighlightFullPass.schedule(storage: textView.textStorage, language: language, layoutTarget: textView)
    }

    static func highlight(storage: NSTextStorage, language: CodeLanguage) {
        HighlightFullPass.schedule(storage: storage, language: language, layoutTarget: nil)
    }

    // MARK: - Bounded rehighlight (per keystroke)

    static func rehighlight(
        textView: TextView,
        language: CodeLanguage,
        editedRange: NSRange,
        newLength: Int
    ) {
        scheduleBoundedRehighlight(
            storage: textView.textStorage,
            language: language,
            editedRange: editedRange,
            newLength: newLength,
            layoutTarget: textView
        )
    }

    static func rehighlight(
        storage: NSTextStorage,
        language: CodeLanguage,
        editedRange: NSRange,
        newLength: Int
    ) {
        scheduleBoundedRehighlight(
            storage: storage,
            language: language,
            editedRange: editedRange,
            newLength: newLength,
            layoutTarget: nil
        )
    }

    // Bounds keystroke work to a region instead of reinterpreting and repainting
    // the whole document. The edited-range broadcast is the single
    // highlight driver now, so exactly one pass runs per edit (this also removes
    // the old double-highlight where `onTextChange` scheduled a whole-document
    // pass on top of the edited-range signal).
    private static func scheduleBoundedRehighlight(
        storage: NSTextStorage,
        language: CodeLanguage,
        editedRange: NSRange,
        newLength: Int,
        layoutTarget: TextView?
    ) {
        guard storage.length > 0 else { return }

        #if DEBUG
        // The command self-test drives many edits after the initial highlight has
        // already logged its token summary; suppressing per-edit rehighlights
        // there keeps the smoke log clean, matching the full path's guard.
        if ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1",
           HighlightStateStore.didLogSmokeTokenSummary {
            return
        }
        #endif

        // Small documents interpret in one cheap pass, so the full path (which is
        // the one the highlighter tests exercise) is both simpler and correct.
        guard storage.length >= HighlightRegionPlanner.boundedMinimumDocumentLength else {
            HighlightFullPass.schedule(storage: storage, language: language, layoutTarget: layoutTarget)
            return
        }

        let languageName = language.tsName
        let strategy = HighlightRegionPlanner.activeStrategy
        // The post-edit span of the just-inserted text, in current (post-edit)
        // character coordinates: the replacement starts where the replaced range
        // started and now runs `newLength` characters.
        let editedSpanLocation = editedRange.location

        let state = HighlightStateStore.state(for: storage)
        state.latestGeneration += 1
        let requestGeneration = state.latestGeneration
        state.currentTask?.cancel()

        #if DEBUG
        // Timestamp the main-actor Task enqueue so the bench can attribute the
        // scheduling hop (enqueue to task-body start) apart from real compute and
        // paint. DEBUG-only; read only when the phase markers fire.
        let enqueueUptime = DispatchTime.now().uptimeNanoseconds
        #endif

        // The generation was bumped synchronously above so a bench waiter
        // registered right after this edit observes the in-flight generation; all
        // storage and layout reads happen inside the task, after the enclosing
        // edit batch (beginEditing/endEditing) has completed and layout settled.
        state.currentTask = Task { @MainActor in
            #if DEBUG
            let bodyUptime = DispatchTime.now().uptimeNanoseconds
            #endif
            guard requestGeneration == state.latestGeneration else {
                HighlightStateStore.settle(state: state, generation: requestGeneration)
                return
            }

            let editedSpan = NSRange(
                location: min(editedSpanLocation, storage.length),
                length: min(newLength, max(0, storage.length - editedSpanLocation))
            )
            let region = HighlightRegionPlanner.boundedRegion(
                storage: storage,
                editedSpan: editedSpan,
                layoutTarget: layoutTarget,
                strategy: strategy
            )

            #if DEBUG
            debugRuntimeLog("BOUNDED_REHIGHLIGHT editedSpan=\(editedSpan) region=\(region) storageLength=\(storage.length) strategy=\(strategy)")
            #endif
            // A region covering the whole buffer (Clean Text arrives as a
            // whole-buffer range edit) is just a full highlight; delegate rather
            // than run the bounded machinery over the entire document.
            if region.location == 0, region.length >= storage.length {
                HighlightStateStore.settle(state: state, generation: requestGeneration)
                HighlightFullPass.schedule(storage: storage, language: language, layoutTarget: layoutTarget)
                return
            }

            let regionText = storage.mutableString.substring(with: region)
            #if DEBUG
            let spanStart = DispatchTime.now().uptimeNanoseconds
            #endif
            let spans = await Task.detached(priority: .userInitiated) {
                CodeEditSyntaxDefinitions.highlightSpans(text: regionText, language: languageName)
            }.value
            #if DEBUG
            let spanMs = Double(DispatchTime.now().uptimeNanoseconds - spanStart) / 1_000_000
            #endif

            guard requestGeneration == state.latestGeneration, !Task.isCancelled else {
                HighlightStateStore.settle(state: state, generation: requestGeneration)
                return
            }

            #if DEBUG
            let paintStart = DispatchTime.now().uptimeNanoseconds
            #endif
            HighlightPainter.applyBoundedHighlight(
                spans: spans,
                storage: storage,
                region: region,
                layoutTarget: layoutTarget
            )
            #if DEBUG
            emitKeystrokePhaseMarkers(
                schedMs: Double(bodyUptime - enqueueUptime) / 1_000_000,
                spanMs: spanMs,
                paintMs: Double(DispatchTime.now().uptimeNanoseconds - paintStart) / 1_000_000
            )
            #endif
            HighlightStateStore.settle(state: state, generation: requestGeneration)
        }
    }

    #if DEBUG
    // DEBUG completion seam for the keystroke bench. Forwards to the
    // state store, which owns the per-generation settle bookkeeping; kept on this
    // type so the bench's `PlainSyntaxHighlighter.onHighlightSettled` call site
    // stays stable.
    static func onHighlightSettled(storage: NSTextStorage, perform completion: @escaping () -> Void) {
        HighlightStateStore.onHighlightSettled(storage: storage, perform: completion)
    }

    // Emits the per-edit sub-phase breakdown for the keystroke floor-attribution
    // experiment, one marker set per measured edit. `schedMs` is the
    // main-actor Task enqueue-to-body hop, `spanMs` the off-main span compute plus
    // its detached round trip, and `paintMs` the attribute paint and layout. These
    // plus the bench's KEYSTROKE_MUTATION_MS sum to the KEYSTROKE_MS window, so a
    // reader can see which phase dominates the fixed floor. Gated so the cold-open
    // pass and non-bench runs stay silent.
    static func emitKeystrokePhaseMarkers(schedMs: Double, spanMs: Double, paintMs: Double) {
        guard PlainEditorKeystrokeBench.phaseMarkersEnabled else { return }
        debugRuntimeLog("KEYSTROKE_SCHED_MS=\(schedMs)")
        debugRuntimeLog("KEYSTROKE_SPAN_MS=\(spanMs)")
        debugRuntimeLog("KEYSTROKE_PAINT_MS=\(paintMs)")
    }
    #endif
}
