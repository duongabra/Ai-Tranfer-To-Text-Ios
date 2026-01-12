//
//  GoogleIcon.swift
//  Chat-Ai
//
//  Google Icon từ SVG
//

import SwiftUI

struct GoogleIcon: View {
    var size: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Blue path
            Path { path in
                path.move(to: CGPoint(x: 17.8427, y: 7.31885))
                path.addCurve(to: CGPoint(x: 18, y: 9.00017), control1: CGPoint(x: 17.9461, y: 7.86328), control2: CGPoint(x: 18, y: 8.42554))
                path.addCurve(to: CGPoint(x: 17.8032, y: 10.8793), control1: CGPoint(x: 18, y: 9.64452), control2: CGPoint(x: 17.9323, y: 10.273))
                path.addCurve(to: CGPoint(x: 14.6344, y: 16.0187), control1: CGPoint(x: 17.3651, y: 12.9424), control2: CGPoint(x: 16.2203, y: 14.7439))
                path.addLine(to: CGPoint(x: 14.6339, y: 16.0182))
                path.addLine(to: CGPoint(x: 12.0659, y: 15.8872))
                path.addLine(to: CGPoint(x: 11.7025, y: 13.6184))
                path.addCurve(to: CGPoint(x: 14.0104, y: 10.8793), control1: CGPoint(x: 12.7548, y: 13.0013), control2: CGPoint(x: 13.5772, y: 12.0355))
                path.addLine(to: CGPoint(x: 9.19781, y: 10.8793))
                path.addLine(to: CGPoint(x: 9.19781, y: 7.31885))
                path.addLine(to: CGPoint(x: 14.0806, y: 7.31885))
                path.addLine(to: CGPoint(x: 17.8427, y: 7.31885))
                path.closeSubpath()
            }
            .fill(Color(hex: "518EF8"))
            
            // Green path
            Path { path in
                path.move(to: CGPoint(x: 14.6337, y: 16.0183))
                path.addLine(to: CGPoint(x: 14.6342, y: 16.0188))
                path.addCurve(to: CGPoint(x: 8.99974, y: 18.0003), control1: CGPoint(x: 13.0918, y: 17.2585), control2: CGPoint(x: 11.1325, y: 18.0003))
                path.addCurve(to: CGPoint(x: 1.07227, y: 13.2654), control1: CGPoint(x: 5.5723, y: 18.0003), control2: CGPoint(x: 2.5924, y: 16.0846))
                path.addLine(to: CGPoint(x: 3.98889, y: 10.8779))
                path.addCurve(to: CGPoint(x: 8.99974, y: 14.3504), control1: CGPoint(x: 4.74894, y: 12.9064), control2: CGPoint(x: 6.70571, y: 14.3504))
                path.addCurve(to: CGPoint(x: 11.7022, y: 13.6185), control1: CGPoint(x: 9.98577, y: 14.3504), control2: CGPoint(x: 10.9095, y: 14.0838))
                path.addLine(to: CGPoint(x: 14.6337, y: 16.0183))
                path.closeSubpath()
            }
            .fill(Color(hex: "28B446"))
            
            // Yellow path
            Path { path in
                path.move(to: CGPoint(x: 3.9892, y: 10.8775))
                path.addLine(to: CGPoint(x: 3.36265, y: 13.2165))
                path.addLine(to: CGPoint(x: 1.07259, y: 13.265))
                path.addCurve(to: CGPoint(x: 0, y: 8.99988), control1: CGPoint(x: 0.388198, y: 11.9956), control2: CGPoint(x: 0, y: 10.5432))
                path.addCurve(to: CGPoint(x: 1.00632, y: 4.86084), control1: CGPoint(x: 0, y: 7.50745), control2: CGPoint(x: 0.362955, y: 6.10007))
                path.addLine(to: CGPoint(x: 1.00681, y: 4.86084))
                path.addLine(to: CGPoint(x: 3.0456, y: 5.23462))
                path.addLine(to: CGPoint(x: 3.93872, y: 7.26118))
                path.addCurve(to: CGPoint(x: 3.64991, y: 8.99988), control1: CGPoint(x: 3.75179, y: 7.80614), control2: CGPoint(x: 3.64991, y: 8.39115))
                path.addCurve(to: CGPoint(x: 3.9892, y: 10.8775), control1: CGPoint(x: 3.64998, y: 9.66054), control2: CGPoint(x: 3.76965, y: 10.2935))
                path.closeSubpath()
            }
            .fill(Color(hex: "EABD08"))
            
            // Red path
            Path { path in
                path.move(to: CGPoint(x: 14.7448, y: 2.07198))
                path.addLine(to: CGPoint(x: 11.8292, y: 4.45896))
                path.addCurve(to: CGPoint(x: 9.00009, y: 3.64994), control1: CGPoint(x: 11.0088, y: 3.94617), control2: CGPoint(x: 10.039, y: 3.64994))
                path.addCurve(to: CGPoint(x: 3.93879, y: 7.26135), control1: CGPoint(x: 6.65413, y: 3.64994), control2: CGPoint(x: 4.66076, y: 5.16016))
                path.addLine(to: CGPoint(x: 1.00685, y: 4.86101))
                path.addLine(to: CGPoint(x: 1.00636, y: 4.86101))
                path.addCurve(to: CGPoint(x: 9.00009, y: 0), control1: CGPoint(x: 2.50423, y: 1.97309), control2: CGPoint(x: 5.52171, y: 0))
                path.addCurve(to: CGPoint(x: 14.7448, y: 2.07198), control1: CGPoint(x: 11.1838, y: 0), control2: CGPoint(x: 13.1861, y: 0.777872))
                path.closeSubpath()
            }
            .fill(Color(hex: "F14336"))
        }
        .frame(width: size, height: size)
        .scaleEffect(size / 18) // Scale từ 18x18 gốc
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        GoogleIcon(size: 18)
        GoogleIcon(size: 24)
        GoogleIcon(size: 32)
    }
    .padding()
}

