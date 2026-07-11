//
//  PlainEditorWindowCaptureTests.swift
//  CodeEditTests
//
//  Covers the pure path-validation half of the window self-capture seam.
//  The rendering half needs a live AppKit window and is proven end to end by the
//  _temp capture proof runner, not by swift test.
//

#if DEBUG
import Foundation
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorWindowCaptureTests {
    @Test
    func absolutePathResolvesToMatchingFileURL() {
        let destination = PlainEditorWindowCapture.resolveCaptureDestination(argument: "/tmp/wp_g0_capture.png")

        #expect(destination?.path == "/tmp/wp_g0_capture.png")
        #expect(destination?.isFileURL == true)
    }

    @Test
    func missingArgumentResolvesToNil() {
        #expect(PlainEditorWindowCapture.resolveCaptureDestination(argument: nil) == nil)
    }

    @Test
    func emptyArgumentResolvesToNil() {
        #expect(PlainEditorWindowCapture.resolveCaptureDestination(argument: "") == nil)
    }

    @Test
    func relativePathResolvesToNil() {
        #expect(PlainEditorWindowCapture.resolveCaptureDestination(argument: "wp_g0_capture.png") == nil)
    }
}
#endif
