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
            // Toolbar
            HStack(spacing: 14) {
                // Source badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(sourceColor.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: article.source.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(sourceColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(article.sourceName)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }

                // Audio controls
                audioButton

                Button {
                    if let url = URL(string: article.url) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                        Text("Browser")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    speechService.stop()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                VisualEffectBackground(material: .headerView, blendingMode: .withinWindow)
            )

            // Progress bar for audio
            if speechService.isSpeaking {
                ProgressView(value: speechService.progress)
                    .tint(.blue)
                    .scaleEffect(y: 0.5)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
            }

            // Web content
            if let url = URL(string: article.url) {
                WebView(url: url, isLoading: $isLoading, webViewRef: $webView)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Invalid URL",
                    subtitle: "This article's link appears to be broken."
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            article.isRead = true
        }
        .onDisappear {
            speechService.stop()
        }
    }

    // MARK: - Audio Button

    @ViewBuilder
    private var audioButton: some View {
        if speechService.isSpeaking {
            HStack(spacing: 4) {
                Button {
                    speechService.stop()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                        Text("Stop")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.12), in: Capsule())
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Button {
                    if speechService.isPaused {
                        speechService.resume()
                    } else {
                        speechService.pause()
                    }
                } label: {
                    Image(systemName: speechService.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                readArticleAloud()
            } label: {
                HStack(spacing: 5) {
                    if isExtracting {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "headphones")
                            .font(.system(size: 11))
                    }
                    Text("Listen")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
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
        isExtracting = true

        // JavaScript to extract the main article text from the page
        let js = """
        (function() {
            // Try common article selectors
            var selectors = ['article', '[role="main"]', '.post-content', '.article-body',
                             '.entry-content', '.post-body', '.story-body', 'main'];
            var el = null;
            for (var i = 0; i < selectors.length; i++) {
                el = document.querySelector(selectors[i]);
                if (el && el.innerText.trim().length > 200) break;
                el = null;
            }
            if (!el) el = document.body;

            // Get text, clean it up
            var text = el.innerText;
            // Remove excessive whitespace
            text = text.replace(/\\n{3,}/g, '\\n\\n');
            text = text.replace(/\\t/g, ' ');
            return text.trim().substring(0, 15000);
        })()
        """

        wv.evaluateJavaScript(js) { result, error in
            DispatchQueue.main.async {
                isExtracting = false
                if let text = result as? String, !text.isEmpty {
                    let intro = article.title + ". From " + article.sourceName + ". "
                    speechService.speakNatural(intro + text)
                }
            }
        }
    }

    var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return .blue
        }
    }
}

// MARK: - WKWebView wrapper

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var webViewRef: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        DispatchQueue.main.async { self.webViewRef = webView }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading = false }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
