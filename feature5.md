

The compact Dynamic Island appears correctly, but when I tap or long-press it, it does not expand to show a detailed download progress view.

Implement the Expanded Dynamic Island using ActivityKit and WidgetKit without changing any existing Flutter UI or download logic.

Requirements:
- Keep the existing compact Dynamic Island.
- Add an expanded Dynamic Island view that opens when tapped or long-pressed.
- Show:
  - File icon
  - File name
  - Progress bar
  - Download percentage
  - Downloaded size / Total size
  - Download speed
  - ETA
  - Download status (Downloading, Paused, Completed, Failed)
- Continue updating the expanded view as the download progresses.
- Use the existing MethodChannel to receive download updates from Flutter.
- Do not recreate the Live Activity for every update—only update the existing activity.
- End the Live Activity automatically when there are no active downloads.
- Support iOS 16.1+ and Dynamic Island devices.
- Modify the existing Widget Extension instead of creating a new implementation.
- Preserve all existing functionality.

After implementation, provide:
1. A list of modified files.
2. A brief explanation of the changes made.