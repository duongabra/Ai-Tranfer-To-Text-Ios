//
//  Conversation.swift
//  Chat-Ai
//
//  Model for a chat conversation (used by ConversationListDrawer).
//

import Foundation

struct Conversation: Identifiable {
    let id: UUID
    var title: String
    let updatedAt: Date

    init(id: UUID = UUID(), title: String = "Chat", updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
    }
}
