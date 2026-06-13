import SwiftUI

/// Visual analog scale: continuous track 0.0–10.0 to one decimal place.
/// Custom-drawn line with a circular handle. Handle starts at 5.0 by default.
struct VASSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.0...10.0
    var leftLabel: String
    var rightLabel: String
    /// Original clinical domain name, surfaced to VoiceOver users.
    var accessibilityHint: String? = nil

    private let handleSize: CGFloat = 28
    private let trackHeight: CGFloat = 6

    var body: some View {
        VStack(spacing: JMSpacing.l) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let span = range.upperBound - range.lowerBound
                let progress = CGFloat((value - range.lowerBound) / span)
                let handleX = max(handleSize / 2, min(width - handleSize / 2, progress * width))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JMColor.divider)
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(JMColor.primary)
                        .frame(width: handleX, height: trackHeight)
                    Circle()
                        .fill(JMColor.surface)
                        .frame(width: handleSize, height: handleSize)
                        .overlay(
                            Circle().strokeBorder(JMColor.primary, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        .offset(x: handleX - handleSize / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let clamped = max(0, min(width, drag.location.x))
                                    let raw = (clamped / width) * CGFloat(span) + CGFloat(range.lowerBound)
                                    value = (raw * 10).rounded() / 10
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.2)
                                }
                        )
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Visual rating slider, \(leftLabel) to \(rightLabel)")
                .accessibilityValue(String(format: "%.1f out of 10", value))
                .accessibilityHint(accessibilityHint ?? "")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: value = min(range.upperBound, ((value + 0.5) * 10).rounded() / 10)
                    case .decrement: value = max(range.lowerBound, ((value - 0.5) * 10).rounded() / 10)
                    @unknown default: break
                    }
                }
            }
            .frame(height: handleSize + 4)

            HStack {
                Text(leftLabel)
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                Spacer()
                Text(rightLabel)
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
            }

            Text(String(format: "%.1f", value))
                .font(JMFont.title)
                .foregroundStyle(JMColor.primary)
                .monospacedDigit()
        }
    }
}
