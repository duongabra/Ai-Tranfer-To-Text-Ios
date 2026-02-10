//
//  MySwatchesViewModel.swift
//  Chat-Ai
//
//  ViewModel quản lý state cho màn My Swatches list
//

import Foundation

enum SwatchTab: Int, CaseIterable {
    case mySwatches = 0
    case saved = 1

    var title: String {
        switch self {
        case .mySwatches: return "All Swatches"
        case .saved: return "Favorites"
        }
    }
}

@MainActor
class MySwatchesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTab: SwatchTab = .mySwatches
    @Published var swatches: [Swatch] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    // Pagination
    @Published private(set) var currentPage = 1
    @Published private(set) var hasMore = false
    @Published private(set) var total = 0

    private let pageSize = 20

    // MARK: - Load Swatches

    /// Load swatches (reset pagination)
    func loadSwatches() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let response: SwatchListResponse
            switch selectedTab {
            case .mySwatches:
                response = try await SwatchService.shared.listSwatches(page: 1, pageSize: pageSize)
            case .saved:
                response = try await SwatchService.shared.listFavorites(page: 1, pageSize: pageSize)
            }

            swatches = response.items
            hasMore = response.hasMore
            total = response.total
            currentPage = 1
        } catch let error as SwatchServiceError {
            errorMessage = error.localizedDescription
            if case .unauthorized = error {
                await AuthService.shared.handleUnauthorizedError()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more swatches (pagination)
    func loadMoreIfNeeded(currentItem: Swatch) async {
        guard hasMore, !isLoadingMore else { return }

        // Check if current item is near the end
        guard let index = swatches.firstIndex(where: { $0.id == currentItem.id }),
              index >= swatches.count - 3 else {
            return
        }

        await loadMore()
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let response: SwatchListResponse
            switch selectedTab {
            case .mySwatches:
                response = try await SwatchService.shared.listSwatches(page: nextPage, pageSize: pageSize)
            case .saved:
                response = try await SwatchService.shared.listFavorites(page: nextPage, pageSize: pageSize)
            }

            swatches.append(contentsOf: response.items)
            hasMore = response.hasMore
            currentPage = nextPage
        } catch {
            print("[MySwatchesViewModel] Load more error: \(error)")
        }

        isLoadingMore = false
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(swatch: Swatch) async {
        do {
            let response = try await SwatchService.shared.toggleFavorite(swatchId: swatch.id)

            // Update local state
            if let index = swatches.firstIndex(where: { $0.id == swatch.id }) {
                swatches[index].isFavorited = response.isFavorited

                // Nếu đang ở tab Saved và unfavorite thì remove khỏi list
                if selectedTab == .saved && !response.isFavorited {
                    swatches.remove(at: index)
                }
            }
        } catch {
            print("[MySwatchesViewModel] Toggle favorite error: \(error)")
        }
    }

    // MARK: - Delete Swatch

    func deleteSwatch(_ swatch: Swatch) async {
        do {
            try await SwatchService.shared.deleteSwatch(id: swatch.id)

            // Remove from local list
            swatches.removeAll { $0.id == swatch.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Tab Change

    func switchTab(to tab: SwatchTab) async {
        guard tab != selectedTab else { return }
        selectedTab = tab
        await loadSwatches()
    }

    // MARK: - Refresh

    func refresh() async {
        await loadSwatches()
    }
}
