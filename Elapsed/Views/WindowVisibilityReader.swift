import AppKit
import SwiftUI

/// MenuBarExtra の `.window` スタイルは、閉じてもビューを破棄しない（perf.csv の `body.popover` で確認）。
/// ビューのライフサイクル（onAppear / onDisappear）ではなく、ホストしている NSWindow が画面に出ているかで判定する
struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityTrackingView {
        let view = VisibilityTrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: VisibilityTrackingView, context: Context) {
        nsView.onChange = onChange
    }
}

final class VisibilityTrackingView: NSView {
    var onChange: ((Bool) -> Void)?
    private var observer: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObserver()
        guard let window else { return }

        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.reportVisibility()
        }
        // viewDidMoveToWindow は SwiftUI のビュー更新の途中で呼ばれ、ここで @State を書き換えると警告になるため、次の周回に回す
        DispatchQueue.main.async { [weak self] in
            self?.reportVisibility()
        }
    }

    deinit {
        removeObserver()
    }

    private func reportVisibility() {
        guard let window else { return }
        onChange?(window.occlusionState.contains(.visible))
    }

    private func removeObserver() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
