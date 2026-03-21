import SwiftUI

struct TopicsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showAddSheet = false
    @State private var newTopicName = ""
    @State private var newTopicKeywords = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .lastTextBaseline) {
                Text("Your Topics")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New Topic")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.flipRed, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)

            if viewModel.topics.isEmpty {
                topicsEmpty
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ], spacing: 14) {
                        ForEach(viewModel.topics, id: \.id) { topic in
                            TopicTile(topic: topic)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTopicSheet(
                name: $newTopicName,
                keywords: $newTopicKeywords,
                onSave: {
                    let kws = newTopicKeywords.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    viewModel.addTopic(name: newTopicName, keywords: kws)
                    newTopicName = ""
                    newTopicKeywords = ""
                    showAddSheet = false
                },
                onCancel: {
                    newTopicName = ""
                    newTopicKeywords = ""
                    showAddSheet = false
                }
            )
        }
    }

    private var topicsEmpty: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "number")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.secondary)
            Text("No topics yet")
                .font(.system(size: 18, weight: .semibold, design: .serif))
            Text("Create topics to personalize your feed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Topic Tile (Flipboard magazine-style)

struct TopicTile: View {
    let topic: Topic
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var isHovered = false
    @State private var isExpanded = false

    var matchCount: Int {
        viewModel.articles.filter { $0.topicName == topic.name }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(
                            topic.enabled
                                ? LinearGradient(colors: [Color.flipRed, Color(red: 0.7, green: 0.08, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 70)

                    Text("#")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundStyle(.white.opacity(0.15))
                        .padding(.leading, 12)
                        .padding(.bottom, 4)
                }

                Toggle("", isOn: Binding(
                    get: { topic.enabled },
                    set: { _ in viewModel.toggleTopic(topic) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .padding(8)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(topic.name)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(topic.enabled ? .primary : .secondary)

                HStack(spacing: 10) {
                    Text("\(topic.keywords.count) keywords")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if matchCount > 0 {
                        Text("\(matchCount) matches")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }

                if isExpanded {
                    FlowLayout(spacing: 4) {
                        ForEach(topic.keywords, id: \.self) { kw in
                            Text(kw)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.flipRed.opacity(0.08), in: Capsule())
                                .foregroundStyle(Color.flipRed)
                        }
                    }
                    .padding(.top, 2)
                }

                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(role: .destructive) {
                        viewModel.deleteTopic(topic)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(12)
        }
        .background(Color.flipCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 3, y: isHovered ? 4 : 1)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovered = h } }
    }
}

// MARK: - Add Topic Sheet

struct AddTopicSheet: View {
    @Binding var name: String
    @Binding var keywords: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.flipRed)
                        .frame(width: 30, height: 30)
                    Text("#")
                        .font(.system(size: 16, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                }
                Text("New Topic")
                    .font(.system(size: 18, weight: .bold, design: .serif))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.5)
                TextField("e.g. AI & Machine Learning", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("KEYWORDS")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).tracking(0.5)
                TextField("artificial intelligence, llm, gpt, deep learning", text: $keywords)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Comma-separated. Articles matching any keyword will be tagged.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(action: onSave) {
                    Text("Create")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(Color.flipRed, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || keywords.isEmpty)
                .opacity(name.isEmpty || keywords.isEmpty ? 0.5 : 1)
            }
        }
        .padding(28)
        .frame(width: 460)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, s.height)
            x += s.width + spacing
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowH), positions)
    }
}
