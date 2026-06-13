import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(visionOS)
import UIKit
#endif

@MainActor
enum SwiftUIViewDiagnosticHost {
    static func render<Content: View>(
        _ view: Content,
        width: CGFloat = 640,
        height: CGFloat = 480
    ) {
        #if os(visionOS)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            let host = UIHostingController(rootView: AnyView(view))
            host.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.rootViewController = host
            window.frame = CGRect(x: 0, y: 0, width: width, height: height)
            window.makeKeyAndVisible()

            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))

            window.isUserInteractionEnabled = false
            window.resignKey()
            window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
            retainedWindows.append(window)
            if retainedWindows.count > 8 {
                retainedWindows.removeFirst(retainedWindows.count - 8)
            }
        } else {
            let host = UIHostingController(rootView: AnyView(view))
            host.loadViewIfNeeded()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }
        #elseif os(macOS)
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: width, height: height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        window.orderOut(nil)
        host.layoutSubtreeIfNeeded()
        retainedWindows.append(window)
        if retainedWindows.count > 8 {
            retainedWindows.removeFirst(retainedWindows.count - 8)
        }
        #else
        _ = view
        #endif
    }

    #if os(visionOS)
    private static var retainedWindows: [UIWindow] = []
    #elseif os(macOS)
    private static var retainedWindows: [NSWindow] = []
    #endif
}
