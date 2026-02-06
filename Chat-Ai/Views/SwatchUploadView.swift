//
//  SwatchUploadView.swift
//  Chat-Ai
//
//  Container: Step 1 (4 states) → Step 2. Mỗi step trong file riêng để dễ debug.
//

import SwiftUI

struct SwatchUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    /// 1 = Step 1 (lipstick photos → identified), 2 = Step 2 (face photo / swatch)
    @State private var currentStep: Int = 1

    var body: some View {
        Group {
            if currentStep == 1 {
                SwatchStep1View(onProceedToStep2: {
                    currentStep = 2
                })
            } else {
                SwatchStep2View()
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationView {
        SwatchUploadView()
            .environmentObject(AuthViewModel())
    }
}
