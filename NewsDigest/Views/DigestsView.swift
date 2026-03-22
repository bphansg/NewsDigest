import SwiftUI

struct DigestsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var speechService: SpeechService
    @State private var selectedDigest: Digest?
    @State private var digestCount = 15
    @State private var showReport = false
    @State private var reportText = ""

    var body: some View {
        VStack(spacing: 0) {
            digestHeader

            Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)

            HStack(spacing: 0) {
                digestList
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 320)

                Rectangle().fill(Color.secondary.opacity(0.1)).frame(width: 1)

                if let digest = selectedDigest {
                    DigestDetailView(digest: digest)
                } else {
                    digestEmpty
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(text: reportText)
        }
    }

    private var digestHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Digests")
                .font(.system(size: 28, weight: .bold, design: .serif))
            Spacer()
            HStack(spacing: 10) {
                Stepper("Articles: \(digestCount)", value: $digestCount, in: 5...30)
                    .font(.system(size: 12))
                    .frame(width: 150)

                Button {
                    reportText = viewModel.generateReport(count: digestCount)
                    showReport = true
                } label: {
                    Text("Report")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.articles.isEmpty)

                Button {
                    if let d = viewModel.generateDigest(count: digestCount) { selectedDigest = d }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
                        Text("Generate").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.flipRed, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.articles.isEmpty)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var digestList: some View {
        Group {
            if viewModel.digests.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "text.document")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                    Text("No digests")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.digests, id: \.id) { digest in
                            DigestRow(digest: digest, isSelected: selectedDigest?.id == digest.id) {
                                selectedDigest = digest
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private var digestEmpty: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.document")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text("Select a digest")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Digest Row

struct DigestRow: View {
    let digest: Digest
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(digest.title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(digest.articleIDs.count)", systemImage: "newspaper")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    statusBadge
                    Spacer()
                    Text(digest.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.flipRed.opacity(0.08) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.flipRed.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var statusText: String {
        switch digest.status {
        case .draft: return "Draft"
        case .ready: return "Ready"
        case .narrating: return "Narrating"
        case .narrated: return "Audio"
        }
    }

    private var statusColor: Color {
        switch digest.status {
        case .draft: return .gray
        case .ready: return .green
        case .narrating: return .orange
        case .narrated: return .blue
        }
    }

    var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
    }
}

// MARK: - Digest Detail

struct DigestDetailView: View {
    let digest: Digest
    @EnvironmentObject var viewModel: NewsViewModel
    @EnvironmentObject var speechService: SpeechService
    @State private var readerArticle: Article?

    var digestArticles: [Article] {
        viewModel.articlesForDigest(digest)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailHeader
                detailArticles
                detailScript
            }
            .padding(24)
        }
        .sheet(item: $readerArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(digest.title)
                .font(.system(size: 22, weight: .bold, design: .serif))
            Text(digest.createdAt.formatted(date: .complete, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if speechService.isSpeaking {
                    Button { speechService.stop() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill").font(.system(size: 9))
                            Text("Stop").font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12), in: Capsule())
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    ProgressView(value: speechService.progress)
                        .tint(Color.flipRed)
                        .frame(maxWidth: 160)
                } else {
                    Button {
                        if let s = digest.audioScript { speechService.speakNatural(s) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            Text("Listen").font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.flipRed, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(digest.audioScript == nil)
                    .opacity(digest.audioScript == nil ? 0.4 : 1)
                }

                Button {
                    if let s = digest.audioScript {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(s, forType: .string)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc").font(.system(size: 10))
                        Text("Copy Script").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
    }

    private var detailArticles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stories")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(digestArticles.enumerated()), id: \.element.id) { i, article in
                    DigestArticleRow(article: article) { readerArticle = article }
                    if i < digestArticles.count - 1 {
                        Rectangle().fill(Color.secondary.opacity(0.08)).frame(height: 1).padding(.leading, 40)
                    }
                }
            }
            .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var detailScript: some View {
        if let script = digest.audioScript {
            VStack(alignment: .leading, spacing: 10) {
                Text("Script")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(.secondary)
                Text(script)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
            }
        }
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let text: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Digest Report")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Text("Copy").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Button { saveReport() } label: {
                    Text("Save").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Text("Done").font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(Color.flipRed, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
        }
        .padding(28)
        .frame(width: 720, height: 520)
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "NewsDigest-Report-\(Date().formatted(date: .numeric, time: .omitted)).md"
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Digest Article Row

struct DigestArticleRow: View {
    let article: Article
    let onRead: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(sourceColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(article.sourceName).font(.system(size: 10)).foregroundStyle(.secondary)
                    if article.hnPoints > 0 {
                        Text("\(article.hnPoints) pts").font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            HStack(spacing: 2) {
                CardAction(icon: "doc.text", help: "Read") { onRead() }
                CardAction(icon: "safari", help: "Browser") {
                    if let url = URL(string: article.url), url.scheme == "https" || url.scheme == "http" { NSWorkspace.shared.open(url) }
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onRead() }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { isHovered = h } }
    }

    private var sourceColor: Color {
        switch article.source {
        case .hackerNews: return .orange
        case .substack: return .purple
        case .rss: return Color.flipRed
        }
    }
}
