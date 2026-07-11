//
//  PlainSyntaxHighlightFullPass.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditLanguages
import CodeEditSyntaxDefinitions
import CodeEditTextView

// Whole-document highlight scheduling: cold open, theme change, and reload. On
// a large document with a layout target this paints the viewport region first
// so the user sees colored text before the whole-document pass finishes;
// both the viewport paint and the full pass run under one generation so a newer
// edit supersedes the pair as a unit.
@MainActor
enum HighlightFullPass {
    // The request-scoped context shared by one full pass's viewport paint and its
    // whole-document loop, so both run under the same storage, generation, and
    // start time without threading a long parameter list.
    private struct Request {
        let storage: NSTextStorage
        let languageName: String
        let layoutTarget: TextView?
        let state: HighlightState
        let generation: Int
        let startTime: CFAbsoluteTime
    }

    // Span computation runs off the main thread; attribute application hops
    // back to @MainActor so the first window paints plain text immediately
    // instead of blocking window construction on the cold interpreter cost.
    static func schedule(
        storage: NSTextStorage,
        language: CodeLanguage,
        layoutTarget: TextView?
    ) {
        guard storage.length > 0 else { return }

        let text = storage.string
        let languageName = language.tsName
        let state = HighlightStateStore.state(for: storage)
        #if DEBUG
        if ProcessInfo.processInfo.environment["CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST"] == "1",
           HighlightStateStore.didLogSmokeTokenSummary,
           text != state.cachedText {
            return
        }
        #endif

        if applyCacheHitIfPossible(
            storage: storage,
            text: text,
            languageName: languageName,
            layoutTarget: layoutTarget,
            state: state
        ) {
            return
        }

        state.latestGeneration += 1
        // One timestamp read per whole-document pass (not per keystroke); the
        // elapsed time it feeds is only logged in DEBUG.
        let start = CFAbsoluteTimeGetCurrent()
        let request = Request(
            storage: storage,
            languageName: languageName,
            layoutTarget: layoutTarget,
            state: state,
            generation: state.latestGeneration,
            startTime: start
        )
        state.currentTask?.cancel()
        #if DEBUG
        let definitionSummary = CodeEditSyntaxDefinitions.debugSummary(language: languageName)
        debugRuntimeLog("PlainSyntaxHighlighter start language=\(languageName) length=\(storage.length) \(definitionSummary)")
        // Timestamp the main-actor Task enqueue so the bench can attribute the
        // scheduling hop (enqueue to task-body start) apart from real compute and
        // paint on the full-document path a small (< bounded threshold) document
        // takes per edit. DEBUG-only; read only when the phase markers fire.
        let enqueueUptime = DispatchTime.now().uptimeNanoseconds
        #endif

        // The enclosing type is @MainActor, so this Task resumes on the main
        // actor; only the detached child runs the interpreter off-main. The task
        // captures `storage` strongly on purpose: the capture is bounded (the
        // task always returns once its generation is superseded or its result is
        // applied), so it keeps the storage alive only for the duration of one
        // pass rather than leaking it.
        state.currentTask = Task { @MainActor in
            #if DEBUG
            let schedMs = Double(DispatchTime.now().uptimeNanoseconds - enqueueUptime) / 1_000_000
            #else
            let schedMs = 0.0
            #endif
            // Coalesce: a burst of edits enqueues many requests on the main
            // actor before any runs. Skip the expensive pass for every request
            // a newer one for this storage has already superseded.
            guard request.generation == state.latestGeneration else {
                HighlightStateStore.settle(state: state, generation: request.generation)
                return
            }

            // Viewport-first: paint what the user sees before interpreting the
            // whole document, so a 1 MB file shows colored text immediately.
            await paintViewportFirst(request)

            guard request.generation == state.latestGeneration, !Task.isCancelled else {
                HighlightStateStore.settle(state: state, generation: request.generation)
                return
            }

            await runFullPass(request, initialText: text, schedMs: schedMs)
        }
    }

    // Applies the cached spans synchronously when an identical text+language was
    // already computed for this storage, returning true when it handled the
    // request. Keeps a theme switch instant (no fresh span computation).
    private static func applyCacheHitIfPossible(
        storage: NSTextStorage,
        text: String,
        languageName: String,
        layoutTarget: TextView?,
        state: HighlightState
    ) -> Bool {
        guard state.cachedLanguage == languageName, state.cachedText == text else {
            return false
        }
        HighlightPainter.applyHighlight(
            spans: state.cachedSpans,
            storage: storage,
            text: text,
            languageName: languageName,
            layoutTarget: layoutTarget,
            elapsedMilliseconds: 0,
            state: state
        )
        // Synchronous cache hit applied a full paint; settle the current
        // generation so a bench waiter registered right after this edit is released.
        HighlightStateStore.settle(state: state, generation: state.latestGeneration)
        return true
    }

    // The whole-document interpret-and-apply loop, with drift recompute. Split
    // out of `schedule`'s task so the scheduling function stays small; behavior
    // is unchanged.
    private static func runFullPass(_ request: Request, initialText: String, schedMs: Double) async {
        let state = request.state
        // Bound the drift-recompute retries below. Each retry handles a
        // setString reload that changed the text without issuing a new
        // request; a pathological reload storm could otherwise spin here
        // indefinitely. After the cap we stop and let the next genuine
        // request repaint, which is strictly better than looping forever.
        var driftRetries = 0
        let maxDriftRetries = 8

        // Recompute against the current text until it stops drifting under
        // us, all under this single request's generation. A drift with no
        // new request happens when a presentedItemDidChange reload replaces
        // the text via setString, which never routes through a new highlight
        // request and so never bumps the generation; without this retry the
        // document would be left unhighlighted. A genuinely newer request
        // does bump the generation, which breaks the loop below so the newer
        // request wins instead of this one clobbering it. Each await frees
        // the main actor, so this never starves other work.
        var attemptText = initialText
        while true {
            let snapshot = attemptText
            let languageName = request.languageName
            #if DEBUG
            let spanStart = DispatchTime.now().uptimeNanoseconds
            #endif
            let spans = await Task.detached(priority: .userInitiated) {
                CodeEditSyntaxDefinitions.highlightSpans(text: snapshot, language: languageName)
            }.value
            #if DEBUG
            let spanMs = Double(DispatchTime.now().uptimeNanoseconds - spanStart) / 1_000_000
            #endif

            // A newer request for THIS storage superseded us while we
            // computed; that request will apply its own result, so stop.
            guard request.generation == state.latestGeneration, !Task.isCancelled else {
                #if DEBUG
                debugRuntimeLog("PlainSyntaxHighlighter dropped superseded generation=\(request.generation) latest=\(state.latestGeneration)")
                #endif
                HighlightStateStore.settle(state: state, generation: request.generation)
                return
            }

            // Text drifted with no newer request (reload via setString).
            // Recompute against the current text rather than applying stale
            // spans or leaving the document unhighlighted.
            let currentText = request.storage.string
            guard currentText == snapshot else {
                driftRetries += 1
                guard driftRetries <= maxDriftRetries else {
                    #if DEBUG
                    debugRuntimeLog("PlainSyntaxHighlighter drift retry cap reached generation=\(request.generation) retries=\(driftRetries)")
                    #endif
                    HighlightStateStore.settle(state: state, generation: request.generation)
                    return
                }
                #if DEBUG
                debugRuntimeLog("PlainSyntaxHighlighter recomputing after text drift generation=\(request.generation) retry=\(driftRetries)")
                #endif
                attemptText = currentText
                continue
            }

            state.cachedLanguage = languageName
            state.cachedText = snapshot
            state.cachedSpans = spans
            #if DEBUG
            let elapsedMilliseconds = Int((CFAbsoluteTimeGetCurrent() - request.startTime) * 1000)
            #else
            let elapsedMilliseconds = 0
            #endif
            #if DEBUG
            let paintStart = DispatchTime.now().uptimeNanoseconds
            #endif
            HighlightPainter.applyHighlight(
                spans: spans,
                storage: request.storage,
                text: snapshot,
                languageName: languageName,
                layoutTarget: request.layoutTarget,
                elapsedMilliseconds: elapsedMilliseconds,
                state: state
            )
            #if DEBUG
            // Whole-document paint over a small (< bounded threshold) document,
            // measured per edit so the low-end floor attribution can see
            // how much of the fixed cost is this synchronous paint (which on this
            // path includes the DEBUG token-summary logging) versus the scheduling
            // hop and the off-main span compute.
            PlainSyntaxHighlighter.emitKeystrokePhaseMarkers(
                schedMs: schedMs,
                spanMs: spanMs,
                paintMs: Double(DispatchTime.now().uptimeNanoseconds - paintStart) / 1_000_000
            )
            #endif
            // applyHighlight has finished painting and laying out on the
            // main actor; the full end-to-end pass for this generation is
            // now complete, so release any bench waiter timing it.
            HighlightStateStore.settle(state: state, generation: request.generation)
            return
        }
    }

    // Paints the viewport region on a large document before the whole-document
    // pass. Runs inside the full pass's task under the same generation, so it is
    // superseded together with the full pass by any newer edit. A no-op when
    // there is no layout target or the document is small enough to interpret in
    // one pass.
    private static func paintViewportFirst(_ request: Request) async {
        guard let layoutTarget = request.layoutTarget,
              request.storage.length >= HighlightRegionPlanner.viewportFirstMinimumDocumentLength,
              let viewport = HighlightRegionPlanner.viewportRegion(layoutTarget: layoutTarget),
              viewport.length > 0,
              viewport.length < request.storage.length else {
            return
        }
        let viewportText = request.storage.mutableString.substring(with: viewport)
        let languageName = request.languageName
        let spans = await Task.detached(priority: .userInitiated) {
            CodeEditSyntaxDefinitions.highlightSpans(text: viewportText, language: languageName)
        }.value
        guard request.generation == request.state.latestGeneration, !Task.isCancelled else { return }
        HighlightPainter.applyBoundedHighlight(
            spans: spans,
            storage: request.storage,
            region: viewport,
            layoutTarget: layoutTarget
        )
    }
}
