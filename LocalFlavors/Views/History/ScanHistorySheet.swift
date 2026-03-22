import SwiftUI

struct ScanHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AnalysisResult) -> Void

    @State private var entries: [ScanHistoryEntry] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle(String(localized: "history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "history.close")) { dismiss() }
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "history.deleteAll"), role: .destructive) {
                            ScanHistoryService.shared.clearAll()
                            withAnimation { entries = [] }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
            .onAppear {
                entries = ScanHistoryService.shared.loadAll()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "history.empty.title"))
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(String(localized: "history.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    onSelect(entry.result)
                    dismiss()
                } label: {
                    historyRow(entry)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    ScanHistoryService.shared.delete(entries[index].id)
                }
                entries.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Row

    private func historyRow(_ entry: ScanHistoryEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.restaurantName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(String(localized: "history.dishes \(entry.dishCount)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !entry.topPickNames.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Text(entry.topPickNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let rating = entry.restaurantRating {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
