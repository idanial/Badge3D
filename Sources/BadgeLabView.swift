//
//  BadgeLabView.swift
//  Badge3D
//
//  Shape controls and material swatches below the badge. Drag the
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
            Badge3DView(
                symbolName: "star.fill",
                style: Self.styles[styleIndex].1,
                shape: shape
            )
            .frame(width: 324, height: 324)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            HStack(spacing: 4) {
                ForEach(Badge3DShape.allCases, id: \.self) { option in
                    Button {
                        shape = option
                    } label: {
                        Image(systemName: option.rawValue)
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(shape == option ? Color.black : Color.gray.opacity(0.55))
                            .frame(width: 52, height: 52)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue.capitalized)
                    .accessibilityAddTraits(shape == option ? .isSelected : [])
                }
            }
            .padding(.bottom, 20)

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
                                    Color(Self.styles[index].1.metal).opacity(0.9),
                                    Color(Self.styles[index].1.metal),
                                    Color(Self.styles[index].1.metalDark),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .strokeBorder(.black, lineWidth: styleIndex == index ? 2 : 0)
                                    .padding(-5)
                            }
                            .frame(width: 52, height: 52)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.styles[index].0)
                    .accessibilityAddTraits(styleIndex == index ? .isSelected : [])
                }
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    BadgeLabView()
}
