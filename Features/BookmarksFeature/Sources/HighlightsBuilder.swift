import AppDependencies
import FeaturesSupport
import UIKit

@MainActor
struct HighlightsBuilder {
    init(container: AppDependencies, listener: QuranNavigator) {
        self.container = container
        self.listener = listener
    }

    func build() -> UIViewController {
        guard let syncService = container.syncService else {
            preconditionFailure("Highlights require syncService")
        }

        let highlightCollectionsUpdates = {
            HighlightCollection.updates(from: syncService)
        }

        let viewModel = HighlightsViewModel(
            highlightCollectionsUpdates: highlightCollectionsUpdates,
            makeColorController: { [container, weak listener] collection in
                let detailViewModel = HighlightsColorViewModel(
                    collection: collection,
                    highlightCollectionsUpdates: highlightCollectionsUpdates,
                    noteService: container.noteService(),
                    navigateTo: { [weak listener] verse in
                        listener?.navigateTo(page: verse.page, lastPage: nil, highlightingSearchAyah: nil)
                    }
                )
                return HighlightColorViewController(collection: collection, viewModel: detailViewModel)
            }
        )
        let viewController = HighlightsViewController(viewModel: viewModel)
        viewModel.presenter = viewController
        return viewController
    }

    private let container: AppDependencies
    private weak var listener: QuranNavigator?
}
