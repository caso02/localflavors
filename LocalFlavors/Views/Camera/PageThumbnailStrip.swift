import SwiftUI

struct PageThumbnailStrip: View {
    @ObservedObject var session: ScanSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(session.pages.enumerated()), id: \.offset) { index, page in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: page)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )

                        // Delete button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                session.removePage(at: index)
                            }
                            HapticsService.light()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(.red, in: Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                // Clear all button (if more than 1 page)
                if session.pages.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            session.reset()
                        }
                        HapticsService.light()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption2)
                            Text("Alle")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, height: 56)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 76)
        .background(.ultraThinMaterial.opacity(0.5))
    }
}
