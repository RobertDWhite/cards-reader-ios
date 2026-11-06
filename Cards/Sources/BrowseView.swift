import SwiftUI

struct CardRoute: Hashable {
    let cards: [Card]
    let index: Int
}

struct BrowseView: View {
    @Environment(ArchiveStore.self) private var store
    @State private var query = ""
    @State private var folder: String?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14, alignment: .top)]

    private var words: [String] {
        query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func visibleSections(_ archive: Archive) -> [CardSection] {
        let w = words
        return archive.sections.compactMap { s in
            if let folder, s.name != folder { return nil }
            var s = s
            if !w.isEmpty { s.cards = s.cards.filter { $0.matches(w) } }
            return s.cards.isEmpty ? nil : s
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let archive = store.archive {
                    content(archive)
                } else if case .failed(let msg) = store.state {
                    ContentUnavailableView {
                        Label("Can't load the archive", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(msg)
                    } actions: {
                        Button("Try Again") { Task { await store.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ProgressView("Loading cards…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper)
            .navigationTitle("Cards")
            .navigationDestination(for: CardRoute.self) { CardPagerView(route: $0) }
        }
    }

    @ViewBuilder
    private func content(_ archive: Archive) -> some View {
        let sections = visibleSections(archive)
        ScrollViewReader { proxy in
            ScrollView {
                if words.isEmpty && folder == nil {
                    ArchiveHeader(archive: archive, notice: store.offlineNotice)
                }
                FolderChips(archive: archive, selection: $folder)
                    .id("chips")
                LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(Array(section.cards.enumerated()), id: \.element.id) { i, card in
                                    NavigationLink(value: CardRoute(cards: section.cards, index: i)) {
                                        CardTile(card: card)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        } header: {
                            SectionHeader(section: section, total: archive.sections.first { $0.name == section.name }?.cards.count ?? 0)
                                .id(section.name)
                        }
                    }
                    if sections.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .padding(.top, 40)
                    }
                }
                .padding(.bottom, 30)
            }
            .onChange(of: folder) {
                withAnimation { proxy.scrollTo(folder ?? archive.sections.first?.name, anchor: .top) }
            }
        }
        .searchable(text: $query, prompt: "Names, messages, publishers…")
        .refreshable { await store.refresh() }
    }
}

private struct ArchiveHeader: View {
    let archive: Archive
    let notice: String?

    var body: some View {
        VStack(spacing: 14) {
            if let r = archive.yearRange {
                Text("Every card kept and scanned, read and catalogued — \(String(r.lowerBound)) to \(String(r.upperBound)).")
                    .font(.serif(.subheadline))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                stat(archive.cardCount, "cards")
                stat(archive.pageCount, "pages")
                stat(archive.sections.count, "collections")
                if let r = archive.yearRange { stat(r.upperBound - r.lowerBound, "years") }
            }
            if let notice {
                Label(notice, systemImage: "icloud.slash")
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.serif(.title2, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(label.uppercased()).font(.caption2).tracking(1).foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FolderChips: View {
    let archive: Archive
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: archive.cardCount, on: selection == nil) { selection = nil }
                ForEach(archive.sections) { s in
                    chip(s.name, count: s.cards.count, on: selection == s.name) {
                        selection = selection == s.name ? nil : s.name
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, count: Int, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)").foregroundStyle(on ? Color.white.opacity(0.8) : Theme.ink2)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(on ? Theme.accent : Theme.paper2, in: Capsule())
            .overlay(Capsule().strokeBorder(on ? Color.clear : Theme.line))
            .foregroundStyle(on ? Color.white : Theme.ink)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
    }
}

private struct SectionHeader: View {
    let section: CardSection
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.name).font(.serif(.title2, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(section.cards.count == total ? "\(total) cards" : "\(section.cards.count) of \(total)")
                    .font(.caption).foregroundStyle(Theme.ink2)
            }
            if !section.blurb.isEmpty {
                Text(section.blurb)
                    .font(.serif(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.opacity(0.96))
    }
}

struct CardTile: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Theme.paper2
                    .aspectRatio(0.8, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if let cover = card.cover {
                            ScanImage(file: cover, maxPixel: 520)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "doc.questionmark")
                                Text("scan lost").font(.caption)
                            }
                            .foregroundStyle(Theme.ink2)
                        }
                    }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                if card.images.count > 1 {
                    Text("\(card.images.count) pages")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
            HStack(spacing: 4) {
                Text(card.yearText).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                if !card.flag.isEmpty {
                    Image(systemName: "exclamationmark.circle.fill").font(.caption).foregroundStyle(Theme.warn)
                }
            }
            Text(card.title)
                .font(.serif(.subheadline))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .contentShape(Rectangle())
    }
}
