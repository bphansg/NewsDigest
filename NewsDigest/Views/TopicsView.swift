import SwiftUI

struct TopicsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showAddSheet = false
    @State private var newTopicName = ""
    @State private var newTopicKeywords = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Topics")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("\(viewModel.topics.count)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.5), in: Capsule())

                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Topic")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(.quaternary.opacity(0.4))
                .frame(height: 1)

            if viewModel.topics.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No topics yet",
                    subtitle: "Create topics with keywords to automatically filter and prioritize your feed."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.topics, id: \.id) { topic in
                            TopicCard(topic: topic)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTopicSheet(
                name: $newTopicName,
                keywords: $newTopicKeywords,
                onSave: {
                    let keywordList = newTopicKeywords
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    viewModel.addTopic(name: newTopicName, keywords: keywordList)
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
}

// MARK: - Topic Card

struct TopicCard: View {
    let topic: Topic
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var isExpanded = false
    @State private var isHovered = false

    var matchCount: Int {
        viewModel.articles.filter { $0.topicName == topic.name }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                // Topic icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            topic.enabled
                                ? LinearGradient(colors: [.purple.opacity(0.15), .indigo.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.gray.opacity(0.08), .gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(topic.enabled ? Color.purple : Color.gray.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(topic.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(topic.enabled ? .primary : .secondary)

                    HStack(spacing: 8) {
                        Text("\(topic.keywords.count) keywords")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        if matchCount > 0 {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 5, height: 5)
                                Text("\(matchCount) matches")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { topic.enabled },
                    set: { _ in viewModel.toggleTopic(topic) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? -180 : 0))
                        .frame(width: 28, height: 28)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    viewModel.deleteTopic(topic)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(14)

            if isExpanded {
                Rectangle()
                    .fill(.quaternary.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                FlowLayout(spacing: 6) {
                    ForEach(topic.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.purple.opacity(0.08), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.quaternary.opacity(isHovered ? 0.8 : 0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 2, y: isHovered ? 4 : 1)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = h }
        }
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
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)

                    Image(systemName: "tag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("New Topic")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                TextField("e.g. AI & Machine Learning", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("KEYWORDS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                TextField("artificial intelligence, machine learning, llm, gpt", text: $keywords)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Separate keywords with commas. Articles containing any keyword will match.")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .font(.system(size: 13))

                Button(action: onSave) {
                    Text("Create Topic")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
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
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
