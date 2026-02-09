//
//  HomeGraphicView.swift
//  Chat-Ai
//
//  Graphic decoration ở cuối trang Home
//

import SwiftUI

struct HomeGraphicView: View {
    var body: some View {
        Image("Frame 4")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    HomeGraphicView()
        .background(Color.backgroundCream)
}

