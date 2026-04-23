import Localization
import NoorUI
import QuranKit
import SwiftUI
import UIx

struct HighlightsView: View {
    @StateObject var viewModel: HighlightsViewModel

    var body: some View {
        NoorList {
            NoorSection(viewModel.items) { item in
                NoorListItem(
                    image: .init(.bookmark, color: item.collection.color.color),
                    title: .text(l(item.collection.localizationKey)),
                    accessory: .text(NumberFormatter.shared.format(item.count))
                ) {
                    viewModel.showDetails(item)
                }
            }
        }
        .task { await viewModel.start() }
        .errorAlert(error: $viewModel.error)
    }
}

struct HighlightColorView: View {
    @StateObject var viewModel: HighlightsColorViewModel

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                DataUnavailableView(
                    title: l("highlights.no-data.title"),
                    text: l("highlights.no-data.text"),
                    image: .bookmark
                )
            } else {
                NoorList {
                    NoorSection(viewModel.items) { item in
                        highlightRow(item)
                    }
                }
            }
        }
        .task { await viewModel.start() }
        .errorAlert(error: $viewModel.error)
    }

    private func highlightRow(_ item: HighlightsColorViewModel.Item) -> some View {
        let verse = item.ayah
        let verseHeader = "\(verse.localizedName) \(verse.sura.arabicSuraName)"

        return Button {
            viewModel.navigateTo(item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verseHeader)
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryLabel)

                        Text(item.verseText)
                            .lineLimit(2)
                            .font(.body)
                            .foregroundStyle(Color.label)
                            .multilineTextAlignment(.leading)

                        Text(item.modifiedDate.timeAgo())
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryLabel)
                    }

                    Spacer(minLength: 12)

                    Text(NumberFormatter.shared.format(verse.page.pageNumber))
                        .font(.body)
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
