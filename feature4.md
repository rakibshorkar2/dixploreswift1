

> Add a **"New Download"** feature to the existing **Downloads** tab of my Flutter iOS app without changing the current UI or download architecture.
>
> Requirements:
>
> * Add a **"+"** button (or download icon) in the Downloads app bar.
> * Tapping it opens a modal/bottom sheet with:
>
>   * URL input field
>   * "Paste from Clipboard" button
>   * Optional filename field (auto-filled when possible)
>   * "Download" and "Cancel" buttons
> * Validate that the entered URL is a valid HTTP or HTTPS URL.
> * Before downloading, perform an HTTP HEAD request (or GET if HEAD is not supported) to retrieve:
>
>   * Content-Length
>   * Content-Type
>   * Content-Disposition
>   * Accept-Ranges
> * Automatically determine the filename from `Content-Disposition` or the URL if no filename is provided.
> * Show a confirmation dialog displaying:
>
>   * Filename
>   * File size
>   * File type
>   * Resume support (Yes/No)
> * When the user confirms, create a download task using the app's existing download manager and queue system.
> * The download must use the app's existing SOCKS5 proxy settings if enabled.
> * Support large files and resumable downloads whenever the server supports HTTP Range requests.
> * Handle errors gracefully (invalid URL, network failure, expired links, permission issues, etc.).
> * Follow the existing project architecture, state management, and UI style. Do not rewrite existing download logic—only integrate this new feature cleanly into the current codebase.
>
> The goal is to let users paste any direct HTTP/HTTPS file link (for example, `.mp4`, `.zip`, `.mkv`, `.pdf`, `.iso`, etc.) and download it through the app just like a typical download manager.
