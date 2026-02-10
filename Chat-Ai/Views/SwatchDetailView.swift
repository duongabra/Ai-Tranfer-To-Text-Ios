//
//  SwatchDetailView.swift
//  Chat-Ai
//
//  Màn chi tiết Swatch: before/after slider, actions, score, info, feedback
//  UI theo Figma node 55499-3612 (giống SwatchStep2View state 4)
//

import SwiftUI

struct SwatchDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let swatch: Swatch
    @ObservedObject var viewModel: MySwatchesViewModel

    @State private var showShareSheet = false
    @State private var isRegenerating = false
    @State private var localFeedback: Bool?
    @State private var localIsFavorited: Bool
    @State private var beforeAfterSliderPosition: CGFloat = 0.5

    init(swatch: Swatch, viewModel: MySwatchesViewModel) {
        self.swatch = swatch
        self.viewModel = viewModel
        _localFeedback = State(initialValue: swatch.feedback)
        _localIsFavorited = State(initialValue: swatch.isFavorited)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 20) {
                        beforeAfterBlock
                        actionButtonsSection
                        scoreSection
                        infoSection
                        feedbackSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .preference(key: HideTabBarKey.self, value: true) // Ẩn tab bar
        .sheet(isPresented: $showShareSheet) {
            if let swatchUrl = swatch.swatchUrl, let url = URL(string: swatchUrl) {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Header (back left, title center)

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4A5565"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F9FAFB"))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("Detail Swatch")
                .font(.custom("Overused Grotesk", size: 16).weight(.semibold))
                .foregroundColor(Color(hex: "101828"))

            Spacer()

            // Spacer để cân bằng
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Before/After Block (giống SwatchStep2View)

    private static let aspectRatio: CGFloat = 335 / 446

    private var beforeAfterBlock: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let dividerX = width * beforeAfterSliderPosition

            ZStack(alignment: .leading) {
                // After (right side) — full area
                afterImage
                    .frame(width: width, height: height)
                    .clipped()

                // Before (left side) — clipped to left of divider
                beforeImage
                    .frame(width: width, height: height)
                    .frame(width: dividerX, height: height, alignment: .leading)
                    .clipped()

                // Badges
                Text("Before")
                    .font(.custom("Overused Grotesk", size: 12).weight(.semibold))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Text("After")
                    .font(.custom("Overused Grotesk", size: 12).weight(.semibold))
                    .foregroundColor(Color(hex: "030712"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                // Divider line + handle
                dividerWithHandle(width: width, height: height, dividerX: dividerX)
            }
            .frame(width: width, height: height)
            .cornerRadius(16)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
    }

    private var beforeImage: some View {
        Group {
            if let url = URL(string: swatch.barefaceUrl), !swatch.barefaceUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
            } else {
                Color(hex: "F3F4F6")
            }
        }
    }

    private var afterImage: some View {
        Group {
            if let swatchUrl = swatch.swatchUrl, !swatchUrl.isEmpty, let url = URL(string: swatchUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(hex: "F3F4F6")
                    default:
                        ProgressView()
                    }
                }
            } else {
                ZStack {
                    Color(hex: "F3F4F6")
                    if swatch.status == .processing {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Processing...")
                                .font(.custom("Overused Grotesk", size: 12))
                                .foregroundColor(Color(hex: "6A7282"))
                        }
                    }
                }
            }
        }
    }

    private func dividerWithHandle(width: CGFloat, height: CGFloat, dividerX: CGFloat) -> some View {
        ZStack {
            // Divider line
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: height)
                .position(x: dividerX, y: height / 2)

            // Handle circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Double arrow icon
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "030712"))
            }
            .position(x: dividerX, y: height / 2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    beforeAfterSliderPosition = min(1, max(0, value.location.x / width))
                }
        )
    }

    // MARK: - Action Buttons (Reset, Download, Heart)

    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            // Reset/Regenerate
            actionButton(
                imageName: "step2_reset_swatch",
                isSystemImage: false,
                isFilled: false
            ) {
                Task { await regenerateSwatch() }
            }
            .disabled(isRegenerating)
            .opacity(isRegenerating ? 0.5 : 1)

            // Download
            actionButton(
                imageName: "step2_down_swatch",
                isSystemImage: false,
                isFilled: true
            ) {
                showShareSheet = true
            }

            // Favorite
            actionButton(
                imageName: localIsFavorited ? "heart.fill" : "step2_heart_swatch",
                isSystemImage: localIsFavorited,
                isFilled: false,
                tintColor: localIsFavorited ? Color(hex: "EF4444") : nil
            ) {
                Task { await toggleFavorite() }
            }
        }
    }

    private func actionButton(
        imageName: String,
        isSystemImage: Bool,
        isFilled: Bool,
        tintColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isSystemImage {
                    Image(systemName: imageName)
                        .font(.system(size: 18))
                        .foregroundColor(tintColor ?? (isFilled ? Color(hex: "F9FAFB") : Color(hex: "030712")))
                } else {
                    Image(imageName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(isFilled ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                }
            }
            .frame(width: 44, height: 44)
            .background(isFilled ? Color(hex: "030712") : Color.white)
            .overlay(
                Circle()
                    .stroke(Color(hex: "030712"), lineWidth: isFilled ? 0 : 1)
            )
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Score circle
            if let score = swatch.score {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 10.0)
                        .stroke(Color(hex: "30A159"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)/10")
                        .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                        .foregroundColor(Color(hex: "030712"))
                }
                .frame(width: 56, height: 56)
            }

            // AI Description
            if let description = swatch.aiDescription {
                Text(description)
                    .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Warm brick tones add definition to your lips while keeping a natural look.")
                    .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(Color(hex: "6A7282"))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(16)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 8) {
            infoRow(label: "Brand", value: swatch.brand)
            infoRow(label: "Product", value: swatch.product)
            infoRow(label: "Shade", value: swatch.shade ?? "—")
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "6A7282"))
            Spacer()
            Text(value)
                .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                .foregroundColor(Color(hex: "101828"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(12)
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Do you like this swatch?")
                .font(.custom("Overused Grotesk", size: 14).weight(.semibold))
                .foregroundColor(Color(hex: "101828"))

            Spacer()

            // Like button
            feedbackButton(isLiked: true)

            // Dislike button
            feedbackButton(isLiked: false)
        }
        .frame(maxWidth: .infinity)
    }

    private func feedbackButton(isLiked: Bool) -> some View {
        let isSelected = localFeedback == isLiked
        let imageName = isLiked ? "step2_like_swatch" : "step2_dislike_swatch"

        return Button(action: { submitFeedback(isLiked: isLiked) }) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundColor(isSelected ? Color(hex: "F9FAFB") : Color(hex: "030712"))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color(hex: "030712") : Color.white)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : Color(hex: "030712"), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func regenerateSwatch() async {
        isRegenerating = true
        do {
            _ = try await SwatchService.shared.regenerateSwatch(id: swatch.id)
            await viewModel.refresh()
        } catch {
            print("[SwatchDetailView] Regenerate error: \(error)")
        }
        isRegenerating = false
    }

    private func toggleFavorite() async {
        do {
            let response = try await SwatchService.shared.toggleFavorite(swatchId: swatch.id)
            localIsFavorited = response.isFavorited
            await viewModel.refresh()
        } catch {
            print("[SwatchDetailView] Toggle favorite error: \(error)")
        }
    }

    private func submitFeedback(isLiked: Bool) {
        // Toggle: nếu đã chọn thì bỏ chọn
        if localFeedback == isLiked {
            localFeedback = nil
            Task {
                try? await SwatchService.shared.removeFeedback(swatchId: swatch.id)
            }
        } else {
            localFeedback = isLiked
            Task {
                _ = try? await SwatchService.shared.submitFeedback(swatchId: swatch.id, isLiked: isLiked)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SwatchDetailView(
        swatch: Swatch(
            id: "1",
            userId: "user1",
            status: .completed,
            errorMessage: nil,
            barefaceUrl: "https://example.com/bareface.jpg",
            lipstickUrls: [],
            swatchUrl: "https://example.com/swatch.jpg",
            brand: "YSL",
            product: "Vinyl Cream Lip Stain",
            shade: "416",
            hexCode: "#C45C5C",
            score: 8,
            aiDescription: "Warm brick tones add definition and balance your features for a natural, everyday look.",
            isFavorited: true,
            feedback: nil,
            createdAt: Date()
        ),
        viewModel: MySwatchesViewModel()
    )
}
