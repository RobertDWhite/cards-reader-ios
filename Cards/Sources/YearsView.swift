import SwiftUI

/// Every card on one timeline, newest year first.
struct YearsView: View {
    @Environment(ArchiveStore.self) private var store

    private struct YearGroup: Identifiable {
        let year: Int?
        let cards: [Card]
        var id: Int { year ?? -1 }
    }

    private func groups(_ archive: Archive) -> [YearGroup] {
        let all = archive.sections.flatMap(\.cards)
        let by = Dictionary(grouping: all, by: \.year)
        return by.keys
            .sorted { ($0 ?? Int.min) > ($1 ?? Int.min) }
            .map { y in YearGroup(year: y, cards: by[y]!.sorted { $0.title.lowercased() < $1.title.lowercased() }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let archive = store.archive {
                    List {
                        ForEach(groups(archive)) { g in
                            Section {
                                ForEach(Array(g.cards.enumerated()), id: \.element.id) { i, card in
                                    NavigationLink(value: CardRoute(cards: g.cards, index: i)) {
                                        YearRow(card: card)
                                    }
                                    .listRowBackground(Theme.paper2)
                                }
                            } header: {
                                HStack {
                                    Text(g.year.map(String.init) ?? "Undated")
                                        .font(.serif(.title3, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text("\(g.cards.count)").foregroundStyle(Theme.ink2)
                                }
                                .textCase(nil)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await store.refresh() }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper)
            .navigationTitle("Years")
            .navigationDestination(for: CardRoute.self) { CardPagerView(route: $0) }
        }
    }
}

private struct YearRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let cover = card.cover {
                    ScanImage(file: cover, maxPixel: 200)
                } else {
                    Image(systemName: "doc.questionmark").foregroundStyle(Theme.ink2)
                }
            }
            .frame(width: 48, height: 60)
            .background(Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title).font(.serif(.body)).foregroundStyle(Theme.ink).lineLimit(2)
                Text(card.folder).font(.caption).foregroundStyle(Theme.ink2)
            }
        }
        .padding(.vertical, 2)
    }
}
