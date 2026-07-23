# Design QA

- Source visual truth: `/var/folders/kf/647f4_w56v77q5zfz3n48f4c0000gn/T/codex-clipboard-b741b564-b552-4cb5-9ae5-5c198bacbce8.png`
- Implementation screenshot: `/tmp/runtime-atlas-implementation.png`
- Combined comparison: `/tmp/runtime-atlas-comparison.png`
- Viewport: native macOS window, approximately 756 × 939 pt
- Pixels and density: source 1514 × 1878 px, implementation 1512 × 1878 px, both normalized to 2× density
- State: dark mode, `CCT-production_bug` selected, update banner visible only in the implementation

## Evidence

The full-view comparison confirms that the separate native title/toolbar row is removed, the standard macOS window controls remain available, and repository add/refresh actions now sit in the sidebar header. The update banner is confined to the detail pane and does not overlap the window controls.

The focused top-chrome comparison was sufficient because the requested change is limited to window chrome and action placement. Existing typography, colors, SF Symbols, copy, content hierarchy, and non-chrome spacing remain consistent with the source.

## Findings

No actionable P0, P1, or P2 differences remain for the requested change.

## Comparison history

- Initial implementation: the sidebar header sat too far below the window controls because its top padding was 36 pt.
- Fix: reduced the top padding to 12 pt.
- Post-fix evidence: `/tmp/runtime-atlas-implementation.png` shows the header and controls sharing a compact top region without overlap.

## Implementation checklist

- Hidden native title bar while retaining standard window controls.
- Moved repository add and refresh actions into the repository header.
- Preserved accessibility labels, help text, disabled refresh state, menu commands, and keyboard shortcuts.
- Kept the update banner clear of the window controls.

final result: passed
