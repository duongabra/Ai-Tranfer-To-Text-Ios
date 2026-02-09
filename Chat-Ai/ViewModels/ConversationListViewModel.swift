//
//  ConversationListViewModel.swift
//  Chat-Ai
//
//  ViewModel for conversation list (drawer). Currently holds empty list;
//  can be extended when conversation/message backend is available.
//

import Foundation
import Combine

final class ConversationListViewModel: ObservableObject {
    static let shared = ConversationListViewModel()

    @Published var conversations: [Conversation] = []
    @Published var isLoading = false

    private init() {}

    func loadConversations(forceRefresh: Bool = false) async {
        await MainActor.run { isLoading = true }
        // Stub: no conversation backend in current Supabase setup.
        await MainActor.run {
            self.conversations = []
        }
        await MainActor.run { isLoading = false }
    }
}
