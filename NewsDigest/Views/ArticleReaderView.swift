import SwiftUI
import WebKit

struct ArticleReaderView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var speechService: SpeechService
    @State private var isLoading = true
    @State private var webView: WKWebView?
    @State private var isExtracting = false

    var body: some View {
        VStack(spacing: 0) {
            readerToolbar

            if speechService.isSpeaking {
                ProgressView(value: speechService.progress)
                    .tint(Color.flipRed)
                    .scaleEffect(y: 0.5)
            } else {
                Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)
            }

            if let url = URL(string: article.url) {
                WebView(url: url, isLoading: $isLoading, webViewRef: $webView)
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                    Text("Invalid URL")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { article.isRead = true }
        .onDisappear { speechService.stop() }
    }

    // MARK: - Toolbar

    private var readerToolbar: some View {
        HStack(spacing: 12) {
            // Source dot + info
            Circle()
                .fill(sourceColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(article.title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text(article.sourceName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView().scaleEffect(0.45).frame(width: 14, height: 14)
            }

            // Audio controls
            audioControls

            Button {
                if let url = URL(string: article.url), url.scheme == "https" || url.scheme == "http" {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "safari").font(.system(size: 10))
                    Text("Browser").font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08), in: Capsule())
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                speechService.stop()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.flipRed, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectBackground(material: .headerView, blendingMode: .withinWindow))
    }

    // MARK: - Audio Controls

    @ViewBuilder
    private var audioControls: some View {
        if speechService.isSpeaking {
            HStack(spacing: 4) {
                Button { speechService.stop() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill").font(.system(size: 8))
                        Text("Stop").font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.12), in: Capsule())
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Button {
                    if speechService.isPaused { speechService.resume() } else { speechService.pause() }
                } label: {
                    Image(systemName: speechService.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9))
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.08), in: Circle())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button { readArticleAloud() } label: {
                HStack(spacing: 4) {
                    if isExtracting {
                        ProgressView().scaleEffect(0.35).frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "headphones").font(.system(size: 10))
                    }
                    Text("Listen").font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.flipRed, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || isExtracting)
            .opacity(isLoading ? 0.5 : 1)
        }
    }

    // MARK: - Extract & Read

    private func readArticleAloud() {
        guard let wv = webView else { return }
        // Verify the WebView is still on the expected article URL
        guard let currentURL = wv.url,
              let expectedURL = URL(string: article.url),
              currentURL.host == expectedURL.host else { return }

        isExtracting = true

        let js = """
        (function() {
            var selectors = ['article', '[role="main"]', '.post-content', '.article-body',
                             '.entry-content', '.post-body', '.story-body', 'main'];
            var el = null;
            for (var i = 0; i < selectors.length; i++) {
                el = document.querySelector(selectors[i]);
                if (el && el.innerText.trim().length > 200) break;
                el = null;
            }
            if (!el) el = document.body;
            var text = el.innerText;
            text = text.replace(/\\n{3,}/g, '\\n\\n').replace(/\\t/g, ' ');
            return text.trim().substring(0, 15000);
        })()
        """

        wv.evaluateJavaScript(js) { result, error in
            DispatchQueue.main.async {
                isExtracting = false
                if let text = result as? String, !text.isEmpty {
                    // Limit text length on Swift side as well
                    let safeText = String(text.prefix(15000))
                    let intro = article.title + ". From " + article.sourceName + ". "
                    speechService.speakNatural(intro + safeText)
                }
            }
        }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return Color.flipRed
        }
    }
}

// MARK: - WKWebView wrapper

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var webViewRef: WKWebView?

    private static let allowedSchemes: Set<String> = ["https", "http"]

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Only load if URL scheme is safe
        if Self.allowedSchemes.contains(url.scheme?.lowercased() ?? "") {
            webView.load(URLRequest(url: url))
        }
        DispatchQueue.main.async { self.webViewRef = webView }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        private let allowedSchemes: Set<String> = ["https", "http"]

        init(isLoading: Binding<Bool>) { _isLoading = isLoading }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading = false }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(scheme) else {
                return .cancel
            }
            // Open clicked links in external browser
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
