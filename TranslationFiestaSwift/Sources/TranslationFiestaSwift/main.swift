import AppKit

// When run via `swift run` (no .app bundle), macOS treats the process as a
// background/accessory process by default.  Setting the activation policy to
// .regular before entering the SwiftUI run-loop makes it a normal GUI app
// with a Dock icon and the ability to own key windows.
NSApplication.shared.setActivationPolicy(.regular)

TranslationFiestaSwiftApp.main()
