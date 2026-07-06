## 2026-07-06

### Fixes and Maintenance

- Replaced the upstream README with a shorter fork-focused front page.
- Linked the README to the docs that already exist in this repository.
- Added a root `build.sh` wrapper for `xcodebuild` on the `CodeEdit` scheme.
- Split the build helper into `build_debug.sh` and `build_release.sh` to match the app workflow.
- Added an early Xcode simulator-component check so build scripts fail with a clearer message when Xcode is incomplete.
- Vendored the CodeEdit-owned Swift packages into `Packages/` and rewired the project to use local package paths.
- Replaced the runtime `ZIPFoundation` dependency with a local unzip helper backed by the system `unzip` tool.
- Added a new `CodeEditHighlighting` package skeleton to define the app-facing syntax highlight span model and protocol.
- Wired `CodeEditSourceEditor` to depend on the new shared highlighting package boundary.
- Added a resource-only `CodeEditSyntaxDefinitions` package skeleton for declarative syntax definition files.
- Added a syntax-rule-set comparison note to keep the format decision explicit.
- Added a removal plan so cleanup can proceed in a bounded order.
- Added a data-first directory layout for the syntax-definition bundle.
- Added an audit note to bound the remaining cleanup surface.
- Removed the default parser-backed provider from the editor entry points.
- Reduced `CodeEditLanguages` to metadata-only source files in the package target.
- Removed parser references from the source editor package docs and comments.
- Continued the SwiftPM-first, source-first refactor toward a smaller editor/highlighting boundary.
