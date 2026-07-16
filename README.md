# SymLinkdCache - made with love @onedaynot

Symbolic links to external caches 

OG PROMPT BELOW

You are an expert macOS developer. Build a native macOS utility app using SwiftUI (for macOS 14+) that allows users to easily migrate application cache and data folders to an external drive. 

The app must feature a point-and-click dashboard listing installed applications, detect their cache sizes, and safely execute migrations.

### 1. Aesthetic & UI Theme (Stark Minimalist / High-End Audio / Flat Geometric)
*   **Palette:** Strictly monochrome. Pure black, deep charcoal, crisp white, and subtle zinc grays. No standard window gradients or system blurs.
*   **Typography:** Bold, clean, flat sans-serif layout. Large typography for status states, minimal labels. Text-driven hierarchy.
*   **Visual Motifs:** Use flat lines, hard corners (no heavy standard rounded rectangles), circular progress indicators, and geometric dials/radio-style badges instead of standard Apple controls.
*   **State Colors (Monochrome Accentuation):**
    *   **Success:** A sharp, solid neon green indicator dot or inverted solid black-on-white text block.
    *   **Alert/Warning:** A sharp, solid amber or red indicator dot. No soft glow or gradients.

### 2. UI Structure (Two-Pane Flat Layout)
*   **Left Pane (The App Selector Matrix):**
    *   A clean vertical list of detected applications, sorted by cache size (largest first).
    *   No icons or colorful app badges. Instead, list the apps using clean, heavy text, paired with a simple flat circular indicator that fills up based on how much space it takes up relative to others.
    *   Example row layout: `[●] FIGMA ........................ 14.2 GB`

*   **Right Pane (The Functional Terminal / Control Deck):**
    *   Separated from the left pane by a single, 1px solid vertical line.
    *   Selecting an app dynamically fills this panel with its data and specific actions.

### 3. Dynamic Control Deck Logic
The right-hand panel must adapt instantly based on the selected application category:

#### Category A: Direct Migration (Figma, Spotify, Chrome, etc.)
*   **Status Readout:** Clear text displaying the current path and target path.
*   **Safety Interlock:** If the app is currently running, show a flashing text indicator or solid dot: `[!] APP RUNNING`. Provide a flat text button `[ FORCE QUIT ]`.
*   **The Action:** A large, circular or heavy rectangular block button: `[ INITIATE MIGRATION ]`. 
*   **Success State:** When done, transition the panel into an inverted black-and-white success screen displaying: `SUCCESS: +[X.X] GB FREED`.

#### Category B: Native Tweak Guidance (Adobe, DaVinci Resolve, etc.)
*   **Status Readout:** Clear, un-embellished text: `NATIVE CONFIGURATION REQUIRED`.
*   **The Instructions:** Render a stark, sequential text list detailing exactly what menus to click inside that app. Use numeric bullet points enclosed in perfect flat circles `①`, `②`, `③`.
*   **Direct Links:** Provide flat, plain text buttons for `[ LAUNCH APPLICATION ]` and `[ VIEW DOCUMENTATION ]`.

### 4. Technical Engine Requirements
*   **Scanning:** Asynchronously scan `~/Library/Caches/` and `~/Library/Application Support/` using background threads via Swift Concurrency (`async/await`) so the UI stays lightning-fast.
*   **File Operations:** Use Apple's native `FileManager` APIs for copying data, deleting local files, and creating symlinks.
*   **Permissions:** Include a minimal, hidden-by-default terminal-style overlay or initial view explaining how to grant "Full Disk Access" in macOS Settings if a file permission error occurs.
