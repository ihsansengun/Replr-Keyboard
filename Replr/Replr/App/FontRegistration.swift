import CoreText
import Foundation
import UIKit

/// Registers bundled custom fonts at launch so SwiftUI `Font.custom(...)` can resolve them.
/// The app target uses a generated Info.plist (no `UIAppFonts` array to edit), so we register
/// programmatically with Core Text instead.
enum ReplrFonts {
    /// Registers the bundled Fraunces variable font. Its named instances
    /// (`Fraunces-SemiBold`, `Fraunces-Bold`, …) then resolve via `ReplrTheme.Font.serif`.
    /// Idempotent — safe to call once at launch; an already-registered result is benign.
    static func registerBundledFonts() {
        guard let url = Bundle.main.url(forResource: "Fraunces-VF", withExtension: "ttf") else {
            assertionFailure("Missing bundled font Fraunces-VF.ttf")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            #if DEBUG
            if let e = error?.takeRetainedValue() {
                print("[Replr] Fraunces registration note:", e)
            }
            #endif
        }
    }
}
