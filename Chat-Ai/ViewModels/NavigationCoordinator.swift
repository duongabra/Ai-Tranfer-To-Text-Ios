//
//  NavigationCoordinator.swift
//  Chat-Ai
//
//  Coordinator để quản lý navigation state (iOS 15+ compatible)
//

import SwiftUI

@MainActor
class NavigationCoordinator: ObservableObject {
    // iOS 16+ navigation path (dùng Any để tránh lỗi @available trên stored property)
    private var _navigationPathStorage: Any? = nil
    
    // iOS 15 navigation state
    @Published var currentDestination: NavigationDestination?
    @Published var showingPaywall = false
    
    // Helper để access navigationPath với type safety cho iOS 16+
    @available(iOS 16.0, *)
    private func getNavigationPath() -> NavigationPath {
        if let path = _navigationPathStorage as? NavigationPath {
            return path
        }
        let newPath = NavigationPath()
        _navigationPathStorage = newPath
        return newPath
    }
    
    @available(iOS 16.0, *)
    private func setNavigationPath(_ path: NavigationPath) {
        _navigationPathStorage = path
        // Trigger update để SwiftUI biết có thay đổi
        objectWillChange.send()
    }
    
    // Public accessor cho iOS 16+
    @available(iOS 16.0, *)
    var navigationPath: NavigationPath {
        get { getNavigationPath() }
        set { setNavigationPath(newValue) }
    }
    
    @available(iOS 16.0, *)
    var navigationPathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.navigationPath },
            set: { self.navigationPath = $0 }
        )
    }
    
    enum NavigationDestination: Identifiable {
        case conversation(Conversation)
        case paywall
        
        var id: String {
            switch self {
            case .conversation(let conv):
                return "conversation_\(conv.id)"
            case .paywall:
                return "paywall"
            }
        }
    }
    
    func navigateToConversation(_ conversation: Conversation) {
        if #available(iOS 16.0, *) {
            var newPath = NavigationPath()
            newPath.append(conversation)
            navigationPath = newPath
        } else {
            currentDestination = .conversation(conversation)
        }
    }
    
    func navigateToPaywall() {
        if #available(iOS 16.0, *) {
            navigationPath.append(PaywallDestination())
        } else {
            showingPaywall = true
        }
    }
    
    func navigateToHome() {
        if #available(iOS 16.0, *) {
            let count = navigationPath.count
            if count > 0 {
                navigationPath.removeLast(count)
            }
        } else {
            currentDestination = nil
            showingPaywall = false
        }
    }
    
    func replaceConversation(_ conversation: Conversation) {
        navigateToConversation(conversation)
    }
}

