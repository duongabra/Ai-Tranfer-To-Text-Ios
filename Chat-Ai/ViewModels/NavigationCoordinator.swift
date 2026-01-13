//
//  NavigationCoordinator.swift
//  Chat-Ai
//
//  Coordinator để quản lý navigation state
//

import SwiftUI

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var pendingConversation: Conversation?
    
    func navigateToConversation(_ conversation: Conversation) {
        // Replace navigation path với conversation mới
        var newPath = NavigationPath()
        newPath.append(conversation)
        navigationPath = newPath
        print("🔄 NavigationCoordinator: Navigated to conversation, count: \(navigationPath.count)")
    }
    
    func navigateToHome() {
        // Clear navigation path
        let count = navigationPath.count
        if count > 0 {
            navigationPath.removeLast(count)
        }
        print("🔄 NavigationCoordinator: Navigated to home, count: \(navigationPath.count)")
    }
    
    func replaceConversation(_ conversation: Conversation) {
        // Replace conversation trong navigation stack
        var newPath = NavigationPath()
        newPath.append(conversation)
        navigationPath = newPath
        print("🔄 NavigationCoordinator: Replaced conversation, count: \(navigationPath.count)")
    }
}

