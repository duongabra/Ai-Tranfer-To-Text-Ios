//
//  SwatchStep2View.swift
//  Chat-Ai
//
//  Step 2: Take/upload face photo — State 1 (choose), State 2 (local preview), State 3 (Figma 55367-1481, applying)
//  Upload ảnh lên Storage chỉ khi bấm "Yes, use this photo".
//

import SwiftUI

struct SwatchStep2View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    /// Từ Step 1: 2 URL ảnh son + brand/product/shade (có thể đã chỉnh)
    var lipstickURL1: String = ""
    var lipstickURL2: String = ""
    var lipstickBrand: String = ""
    var lipstickProduct: String = ""
    var lipstickShade: String = ""

    private let progressCornerRadius: CGFloat = 20
    private let progressFillColor = Color(hex: "030712")
    private let progressEmptyColor = Color(hex: "F9FAFB")

    @State private var faceImage: UIImage?
    @State private var faceImageURL: String?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var isUploadingFace = false
    @State private var showFaceUploadErrorAlert = false
    @State private var faceUploadErrorMessage: String?
    @State private var step2ShowingState3 = false
    @State private var step2ShowingState4 = false
    @State private var step2MockProgress: CGFloat = 0
    private let step2ProgressDuration: TimeInterval = 100
    @State private var step3ApiDone = false
    @State private var step3TimerDone = false
    @State private var step2SwatchResult: SwatchDetailResponse? = nil
    @State private var step2CreateSwatchError: String? = nil
    @State private var step2ProgressTimer: Timer?
    @State private var step2State4LikeDislike: Bool? = nil // true = like, false = dislike
    @State private var step2BeforeAfterSliderPosition: CGFloat = 0.5 // 0 = all After, 1 = all Before
    @State private var step2SliderDragStartPosition: CGFloat? = nil

    /// Validate face API: loading, result (is_valid + checks + issues), URL from upload (reuse for State 3)
    @State private var step2ValidationLoading = false
    @State private var step2ValidationResult: ValidateFaceResponse? = nil
    @State private var step2FaceImageURLFromValidation: String? = nil
    @State private var step2ValidationError: String? = nil

    /// Lipstick info hiển thị ở Step 4: từ API GET (step2SwatchResult) hoặc từ Step 1 (lipstickBrand/Product/Shade)
    private var step2LipstickBrand: String { step2SwatchResult?.brand ?? lipstickBrand }
    private var step2LipstickProduct: String { step2SwatchResult?.product ?? lipstickProduct }
    private var step2LipstickShade: String { step2SwatchResult?.shade ?? lipstickShade }

    private var isState2: Bool { faceImage != nil && !step2ShowingState3 && !step2ShowingState4 }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                if step2ShowingState4 {
                    step2State4Header
                } else if !step2ShowingState3 {
                    step2ModalHeader
                }
                ScrollView {
                    if step2ShowingState4 {
                        step2State4Content
                    } else if step2ShowingState3 {
                        step2State3Content
                    } else if isState2 {
                        step2State2Content
                    } else {
                        step2State1Content
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(source: .camera, image: $faceImage, useFrontCamera: true)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingLibrary) {
            ImagePicker(source: .photoLibrary, image: $faceImage)
                .ignoresSafeArea()
        }
        .alert("Upload failed", isPresented: $showFaceUploadErrorAlert) {
            Button("OK", role: .cancel) {
                isUploadingFace = false
            }
        } message: {
            Text(faceUploadErrorMessage ?? "Could not upload face photo.")
        }
        .onDisappear {
            step2ProgressTimer?.invalidate()
            step2ProgressTimer = nil
        }
    }

    /// Upload face → validate-face API. Khi vào State 2 có ảnh thì chạy; nếu is_valid enable "Yes", không thì disable + hiện issues.
    private func runUploadAndValidateFace() {
        guard let img = faceImage,
              let userId = authViewModel.currentUser?.id,
              let data = img.jpegData(compressionQuality: 0.85) else { return }
        step2ValidationLoading = true
        step2ValidationError = nil
        step2ValidationResult = nil
        step2FaceImageURLFromValidation = nil
        Task {
            do {
                let url = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data)
                let result = try await SwatchAPIService.shared.validateFace(imageURL: url)
                await MainActor.run {
                    step2FaceImageURLFromValidation = url
                    step2ValidationResult = result
                    step2ValidationLoading = false
                }
            } catch {
                await MainActor.run {
                    step2ValidationError = error.localizedDescription
                    step2ValidationLoading = false
                }
            }
        }
    }

    private func uploadFaceImageThenGoToState3(_ image: UIImage) {
        guard let userId = authViewModel.currentUser?.id,
              let data = image.jpegData(compressionQuality: 0.85) else {
            faceUploadErrorMessage = "Missing user or invalid image."
            showFaceUploadErrorAlert = true
            return
        }
        isUploadingFace = true
        Task {
            do {
                let url = try await SupabaseService.shared.uploadImageToStorage(userId: userId, imageData: data)
                await MainActor.run {
                    faceImageURL = url
                    isUploadingFace = false
                    step2ShowingState3 = true
                    step3ApiDone = false
                    step3TimerDone = false
                    startCreateSwatchAndPoll()
                }
            } catch {
                await MainActor.run {
                    isUploadingFace = false
                    faceUploadErrorMessage = error.localizedDescription
                    showFaceUploadErrorAlert = true
                }
            }
        }
    }

    /// POST create swatch → lưu id → poll GET mỗi 3s. Progress 0→99% trong 100s; khi API xong nhảy 100% rồi sang State 4.
    private func startCreateSwatchAndPoll() {
        guard let barefaceUrl = step2FaceImageURLFromValidation else { return }
        let lipstickUrls = [lipstickURL1, lipstickURL2].filter { !$0.isEmpty }
        guard lipstickUrls.count >= 2 else {
            step2CreateSwatchError = "Need 2 lipstick image URLs."
            showFaceUploadErrorAlert = true
            faceUploadErrorMessage = step2CreateSwatchError
            return
        }
        step2MockProgress = 0
        step2SwatchResult = nil
        step2CreateSwatchError = nil
        step2ProgressTimer?.invalidate()

        Task {
            do {
                let createResponse = try await SwatchAPIService.shared.createSwatch(
                    barefaceUrl: barefaceUrl,
                    lipstickUrls: lipstickUrls,
                    brand: lipstickBrand,
                    product: lipstickProduct,
                    shade: lipstickShade
                )
                guard let swatchId = createResponse.id else {
                    await MainActor.run {
                        step2ShowingState3 = false
                        step2CreateSwatchError = "No swatch id in response."
                        showFaceUploadErrorAlert = true
                        faceUploadErrorMessage = step2CreateSwatchError
                    }
                    return
                }
                await MainActor.run { startStep2ProgressTimer100s() }
                // Poll every 3s until status completed or swatch_url present
                var pollCount = 0
                while true {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    pollCount += 1
                    let detail = try await SwatchAPIService.shared.getSwatch(swatchId: swatchId)
                    print("[SwatchStep2] Poll #\(pollCount) id: \(swatchId) GET /api/mobile/swatches/\(swatchId) — status: \(detail.status ?? "nil"), swatch_url: \(detail.swatchUrl ?? "nil")")
                    let isDone = detail.status?.lowercased() == "completed" || detail.status?.lowercased() == "complete" || (detail.swatchUrl != nil && !(detail.swatchUrl?.isEmpty ?? true))
                    if isDone {
                        await MainActor.run {
                            step2SwatchResult = detail
                            step3ApiDone = true
                            if step3TimerDone {
                                step2MockProgress = 100
                                step2ShowingState4 = true
                                step2ProgressTimer?.invalidate()
                            } else {
                                startStep2RampTo100AndProceed()
                            }
                        }
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    step2ShowingState3 = false
                    step2CreateSwatchError = error.localizedDescription
                    showFaceUploadErrorAlert = true
                    faceUploadErrorMessage = step2CreateSwatchError
                }
            }
        }
    }

    private func startStep2ProgressTimer100s() {
        step2MockProgress = 0
        let duration: TimeInterval = 100
        step2ProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            step2MockProgress += CGFloat(0.05 / duration) * 99
            if step2MockProgress >= 99 {
                step2ProgressTimer?.invalidate()
                step2ProgressTimer = nil
                step2MockProgress = 99
                step3TimerDone = true
                if step3ApiDone {
                    step2MockProgress = 100
                    step2ShowingState4 = true
                }
            }
        }
        RunLoop.main.add(step2ProgressTimer!, forMode: .common)
    }

    private func startStep2RampTo100AndProceed() {
        step2ProgressTimer?.invalidate()
        let startProgress = step2MockProgress
        let startTime = Date()
        step2ProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= 1 {
                step2MockProgress = 100
                step2ProgressTimer?.invalidate()
                step2ProgressTimer = nil
                step2ShowingState4 = true
                return
            }
            step2MockProgress = startProgress + (100 - startProgress) * CGFloat(elapsed / 1)
        }
        RunLoop.main.add(step2ProgressTimer!, forMode: .common)
    }

    private func startStep2ProgressTimer() {
        step2MockProgress = 0
        let interval: TimeInterval = 0.05
        let increment = 100 * interval / step2ProgressDuration
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                step2MockProgress += increment
                if step2MockProgress >= 100 {
                    timer.invalidate()
                    step2ShowingState4 = true
                }
            }
        }
        .fire()
    }

    // MARK: - Header (state 1: back invisible; state 2/3: back visible)
    private var step2ModalHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            if isState2 || step2ShowingState3 {
                Button(action: {
                    if step2ShowingState3 {
                        step2ShowingState3 = false
                    } else {
                        faceImage = nil
                        faceImageURL = nil
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

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressFillColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressFillColor)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: progressCornerRadius)
                    .fill(progressEmptyColor)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

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
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - State 4 header (home left, close right)
    private var step2State4Header: some View {
        HStack(alignment: .center, spacing: 24) {
            Button(action: { dismiss() }) {
                Image("step2_home_swatch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 13)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F9FAFB"))
                    .cornerRadius(9999)
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
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
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - State 4: Result before/after — bareface_url (Before), swatch_url (After), score, ai_description từ GET swatch
    private var step2State4BeforeURL: URL? { (step2SwatchResult?.barefaceUrl).flatMap { URL(string: $0) } }
    private var step2State4AfterURL: URL? { (step2SwatchResult?.swatchUrl).flatMap { URL(string: $0) } }

    private var step2State4Content: some View {
        VStack(alignment: .center, spacing: 20) {
            // Before / After swipe (mock 2 images, kéo sang 2 bên)
            step2State4BeforeAfterBlock
            // Action buttons: Reset, Download, Heart (order per design)
            HStack(spacing: 16) {
                Button(action: {
                    step2ShowingState4 = false
                    step2ShowingState3 = true
                    step2MockProgress = 0
                    step3ApiDone = false
                    step3TimerDone = false
                    step2SwatchResult = nil
                    startCreateSwatchAndPoll()
                }) {
                    Image("step2_reset_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 16)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(Circle().stroke(Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { /* TODO: download result image */ }) {
                    Image("step2_down_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(hex: "F9FAFB"))
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { /* TODO: favorite */ }) {
                    Image("step2_heart_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 15)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(Circle().stroke(Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
            }
            // Score card — score + ai_description từ GET swatch
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: min(1, (step2SwatchResult?.score ?? 0) / 10))
                        .stroke(Color(hex: "30A159"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text(step2SwatchResult?.score != nil ? "\(Int(step2SwatchResult!.score!))/10" : "—/10")
                        .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                        .foregroundColor(Color(hex: "030712"))
                }
                .frame(width: 56, height: 56)
                Text(step2SwatchResult?.aiDescription ?? "Generating your swatch...")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "F9FAFB"))
            .cornerRadius(16)
            // Lipstick info block (giống Step 1 State 4)
            VStack(spacing: 8) {
                step2LipstickInfoRow(label: "Brand", value: step2LipstickBrand)
                step2LipstickInfoRow(label: "Product", value: step2LipstickProduct)
                step2LipstickInfoRow(label: "Shade", value: step2LipstickShade)
            }
            // Like or dislike — centered, 12px gap between text and each button
            HStack(alignment: .center, spacing: 12) {
                Text("Do you like this swatch?")
                    .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "101828"))
                Button(action: { step2State4LikeDislike = true }) {
                    Image("step2_like_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(step2State4LikeDislike == true ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                        .frame(width: 13, height: 13)
                        .frame(width: 28, height: 28)
                        .background(step2State4LikeDislike == true ? Color(hex: "030712") : Color.white)
                        .overlay(Circle().stroke(step2State4LikeDislike == true ? Color.clear : Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { step2State4LikeDislike = false }) {
                    Image("step2_dislike_swatch")
                        .renderingMode(Image.TemplateRenderingMode.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(step2State4LikeDislike == false ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                        .frame(width: 16, height: 16)
                        .frame(width: 28, height: 28)
                        .background(step2State4LikeDislike == false ? Color(hex: "030712") : Color.white)
                        .overlay(Circle().stroke(step2State4LikeDislike == false ? Color.clear : Color(hex: "030712"), lineWidth: 1))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private static let step2BeforeAfterAspectRatio: CGFloat = 335 / 446

    /// Một dòng hiển thị thông tin son (Brand/Product/Shade), style giống Step 1.
    private func step2LipstickInfoRow(label: String, value: String) -> some View {
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

    private var step2State4BeforeAfterBlock: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let dividerX = width * step2BeforeAfterSliderPosition
            let beforeURL = step2State4BeforeURL
            let afterURL = step2State4AfterURL
            ZStack(alignment: .leading) {
                // After (right side) — swatch_url
                Group {
                    if let url = afterURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure: Color(hex: "F3F4F6")
                            default: ProgressView()
                            }
                        }
                    } else {
                        Color(hex: "F3F4F6")
                    }
                }
                .frame(width: width, height: height)
                .clipped()
                // Before (left side) — bareface_url
                Group {
                    if let url = beforeURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure: Color(hex: "F3F4F6")
                            default: ProgressView()
                            }
                        }
                    } else {
                        Color(hex: "F3F4F6")
                    }
                }
                .frame(width: width, height: height)
                .frame(width: dividerX, height: height, alignment: .leading)
                .clipped()
                // Badges
                Text("Before")
                    .font(.custom("Overused Grotesk", size: 12).weight(.medium))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Text("After")
                    .font(.custom("Overused Grotesk", size: 12).weight(.medium))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                // Divider line (white) + handle
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: dividerX - 1)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                    Spacer()
                }
                .frame(height: height)
                .overlay(alignment: .leading) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                        Image("step2_slider_handle_swatch")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 8)
                    }
                    .offset(x: dividerX - 16)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if step2SliderDragStartPosition == nil {
                                step2SliderDragStartPosition = step2BeforeAfterSliderPosition
                            }
                            let start = step2SliderDragStartPosition ?? 0.5
                            step2BeforeAfterSliderPosition = min(1, max(0, start + value.translation.width / width))
                        }
                        .onEnded { _ in
                            step2SliderDragStartPosition = nil
                        }
                )
            }
            .frame(width: width, height: height)
            .cornerRadius(16)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.step2BeforeAfterAspectRatio, contentMode: .fit)
    }

    // MARK: - State 1: Take a photo of your face (take / upload)
    private var step2State1Content: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Take a photo of your face")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            facePhotoArea

            VStack(alignment: .leading, spacing: 8) {
                ruleRow(icon: "checkmark.circle.fill", text: "Center your face within the oval area")
                ruleRow(icon: "checkmark.circle.fill", text: "Maintain a neutral expression")
                ruleRow(icon: "checkmark.circle.fill", text: "Ensure good lighting")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: { showingCamera = true }) {
                    HStack(spacing: 8) {
                        Image("camera_2_ai_swatch")
                            .renderingMode(Image.TemplateRenderingMode.template)
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
                            .renderingMode(Image.TemplateRenderingMode.template)
                            .foregroundColor(Color(hex: "101828"))
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
                            .stroke(Color(hex: "101828"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - State 2: Your photo looks good (Figma 55367-636) — validate face → enable/disable Yes
    private var step2State2Content: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("Your photo looks good")
                .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                .foregroundColor(Color(hex: "101828"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Group {
                if let img = faceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 165)
                        .overlay {
                            if isUploadingFace || step2ValidationLoading {
                                Color.black.opacity(0.3)
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Text(step2ValidationLoading ? "Checking photo..." : "Uploading...")
                                        .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Validation: hiện checks từ API (✓/✗) hoặc rules mặc định khi đang loading
            VStack(alignment: .leading, spacing: 8) {
                if let result = step2ValidationResult, let checks = result.checks {
                    step2ValidationCheckRow(ok: checks.faceCentered ?? false, text: "Face centered")
                    step2ValidationCheckRow(ok: checks.goodLighting ?? false, text: "Good lighting")
                    step2ValidationCheckRow(ok: checks.faceNotCovered ?? false, text: "Face not covered")
                    step2ValidationCheckRow(ok: checks.neutralExpression ?? false, text: "Neutral expression")
                    if let issues = result.issues, !issues.isEmpty {
                        ForEach(issues, id: \.self) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "DC2626"))
                                Text(issue)
                                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                                    .foregroundColor(Color(hex: "6A7282"))
                            }
                        }
                    }
                } else {
                    ruleRow(icon: "checkmark.circle.fill", text: "Face centered")
                    ruleRow(icon: "checkmark.circle.fill", text: "Good lighting")
                    ruleRow(icon: "checkmark.circle.fill", text: "Neutral expression")
                }
                if let err = step2ValidationError {
                    Text(err)
                        .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                        .foregroundColor(Color(hex: "DC2626"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Button(action: {
                    guard let url = step2FaceImageURLFromValidation, step2ValidationResult?.isValid == true else { return }
                    faceImageURL = url
                    step2ShowingState3 = true
                    step3ApiDone = false
                    step3TimerDone = false
                    startCreateSwatchAndPoll()
                }) {
                    Text("Yes, use this photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(step2ValidationResult?.isValid == true ? Color(hex: "F9FAFB") : Color(hex: "9CA3AF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(step2ValidationResult?.isValid == true ? Color(hex: "030712") : Color(hex: "E5E7EB"))
                        .cornerRadius(9999)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUploadingFace || step2ValidationLoading || step2ValidationResult?.isValid != true)

                Button(action: {
                    step2ValidationResult = nil
                    step2ValidationLoading = false
                    step2FaceImageURLFromValidation = nil
                    step2ValidationError = nil
                    faceImage = nil
                    faceImageURL = nil
                }) {
                    Text("Retake photo")
                        .font(.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "101828"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(Color(hex: "101828"), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUploadingFace || step2ValidationLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .task(id: faceImage?.pngData() ?? Data()) {
            guard faceImage != nil, step2ValidationResult == nil, !step2ValidationLoading else { return }
            runUploadAndValidateFace()
        }
    }

    private func step2ValidationCheckRow(ok: Bool, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(ok ? Color(hex: "30A159") : Color(hex: "DC2626"))
            Text(text)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "6A7282"))
        }
    }

    /// State 3 image block per Figma 55367-46540: center 160x160 circle (100% round), 3 dashed rings, 3 icon buttons dịch vào
    private var step2State3ImageSection: some View {
        ZStack {
            // Center 160x160 image — bo tròn full 100% (Circle)
            if let img = faceImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            } else if let urlString = faceImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
            }
            // 3 concentric dashed rings (200, 240, 280) — stroke rgba(0,0,0,0.05), dash [4,4]
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 200, height: 200)
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 240, height: 240)
            Ellipse()
                .stroke(Color.black.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 280, height: 280)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .overlay {
            GeometryReader { g in
                let cx = g.size.width / 2
                let cy = g.size.height / 2
                let r: CGFloat = 140 // radius of outer circle (280/2)
                // 3 icon đúng vị trí design: sparkle 1h (30°), lipstick 9h (180°), pencil 5h (150°)
                ZStack {
                    Image("step2_ai_sparkle_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(300 * .pi / 180), y: cy + r * sin(300 * .pi / 180))
                    Image("step2_lipstick_fill_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(180 * .pi / 180), y: cy + r * sin(180 * .pi / 180))
                    Image("step2_pencil_fill_swatch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "030712"))
                        .cornerRadius(9999)
                        .position(x: cx + r * cos(60 * .pi / 180), y: cy + r * sin(60 * .pi / 180))
                }
            }
        }
    }

    // MARK: - State 3: Applying the shade... (Figma 55367-1481)
    private var step2State3Content: some View {
        VStack(alignment: .center, spacing: 24) {
            step2State3ImageSection

            VStack(alignment: .center, spacing: 16) {
                Text("Applying the shade...")
                    .font(.custom("Overused Grotesk", size: 24).weight(.regular))
                    .foregroundColor(Color(hex: "101828"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 24) {
                    step2State3ProgressRow(
                        label: "Detecting lips & shape",
                        progress: min(1, step2MockProgress / 25),
                        isActive: step2MockProgress > 0
                    )
                    step2State3ProgressRow(
                        label: "Applying the shade",
                        progress: min(1, max(0, (step2MockProgress - 25) / 25)),
                        isActive: step2MockProgress > 25
                    )
                    step2State3ProgressRow(
                        label: "Blending for a natural finish",
                        progress: min(1, max(0, (step2MockProgress - 50) / 25)),
                        isActive: step2MockProgress > 50
                    )
                    step2State3ProgressRow(
                        label: "Finalizing your swatch",
                        progress: min(1, max(0, (step2MockProgress - 75) / 25)),
                        isActive: step2MockProgress > 75
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func step2State3ProgressRow(label: String, progress: CGFloat, isActive: Bool) -> some View {
        let stepPercent = min(100, Int(progress * 100))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(stepPercent)%")
                    .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                    .foregroundColor(isActive ? Color(hex: "101828") : Color(hex: "6A7282"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9999)
                        .fill(Color(hex: "F3F4F6"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9999)
                                .stroke(isActive ? Color(hex: "E5E7EB") : Color(hex: "E5E7EB"), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "030712"))
                        .frame(width: max(0, (geo.size.width - 4) * progress), height: 4)
                        .padding(.leading, 2)
                        .padding(.vertical, 2)
                        .opacity(progress > 0 ? 1 : 0)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Face photo area (sample or selected image + oval dashed, border 12px) — 165x220 fit
    private var facePhotoArea: some View {
        ZStack {
            Group {
                if let img = faceImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image("FacePhotoSample")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 165, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Ellipse()
                .stroke(Color(hex: "F3F4F6"), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: 165, height: 220)
        }
        .frame(width: 165, height: 220)
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "30A159"))
            Text(text)
                .font(.custom("Overused Grotesk", size: 14).weight(.regular))
                .foregroundColor(Color(hex: "364153"))
        }
    }
}

#Preview {
    SwatchStep2View()
        .environmentObject(AuthViewModel())
}
