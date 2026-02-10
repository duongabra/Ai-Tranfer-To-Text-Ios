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

    /// Gọi khi user bấm X để đóng màn Swatch → ẩn tab bar và chuyển về tab khác (ContentView set selectedTab).
    var onClose: (() -> Void)? = nil

    /// 1 = Step 1 (lipstick photos → identified), 2 = Step 2 (face photo / swatch)
    @State private var currentStep: Int = 1

    /// Dữ liệu từ Step 1 truyền sang Step 2 (2 URL son + brand/product/shade có thể đã chỉnh)
    @State private var step1LipstickURL1: String = ""
    @State private var step1LipstickURL2: String = ""
    @State private var step1LipstickBrand: String = ""
    @State private var step1LipstickProduct: String = ""
    @State private var step1LipstickShade: String = ""

    var body: some View {
        Group {
            if currentStep == 1 {
                SwatchStep1View(
                    onProceedToStep2: { url1, url2, brand, product, shade in
                        step1LipstickURL1 = url1
                        step1LipstickURL2 = url2
                        step1LipstickBrand = brand
                        step1LipstickProduct = product
                        step1LipstickShade = shade
                        currentStep = 2
                    },
                    onClose: onClose ?? { dismiss() }
                )
            } else {
                SwatchStep2View(
                    lipstickURL1: step1LipstickURL1,
                    lipstickURL2: step1LipstickURL2,
                    lipstickBrand: step1LipstickBrand,
                    lipstickProduct: step1LipstickProduct,
                    lipstickShade: step1LipstickShade
                )
            }
        }
        .navigationBarHidden(true)
        .preference(key: HideTabBarKey.self, value: true)
    }
}

#Preview {
    NavigationView {
        SwatchUploadView()
            .environmentObject(AuthViewModel())
    }
}
