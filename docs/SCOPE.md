# Project Scope

This document is short on purpose: it lists only non-negotiable rules.
User must approve any new scope items. Agents are not allowed to edit.

change App name to: SwiftlyCodeEdit
Tagline: A fast native code editor for macOS.

Incorporate as much liquid glass styling as possible.

This builds for macOS 26 Tahoe or newer and Apple Silicon arm based processors M1 or newer.

We are trying for 100% SwiftUI and Swift based code, where possible. the code is old, and I want to use modern 
swift/swiftUI best practices, so fix the architecture and update codebase as needed

We are building a text editor with syntax highlighting, not an IDE.


## Features of a Quality Code Editor

Here are the must-have features that make a code editor on Mac truly awesome:

- Speed: opens fast and does not lag
- Syntax highlighting: makes code colorful and easier to read
- super fast and lightweight, loads almost instantly
- clean, simple code editor without distractions, no confusing menus
- looks clean, feels smooth, and is built with macOS in mind
- syntax coloring and supports multiple languages
- text cleaning features, ASCII and Unicode support
- built-in find/replace with optional regex
- launch fast and work across languages without hogging memory
- auto-save and detects changes to files and updates in GUI
- ability to customize syntax highlighting and add new custom languages like Kate.app
- Syntax definitions are data files, not compiled parser packages.
- Users should be able to add syntax files later without rebuilding the app.
- Themes should also be data files.

## Possible Goals / Low Priority

These are lower priority because they introduce lag:

- Auto-complete: finishes code for you like magic
- Extensions or plugins: add cool features like AI helpers or code formatters

## Out of Scope / Non-Goals

- Built-in terminal: run commands right inside the editor
- Git support
- Cross-platform support
- heavier IDEs like IntelliJ or PyCharm


## Target Platform

- Target hardware is Apple Silicon M1 or newer.
- Target operating system is macOS 26 Tahoe or newer.
- Swift 6.3 or newer toolchain.
- Older support might work, but it is not a priority.
