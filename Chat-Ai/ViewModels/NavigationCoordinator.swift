//
//  NavigationCoordinator.swift
//  Chat-Ai
//
//  Coordinates navigation (e.g. to Paywall) from Settings and drawer.
//

import Foundation
import SwiftUI

public final class NavigationCoordinator: ObservableObject {
    @Published var showPaywall = false

    public init() {}

    public func navigateToPaywall() {
        showPaywall = true
    }
}
