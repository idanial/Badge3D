//
//  BadgeLabView.swift
//  Badge3D
//
//  The whole app: the settings across the top, the badge below them. Drag the
//  badge to spin it; a flick carries momentum and always settles on a face.
//

import SwiftUI

struct BadgeLabView: View {
    private static let styles: [(String, Badge3DStyle)] = [
        ("Gold", .gold), ("Silver", .silver), ("Bronze", .bronze),
    ]

    @State private var styleIndex = 0
    @State private var shape: Badge3DShape = .hexagon

    var body: some View {
        VStack(spacing: 0) {
            // Parked at the very top so the badge below them reads
            // uninterrupted.
            Picker("Shape", selection: $shape) {
                ForEach(Badge3DShape.allCases, id: \.self) {
                    Image(systemName: $0.rawValue)
                        .accessibilityLabel($0.rawValue.capitalized)
                        .tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            HStack(spacing: 4) {
                ForEach(Self.styles.indices, id: \.self) { index in
                    Button {
                        styleIndex = index
                    } label: {
                        Circle()
                            .fill(LinearGradient(
                                colors: [
                                    Color(Self.styles[index].1.metalDark),
                                    Color(Self.styles[index].1.metal),
                                    .white.opacity(0.9),
                                    Color(Self.styles[index].1.metal),
                                    Color(Self.styles[index].1.metalDark),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 28, height: 28)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if styleIndex == index {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.background)
                                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.styles[index].0)
                    .accessibilityAddTraits(styleIndex == index ? .isSelected : [])
                }
            }
            .padding(4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 0)

            Badge3DView(
                symbolName: "bolt.fill",
                style: Self.styles[styleIndex].1,
                shape: shape
            )
            .frame(width: 324, height: 324)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    BadgeLabView()
}
