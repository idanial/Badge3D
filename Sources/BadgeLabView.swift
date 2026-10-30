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
    @State private var spin: Badge3DSpinEasing = .settle

    var body: some View {
        VStack(spacing: 0) {
            // Parked at the very top so the badge below them reads
            // uninterrupted.
            Picker("Shape", selection: $shape) {
                ForEach(Badge3DShape.allCases, id: \.self) {
                    Text($0.rawValue.capitalized).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            Picker("Style", selection: $styleIndex) {
                ForEach(Self.styles.indices, id: \.self) { Text(Self.styles[$0].0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            // Changing this replays the spin, so the curves can be compared
            // back to back.
            Picker("Spin", selection: $spin) {
                ForEach(Badge3DSpinEasing.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Spacer(minLength: 0)

            Badge3DView(
                symbolName: "bolt.fill",
                style: Self.styles[styleIndex].1,
                shape: shape,
                spin: spin
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
