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
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Digests")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("\(viewModel.digests.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.5), in: Capsule())

                Spacer()

                HStack(spacing: 10) {
                    Stepper("Articles: \(digestCount)", value: $digestCount, in: 5...30)
                        .font(.system(size: 12))
                        .frame(width: 155)

                    Button {
                        reportText = viewModel.generateReport(count: digestCount)
                        showReport = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                            Text("Report")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.quaternary.opacity(0.4), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.articles.isEmpty)

                    Button {
                        if let digest = viewModel.generateDigest(count: digestCount) {
                            selectedDigest = digest
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Generate")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.articles.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(.quaternary.opacity(0.4))
                .frame(height: 1)

            // Content
            HStack(spacing: 0) {
                // Digest list
                VStack(spacing: 0) {
                    if viewModel.digests.isEmpty {
                        EmptyStateView(
                            icon: "waveform.and.doc",
                            title: "No digests yet",
                            subtitle: "Generate a digest to curate your top stories."
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(viewModel.digests, id: \.id) { digest in
                                    DigestListRow(
                                        digest: digest,
                                        isSelected: selectedDigest?.id == digest.id
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedDigest = digest
                                        }
                                    }
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 320)

                Rectangle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 1)

                // Detail
                if let digest = selectedDigest {
                    DigestDetailView(digest: digest)
                } else {
                    EmptyStateView(
                        icon: "text.document",
                        title: "Select a digest",
                        subtitle: "Choose a digest from the list to view its contents."
                    )
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(text: reportText)
        }
    }
}

// MARK: - Digest List Row

struct DigestListRow: View {
    let digest: Digest
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(digest.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 9))
                        Text("\(digest.articleIDs.count)")
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundStyle(.tertiary)

                    statusBadge

                    Spacer()

                    Text(digest.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
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
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
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
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    Text(digest.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("Created \(digest.createdAt.formatted(date: .complete, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    // Audio controls
                    HStack(spacing: 10) {
                        if speechService.isSpeaking {
                            Button {
                                speechService.stop()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 10))
                                    Text("Stop")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.red.opacity(0.12), in: Capsule())
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)

                            ProgressView(value: speechService.progress)
                                .tint(.blue)
                                .frame(maxWidth: 180)
                        } else {
                            Button {
                                if let script = digest.audioScript {
                                    speechService.speak(script)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Listen")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(digest.audioScript == nil)
                            .opacity(digest.audioScript == nil ? 0.4 : 1)
                        }

                        Button {
                            if let script = digest.audioScript {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(script, forType: .string)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy Script")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.quaternary.opacity(0.4), in: Capsule())
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.quaternary.opacity(0.4), lineWidth: 1)
                )

                // Articles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Articles")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(digestArticles.enumerated()), id: \.element.id) { index, article in
                            DigestArticleRow(article: article, onRead: { readerArticle = article })

                            if index < digestArticles.count - 1 {
                                Rectangle()
                                    .fill(.quaternary.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary.opacity(0.4), lineWidth: 1)
                    )
                }

                // Script preview
                if let script = digest.audioScript {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Audio Script")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(script)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.quaternary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $readerArticle) { article in
            ArticleReaderView(article: article)
                .frame(width: 900, height: 650)
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
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)

                        Image(systemName: "doc.text")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Digest Report")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.4), in: Capsule())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    saveReport()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                        Text("Save")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.4), in: Capsule())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
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

            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary.opacity(0.4), lineWidth: 1)
            )
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
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(sourceColor.opacity(0.1))
                    .frame(width: 30, height: 30)

                Image(systemName: article.source.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(sourceColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(article.sourceName)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    if article.hnPoints > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(article.hnPoints)")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                    }
                    if let topic = article.topicName {
                        Text(topic)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            HStack(spacing: 2) {
                IconAction(icon: "doc.text", help: "Read in app") { onRead() }
                IconAction(icon: "safari", help: "Open in browser") {
                    if let url = URL(string: article.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onRead() }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = h }
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
