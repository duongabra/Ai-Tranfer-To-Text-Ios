//
//  SwatchUploadView.swift
//  Chat-Ai
//
//  Step 1: state 1 = chọn 2 ảnh son (upload/take), state 2 = xác nhận (Figma 55341-504)
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - PHPicker: chọn đúng 2 ảnh (upload)
struct PHPickerView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        init(_ parent: PHPickerView) {
            self.parent = parent
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { parent.onComplete([]); return }
            let providers = results.map(\.itemProvider)
            var images: [UIImage?] = Array(repeating: nil, count: providers.count)
            let group = DispatchGroup()
            for (index, provider) in providers.enumerated() {
                group.enter()
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { obj, _ in
                        if let img = obj as? UIImage {
                            images[index] = img
                        }
                        group.leave()
                    }
                } else { group.leave() }
            }
            group.notify(queue: .main) {
                self.parent.onComplete(images.compactMap { $0 })
            }
        }
    }
}

// MARK: - Image Picker (camera / single photo, iOS 15 compatible)
struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case photoLibrary
        case camera
    }
    let source: Source
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        switch source {
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        case .camera:
            picker.sourceType = .camera
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Swatch Upload View
struct SwatchUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    // Step 1: state 1 = chọn ảnh, state 2 = xác nhận, state 3 = analyzing (progress mock 10s)
    @State private var lipstickImage1: UIImage?
    @State private var lipstickImage2: UIImage?
    @State private var lipstickImageURL1: String?
    @State private var lipstickImageURL2: String?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showNeedTwoImagesAlert = false
    @State private var pickingForSlot: Int = 1
    @State private var step1ShowingState3 = false
    @State private var step1ShowingState4 = false
    @State private var state3UploadError: String?
    @State private var showUploadErrorAlert = false

    // State 3: mock progress 10s → khi 100% chuyển State 4 (Lipstick identified)
    @State private var mockProgressTotal: CGFloat = 0
    @State private var mockTimer: Timer?
    private let mockDuration: TimeInterval = 2

    private var step1State2: Bool {
        lipstickImage1 != nil && lipstickImage2 != nil
    }

    private let progressCornerRadius: CGFloat = 20
    private let progressFillColor = Color(hex: "030712")
    private let progressEmptyColor = Color(hex: "F9FAFB")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // State 3 không có header; State 4 có header (Figma 55350-629)
                if step1ShowingState4 || !step1ShowingState3 {
                    modalHeader
                }

                if step1ShowingState4 {
                    step1State4Content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            if step1ShowingState3 {
                                step1State3Content
                            } else if step1State2 {
                                step1State2Content
                            } else {
                                step1State1Content
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.horizontal, step1ShowingState4 ? 0 : 16)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(source: .camera, image: bindingForSlot(pickingForSlot))
        }
        .sheet(isPresented: $showingLibrary) {
            PHPickerView(selectionLimit: 2) { images in
                if images.count == 2 {
                    lipstickImage1 = images[0]
                    lipstickImage2 = images[1]
                } else if images.count == 1 {
                    showNeedTwoImagesAlert = true
                }
            }
        }
        .alert("Please select 2 images", isPresented: $showNeedTwoImagesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need to select 2 lipstick photos to continue.")
        }
        .alert("Upload failed", isPresented: $showUploadErrorAlert) {
            Button("OK", role: .cancel) {
                state3UploadError = nil
            }
        } message: {
            Text(state3UploadError ?? "")
        }
        .onDisappear {
            mockTimer?.invalidate()
            mockTimer = nil
        }
    }

    private func nextEmptySlot() -> Int {
        lipstickImage1 == nil ? 1 : 2
    }

    private func bindingForSlot(_ slot: Int) -> Binding<UIImage?> {
        if slot == 1 { return $lipstickImage1 }
        return $lipstickImage2
    }

    // MARK: - Modal Header (progress + X)
    private var modalHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            // Left: back khi state 2 (retake) hoặc state 4 (quay lại confirm)
            if (step1State2 && !step1ShowingState3) || step1ShowingState4 {
                Button(action: {
                    if step1ShowingState4 {
                        step1ShowingState4 = false
                        step1ShowingState3 = false
                    } else {
                        retakePhotos()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "4A5565"))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            // Progress: 3 segments (Step 1 = first filled)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressFillColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

            // X close (Figma 55353-746: tonal, icon SVG 16x16 #4A5565)
            Button(action: { dismiss() }) {
                Image("close_line_swatch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F9FAFB"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, step1ShowingState4 ? 4 : 16)
        .padding(.bottom, step1ShowingState4 ? 4 : 8)
    }

    /// Kích thước ảnh trong ô: ảnh 1 = 93x131, ảnh 2 = 55x125 (aspect 11/25)
    private let imageSize1: (w: CGFloat, h: CGFloat) = (93, 131)
    private let imageSize2: (w: CGFloat, h: CGFloat) = (55, 125)

    // MARK: - Step 1 State 1 (chọn 2 ảnh: Take / Upload)
    private var step1State1Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take 2 lipstick photos ")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Good example")
                    .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(Color(hex: "6A7282"))

                // Ô vuông fit màn hình: (width - 16*2 - 12) / 2; ảnh trong đúng 93x131 và 55x125
                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let squareSize = (availableWidth - 12) / 2
                    HStack(alignment: .top, spacing: 12) {
                        slotView(
                            image: lipstickImage1,
                            sampleImageName: "LipstickSampleBox",
                            caption: "Full tube - logo visible",
                            squareSize: squareSize,
                            imageSize: imageSize1
                        )
                        slotView(
                            image: lipstickImage2,
                            sampleImageName: "LipstickSampleTube",
                            caption: "Bottom label or tube text",
                            squareSize: squareSize,
                            imageSize: imageSize2
                        )
                    }
                    .frame(width: availableWidth, height: squareSize + 12 + 24)
                }
                .frame(height: 220)
            }
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                Button(action: {
                    pickingForSlot = nextEmptySlot()
                    showingCamera = true
                }) {
                    HStack(spacing: 8) {
                        Image("camera_2_ai_swatch")
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: "F9FAFB"))
                            .frame(width: 20, height: 20)
                        Text("Take a photo")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    }
                    .foregroundColor(Color(hex: "F9FAFB"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .padding(.trailing, 20)
                    .background(Color(hex: "030712"))
                    .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showingLibrary = true }) {
                    HStack(spacing: 8) {
                        Image("upload_2_swatch")
                            .renderingMode(.template)
                            .foregroundColor(Color(hex: "030712"))
                            .frame(width: 20, height: 20)
                        Text("Upload a photo")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    }
                    .foregroundColor(Color(hex: "101828"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9999)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    /// Ô vuông xám (#F3F4F6) fit màn hình; ảnh bên trong đúng kích thước (93x131 hoặc 55x125)
    private func slotView(image: UIImage?, sampleImageName: String, caption: String, squareSize: CGFloat, imageSize: (w: CGFloat, h: CGFloat)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Color(hex: "F3F4F6")
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(12)

                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(sampleImageName)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: imageSize.w, height: imageSize.h)
            }
            .frame(width: squareSize, height: squareSize)
            .clipped()
            .cornerRadius(12)

            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "30A159"))
                Text(caption)
                    .font(.custom("Overused Grotesk", size: 12).weight(.regular))
                    .foregroundColor(Color(hex: "364153"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1 State 2 (xác nhận 2 ảnh — Figma 55341-504)
    private var step1State2Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm your photos")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            // 2 ảnh đã chọn — gap 4 như Figma
            HStack(alignment: .top, spacing: 4) {
                if let img1 = lipstickImage1 {
                    Image(uiImage: img1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                }
                if let img2 = lipstickImage2 {
                    Image(uiImage: img2)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Button(action: { confirmPhotos() }) {
                    Text("Yes, use these photos")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { retakePhotos() }) {
                    Text("Retake photos")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "101828"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private func retakePhotos() {
        lipstickImage1 = nil
        lipstickImage2 = nil
        lipstickImageURL1 = nil
        lipstickImageURL2 = nil
        step1ShowingState3 = false
        step1ShowingState4 = false
        mockTimer?.invalidate()
        mockProgressTotal = 0
    }

    private func confirmPhotos() {
        guard let img1 = lipstickImage1, let img2 = lipstickImage2,
              let userId = authViewModel.currentUser?.id else {
            return
        }
        let data1 = img1.jpegData(compressionQuality: 0.85) ?? Data()
        let data2 = img2.jpegData(compressionQuality: 0.85) ?? Data()

        Task {
            do {
                let url1 = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data1)
                let url2 = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data2)
                await MainActor.run {
                    lipstickImageURL1 = url1
                    lipstickImageURL2 = url2
                    step1ShowingState3 = true
                    startMockProgressTimer()
                }
            } catch {
                await MainActor.run {
                    state3UploadError = error.localizedDescription
                    showUploadErrorAlert = true
                }
            }
        }
    }

    private func startMockProgressTimer() {
        mockProgressTotal = 0
        mockTimer?.invalidate()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            mockProgressTotal += CGFloat(0.05 / mockDuration) * 100
            if mockProgressTotal >= 100 {
                mockTimer?.invalidate()
                mockTimer = nil
                mockProgressTotal = 100
                step1ShowingState4 = true
            }
        }
        RunLoop.main.add(mockTimer!, forMode: .common)
    }

    // MARK: - Step 1 State 3 (analyzing — Figma 55350-628: 2 ảnh + progress tròn 64pt + title + 3 thanh pill)
    private var step1State3Content: some View {
        VStack(alignment: .center, spacing: 24) {
            // 2 ảnh đã up (preview từ URL hoặc UIImage)
            HStack(alignment: .top, spacing: 4) {
                state3ImagePreview(url: lipstickImageURL1, image: lipstickImage1)
                state3ImagePreview(url: lipstickImageURL2, image: lipstickImage2)
            }
            .frame(maxWidth: .infinity)

            // Block progress theo Figma 55353-973: 1 vòng ring ngoài — track nhạt + progress đậm, % giữa
            VStack(alignment: .center, spacing: 24) {
                ZStack {
                    // Vòng tròn nền (track) — stroke nhạt
                    Circle()
                        .stroke(Color(hex: "F9FAFB"), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    // Vòng progress — stroke #030712, trim từ 12h quay theo chiều kim đồng hồ
                    Circle()
                        .trim(from: 0, to: CGFloat(mockProgressTotal / 100))
                        .stroke(Color(hex: "030712"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(mockProgressTotal))%")
                        .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(Color(hex: "6A7282"))
                }
                .frame(width: 64, height: 64)

                Text("Finding your lipstick...")
                    .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // 3 rules: mỗi dòng label + % (space-between), thanh pill height 8, track #F3F4F6, border active #101828 / inactive #99A1AF
            VStack(alignment: .leading, spacing: 24) {
                state3ProgressRow(
                    label: "Detecting the brand logo",
                    progress: min(1, mockProgressTotal / 33.33),
                    percent: min(33, Int(mockProgressTotal)),
                    isActive: mockProgressTotal > 0
                )
                state3ProgressRow(
                    label: "Identifying the product line",
                    progress: min(1, max(0, (mockProgressTotal - 33.33) / 33.33)),
                    percent: min(33, max(0, Int(mockProgressTotal - 33.33))),
                    isActive: mockProgressTotal > 33.33
                )
                state3ProgressRow(
                    label: "Reading shade name",
                    progress: min(1, max(0, (mockProgressTotal - 66.66) / 33.34)),
                    percent: min(34, max(0, Int(mockProgressTotal - 66.66))),
                    isActive: mockProgressTotal > 66.66
                )
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Step 1 State 4: base State 3, bỏ progress; thêm overlay info absolute từ dưới lên
    private var step1State4Content: some View {
        GeometryReader { geo in
            // Giống State 3: 2 ảnh (state3ImagePreview) + overlay tối; không có progress
            VStack(alignment: .center, spacing: 24) {
                ZStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 4) {
                        state3ImagePreview(url: lipstickImageURL1, image: lipstickImage1)
                        state3ImagePreview(url: lipstickImageURL2, image: lipstickImage2)
                    }
                    .frame(maxWidth: .infinity)

                    Color.black.opacity(0.3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                state4InfoPanelOverlay(safeBottom: geo.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Cục info = overlay absolute từ dưới lên (thay cho block progress của State 3)
    private func state4InfoPanelOverlay(safeBottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Color.white
                    .frame(maxWidth: .infinity, maxHeight: 375)
                    .ignoresSafeArea(edges: .bottom)
                state4CardContent
            }
            .frame(maxWidth: .infinity)
            .frame(height: 375)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 32, x: 0, y: 0)
        }
    }

    private var state4CardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image("sparkles_ai_swatch")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(hex: "101828"))
                    Text("Lipstick identified")
                        .font(.custom("Overused Grotesk", size: 20).weight(.regular))
                        .foregroundColor(Color(hex: "101828"))
                }
                Text("Please confirm the details before we generate your swatch")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
            }

            VStack(spacing: 8) {
                state4InfoRow(label: "Brand", value: "MAC")
                state4InfoRow(label: "Product", value: "Silky Matte Lipstick")
                state4InfoRow(label: "Shade", value: "646 Marrakesh")
            }

            VStack(spacing: 12) {
                Button(action: { /* Add face photo - TODO */ }) {
                    Text("Add face photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { /* Edit details - TODO */ }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "101828"))
                        Text("Edit details")
                            .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                            .foregroundColor(Color(hex: "101828"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9999)
                            .stroke(Color(hex: "101828"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func state4InfoRow(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "6A7282"))
            Spacer()
            Text(value)
                .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "101828"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(12)
    }

    private func state3ImagePreview(url: String?, image: UIImage?) -> some View {
        Group {
            if let urlString = url, let u = URL(string: urlString) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        imagePreviewFallback(image: image)
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, maxHeight: 120)
                    @unknown default:
                        imagePreviewFallback(image: image)
                    }
                }
            } else if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Color(hex: "F3F4F6")
                    .frame(minHeight: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
    }

    private func imagePreviewFallback(image: UIImage?) -> some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Color(hex: "F3F4F6").frame(minHeight: 80)
            }
        }
    }

    private func state3ProgressRow(label: String, progress: CGFloat, percent: Int, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row: label + percent (space-between), body-sm; active #101828, inactive #6A7282
            HStack {
                Text(label)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
            }

            // Progress bar: height 8, track #F3F4F6, border 1px (active #101828 / inactive #99A1AF), pill radius
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "F3F4F6"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(isActive ? Color(hex: "101828") : Color(hex: "99A1AF"), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "030712"))
                        .frame(width: max(0, geo.size.width * progress))
                        .opacity(progress > 0 ? 1 : 0)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    NavigationView {
        SwatchUploadView()
            .environmentObject(AuthViewModel())
    }
}
