import SwiftUI
import WebKit

public struct WebPreviewScreen: View {
    public let url: URL
    @Environment(\.dismiss) private var dismiss
    public init(url: URL) { self.url = url }
    public var body: some View {
        NavigationStack {
            WebPreview(url: url)
                .navigationTitle("Prévia local")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } } }
        }
    }
}

public struct WebPreview: UIViewRepresentable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        return view
    }
    public func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.standardizedFileURL != url.standardizedFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }
}
