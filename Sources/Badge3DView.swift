//
//  Badge3DView.swift
//  Badge3D
//
//  A procedurally generated, spinning 3D badge. No model assets: the slab,
//  bevel and raised rim are extruded from bezier paths at runtime, the metal
//  look comes from a PBR material lit by a generated environment map, and the
//  face carries a rendered SF Symbol.
//

import SceneKit
import SwiftUI
import UIKit

/// Palette for a badge. Defaults to gold.
public struct Badge3DStyle: Equatable {
    public var metal: UIColor
    public var metalDark: UIColor
    public var ink: UIColor

    public init(metal: UIColor, metalDark: UIColor, ink: UIColor) {
        self.metal = metal
        self.metalDark = metalDark
        self.ink = ink
    }

    public static let gold = Badge3DStyle(
        metal: UIColor(red: 1.00, green: 0.90, blue: 0.62, alpha: 1),
        metalDark: UIColor(red: 0.74, green: 0.55, blue: 0.20, alpha: 1),
        ink: UIColor(red: 0.28, green: 0.20, blue: 0.08, alpha: 1)
    )

    public static let silver = Badge3DStyle(
        // Neutral metal; the warm cast it picks up comes from the environment
        // reflections, not the palette.
        metal: UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1),
        metalDark: UIColor(red: 0.66, green: 0.66, blue: 0.66, alpha: 1),
        // The ink alone is nudged warm. Dead-neutral dark grey reads as navy
        // against pale metal, so it needs red slightly ahead of blue to look
        // neutral rather than to measure neutral.
        ink: UIColor(red: 0.215, green: 0.205, blue: 0.195, alpha: 1)
    )

    public static let bronze = Badge3DStyle(
        metal: UIColor(red: 0.90, green: 0.62, blue: 0.40, alpha: 1),
        metalDark: UIColor(red: 0.60, green: 0.36, blue: 0.18, alpha: 1),
        ink: UIColor(red: 0.30, green: 0.16, blue: 0.08, alpha: 1)
    )
}

/// How the automatic spin accelerates and settles.
public enum Badge3DSpinEasing: String, CaseIterable, Equatable {
    /// SceneKit's own curve. Roughly quadratic, so acceleration jumps at each
    /// end and the turn starts and stops with a faint snap.
    case easeInOut
    /// Perlin's quintic smootherstep. Velocity *and* acceleration reach zero at
    /// both ends, so there is no jerk at all. The smoothest symmetric option.
    case smootherStep
    /// Sinusoidal. Gentler than quadratic, but still has end jerk.
    case sine
    /// Fast off the mark and settling slowly, reusing the same exponential
    /// decay as a thrown flick so both kinds of spin feel like one object.
    /// Covers ground early, but starts at full speed, so it snaps into motion.
    case flick
    /// A critically damped spring. Velocity starts at zero, peaks early, then
    /// decays exponentially into the stop. This is the flick's long settle with
    /// a smooth start instead of a jolt, and unlike the symmetric curves it
    /// does not brake hard at the end.
    case settle

    /// Fraction of angular velocity kept per second while coasting after a flick.
    static let friction: Float = 0.12

    public var title: String {
        switch self {
        case .easeInOut: return "Ease"
        case .smootherStep: return "Quintic"
        case .sine: return "Sine"
        case .flick: return "Flick"
        case .settle: return "Settle"
        }
    }

    /// A smoother curve spends more of its time slow, so it reads as quicker.
    /// The gentler options get a little longer to keep the pace comparable.
    var duration: TimeInterval {
        switch self {
        case .easeInOut: return 1.5
        case .smootherStep: return 1.8
        case .sine: return 1.6
        case .flick: return 1.9
        case .settle: return 2.0
        }
    }

    /// `nil` falls back to SceneKit's own timing mode.
    var timingFunction: ((Float) -> Float)? {
        switch self {
        case .easeInOut:
            return nil
        case .smootherStep:
            return { t in t * t * t * (t * (t * 6 - 15) + 10) }
        case .sine:
            return { t in -(cos(Float.pi * t) - 1) / 2 }
        case .flick:
            let span = Float(duration)
            let settled = pow(Self.friction, span)
            return { t in (1 - pow(Self.friction, t * span)) / (1 - settled) }
        case .settle:
            // 1 - (1 + wt)e^-wt, the unit step response of a critically damped
            // second-order system. Both value and velocity are zero at t = 0,
            // and the tail is exponential. Renormalised so it lands exactly on
            // 1, since the raw response only approaches it asymptotically.
            let w: Float = 6
            let remainder = (1 + w) * exp(-w)
            return { t in (1 - (1 + w * t) * exp(-w * t)) / (1 - remainder) }
        }
    }
}

/// Silhouette of the badge slab.
public enum Badge3DShape: String, CaseIterable, Equatable {
    case hexagon
    case circle
}

/// A 3D badge rendered with SceneKit. Drag horizontally to spin it; a flick
/// carries momentum that decays with friction. Transparent background, so it
/// composites over whatever sits behind it.
public struct Badge3DView: View {
    /// SF Symbol rendered on the face.
    public var symbolName: String
    public var style: Badge3DStyle
    public var shape: Badge3DShape
    public var spin: Badge3DSpinEasing

    public init(
        symbolName: String,
        style: Badge3DStyle = .gold,
        shape: Badge3DShape = .hexagon,
        spin: Badge3DSpinEasing = .settle
    ) {
        self.symbolName = symbolName
        self.style = style
        self.shape = shape
        self.spin = spin
    }

    /// Bumped on every appearance. A `TabView` keeps its tabs alive, so the
    /// representable is made once and leaving and re-entering the tab would
    /// otherwise never replay the intro spin.
    @State private var appearance = 0

    public var body: some View {
        Badge3DSceneView(
            symbolName: symbolName, style: style, shape: shape, spin: spin,
            appearance: appearance
        )
        .onAppear { appearance &+= 1 }
    }
}

struct Badge3DSceneView: UIViewRepresentable {
    var symbolName: String
    var style: Badge3DStyle
    var shape: Badge3DShape
    var spin: Badge3DSpinEasing
    var appearance: Int

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.scene = Badge3DSceneBuilder(
            symbolName: symbolName, style: style, shape: shape
        ).makeScene()
        context.coordinator.attach(
            to: view, symbolName: symbolName, style: style, shape: shape, spin: spin)
        context.coordinator.appearance = appearance
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.symbolName != symbolName || coordinator.style != style
            || coordinator.shape != shape
        {
            view.scene = Badge3DSceneBuilder(
                symbolName: symbolName, style: style, shape: shape
            ).makeScene()
            coordinator.attach(
                to: view, symbolName: symbolName, style: style, shape: shape, spin: spin)
            coordinator.appearance = appearance
        } else if coordinator.appearance != appearance || coordinator.spin != spin {
            coordinator.appearance = appearance
            coordinator.spin = spin
            coordinator.startIntroSpin()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stopInertia()
    }

    /// Owns the pan gesture and the inertia loop. The current rotation is kept
    /// here so a rebuild of the scene (new symbol or style) preserves the angle.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var symbolName: String?
        var style: Badge3DStyle?
        var shape: Badge3DShape?
        var spin: Badge3DSpinEasing?
        var appearance: Int?

        private weak var spinner: SCNNode?
        private var angle: Float = 0
        private var velocity: Float = 0  // radians per second
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private var panInstalled = false
        private var isDragging = false
        private let introKey = "badge.introSpin"

        /// Radians of rotation per point of horizontal drag.
        private let radiansPerPoint: Float = 0.012
        /// Fraction of angular velocity kept per second while coasting.
        private let friction = Badge3DSpinEasing.friction
        private let minVelocity: Float = 0.05

        /// What the display link is currently driving.
        private enum Motion { case coasting, snapping }
        private var motion: Motion = .coasting

        /// The badge always finishes on a face. Duration scales with how far it
        /// has to travel, so a 2° correction is not given the same time as an
        /// 89° one; the two faces are 180° apart, so 90° is the worst case.
        private let snapShortest: Float = 0.34
        private let snapLongest: Float = 0.72
        private var snapDuration: Float = 0.32
        private var snapFrom: Float = 0
        private var snapTo: Float = 0
        private var snapElapsed: Float = 0

        func attach(
            to view: SCNView, symbolName: String, style: Badge3DStyle, shape: Badge3DShape,
            spin: Badge3DSpinEasing
        ) {
            self.symbolName = symbolName
            self.style = style
            self.shape = shape
            self.spin = spin
            spinner = view.scene?.rootNode.childNode(
                withName: Badge3DSceneBuilder.spinnerName, recursively: true)
            spinner?.eulerAngles.y = angle
            startIntroSpin()
            if !panInstalled {
                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                pan.maximumNumberOfTouches = 1
                view.addGestureRecognizer(pan)

                // A pan only begins once the finger has travelled a few points,
                // so on its own the badge keeps spinning under a resting
                // finger. A zero-duration long press fires on touch-down, which
                // is where the spin should actually stop.
                let touch = UILongPressGestureRecognizer(
                    target: self, action: #selector(handleTouch(_:)))
                touch.minimumPressDuration = 0
                touch.cancelsTouchesInView = false
                touch.delegate = self
                view.addGestureRecognizer(touch)

                panInstalled = true
            }
        }

        /// One eased turn whenever the badge appears or is rebuilt, so its depth
        /// and finish are legible before the user touches it.
        func startIntroSpin() {
            guard let spinner else { return }
            let easing = spin ?? .settle
            spinner.removeAction(forKey: introKey)
            let turn = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: easing.duration)
            if let curve = easing.timingFunction {
                turn.timingFunction = curve
            } else {
                turn.timingMode = .easeInEaseOut
            }
            spinner.runAction(turn, forKey: introKey)
        }

        /// Hand control back to the finger mid-animation, picking up wherever
        /// the intro spin had got to rather than snapping.
        private func cancelIntroSpin() {
            guard let spinner, spinner.action(forKey: introKey) != nil else { return }
            spinner.removeAction(forKey: introKey)
            angle = spinner.eulerAngles.y
        }

        /// Kills every kind of motion the instant a finger lands, and settles on
        /// a face when it lifts without having dragged.
        @objc private func handleTouch(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                stopInertia()
                cancelIntroSpin()
            case .ended, .cancelled:
                if !isDragging { snapToNearestFace() }
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began:
                isDragging = true
                stopInertia()
                cancelIntroSpin()
            case .changed:
                let dx = Float(gesture.translation(in: view).x)
                gesture.setTranslation(.zero, in: view)
                angle += dx * radiansPerPoint
                spinner?.eulerAngles.y = angle
            case .ended, .cancelled:
                isDragging = false
                velocity = Float(gesture.velocity(in: view).x) * radiansPerPoint
                if abs(velocity) > minVelocity {
                    startInertia()
                } else {
                    snapToNearestFace()
                }
            default:
                break
            }
        }

        private func startInertia() {
            motion = .coasting
            startLink()
        }

        /// Step response of an *under*damped spring: leaves at rest, overshoots
        /// the face by about 13%, then swings back and settles. That overshoot
        /// is the bounce. `zeta` sets how far it goes past, `omega` how quickly
        /// the swing dies out.
        private static func springOvershoot(_ t: Float) -> Float {
            let zeta: Float = 0.55
            let omega: Float = 9
            let decay = (1 - zeta * zeta).squareRoot()
            let damped = omega * decay
            return 1
                - exp(-zeta * omega * t)
                * (cos(damped * t) + (zeta / decay) * sin(damped * t))
        }

        /// Always finish on a face rather than at an arbitrary angle.
        private func snapToNearestFace() {
            // The two faces sit at multiples of π about the spin axis.
            let target = (angle / .pi).rounded() * .pi
            let offset = abs(angle - target)
            guard offset > 0.002 else { return }
            let reach = min(1, offset / (.pi / 2))
            snapDuration = snapShortest + (snapLongest - snapShortest) * reach
            snapFrom = angle
            snapTo = target
            snapElapsed = 0
            motion = .snapping
            startLink()
        }

        private func startLink() {
            displayLink?.invalidate()
            lastTimestamp = 0
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stopInertia() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func step(_ link: CADisplayLink) {
            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                return
            }
            let dt = Float(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp

            switch motion {
            case .coasting:
                angle += velocity * dt
                velocity *= pow(friction, dt)
                spinner?.eulerAngles.y = angle
                if abs(velocity) < minVelocity {
                    stopInertia()
                    snapToNearestFace()
                }
            case .snapping:
                snapElapsed += dt
                let t = min(1, snapElapsed / snapDuration)
                angle = snapFrom + (snapTo - snapFrom) * Self.springOvershoot(t)
                spinner?.eulerAngles.y = angle
                if t >= 1 {
                    // The response only approaches its target asymptotically,
                    // so land it exactly rather than a fraction of a degree off.
                    angle = snapTo
                    spinner?.eulerAngles.y = angle
                    stopInertia()
                }
            }
        }
    }
}

// MARK: - Scene construction

struct Badge3DSceneBuilder {
    static let spinnerName = "badge.spinner"
    static let cameraName = "badge.camera"
    static let cameraRest: Float = 5.18

    let symbolName: String
    let style: Badge3DStyle
    let shape: Badge3DShape

    // Badge dimensions in scene units.
    private let radius: CGFloat = 1.0
    private let thickness: CGFloat = 0.12
    /// Where the rim ends and the recessed face begins.
    private let faceRadius: CGFloat = 0.93
    /// How far the face sits below the front of the rim.
    private let recess: CGFloat = 0.026

    /// Depth of the plate holding the two faces; recessed on both sides.
    private var plateDepth: CGFloat { thickness - recess * 2 }
    /// Z of the recessed front face.
    private var faceZ: CGFloat { plateDepth / 2 }

    func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = Badge3DTextures.environmentMap()
        scene.lightingEnvironment.intensity = 1.2

        let camera = SCNCamera()
        camera.fieldOfView = 28
        // No HDR/bloom: at edge-on angles the bevel catches the environment
        // streaks and bloom washes the whole rim out to white.
        camera.wantsHDR = false
        let cameraNode = SCNNode()
        cameraNode.name = Self.cameraName
        cameraNode.camera = camera
        // Pulled in from 5.6 so the badge fills more of its view. Sizing the
        // badge by growing the SwiftUI frame instead would push the frame wider
        // than the screen's content width and drag every sibling's margin with
        // it.
        cameraNode.position = SCNVector3(0, 0, Self.cameraRest)
        scene.rootNode.addChildNode(cameraNode)

        // A directional light alone leaves the badge looking unlit head-on: the
        // face is flat, so a constant light direction highlights all of it or
        // none of it. Nearby omni lights give a direction that varies across
        // the face, so a sheen sits on the metal even at rest.
        func addOmni(at position: SCNVector3, intensity: CGFloat, temperature: CGFloat) {
            let light = SCNLight()
            light.type = .omni
            light.intensity = intensity
            light.temperature = temperature
            let node = SCNNode()
            node.light = light
            node.position = position
            scene.rootNode.addChildNode(node)
        }
        addOmni(at: SCNVector3(-2.4, 2.6, 3.2), intensity: 58, temperature: 6200)
        addOmni(at: SCNVector3(2.6, -2.0, 2.8), intensity: 18, temperature: 4200)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 340
        key.color = UIColor(white: 1, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.6, 0.5, 0)
        scene.rootNode.addChildNode(keyNode)

        // The badge faces the camera dead-on; dragging rotates the spinner
        // about its own vertical axis.
        let spinner = SCNNode()
        spinner.name = Self.spinnerName
        scene.rootNode.addChildNode(spinner)

        spinner.addChildNode(makeRim())
        spinner.addChildNode(makePlate())
        spinner.addChildNode(makeFrontDecal())

        return scene
    }

    // MARK: Geometry

    /// One band around the edge with square, unchamfered corners. Chamfering it
    /// both softened the silhouette and, because the chamfer surfaces sample the
    /// radial grain map edge-on, gave the circle a milled-coin ribbing.
    private func makeRim() -> SCNNode {
        let path = Badge3DPaths.ring(shape: shape, outer: radius, inner: radius * faceRadius)
        let geometry = SCNShape(path: path, extrusionDepth: thickness)
        geometry.chamferRadius = 0
        let polished = metal(
            style.metal, roughness: 0.14,
            grain: Badge3DTextures.spunGrain(base: 0.14, contrast: 0.35), relief: 0.05)
        // Plain, slightly rough wall: no grain map, so the facets of the
        // extruded silhouette do not each catch the environment differently.
        let side = metal(style.metal, roughness: 0.30)
        // SCNShape order: front, back, extruded sides.
        geometry.materials = [polished, polished, side]
        return SCNNode(geometry: geometry)
    }

    /// The plate the content sits on, sunk below the rim on both sides so the
    /// face reads as recessed into the metal.
    private func makePlate() -> SCNNode {
        let path = Badge3DPaths.outline(shape: shape, radius: radius * (faceRadius + 0.015))
        let geometry = SCNShape(path: path, extrusionDepth: plateDepth)
        geometry.chamferRadius = 0
        let face = metal(
            style.metal,
            roughness: 0.30,
            grain: Badge3DTextures.spunGrain(base: 0.30, contrast: 1.0),
            innerShadow: Badge3DTextures.innerShadow(
                shape: shape,
                plateRadius: radius * (faceRadius + 0.015),
                visibleRadius: radius * faceRadius),
            relief: 0.10)
        let wall = metal(style.metalDark, roughness: 0.5)
        geometry.materials = [face, face, wall]
        return SCNNode(geometry: geometry)
    }

    /// The back of the plate is left as bare, grained metal, so the badge has
    /// a finished reverse without carrying any mark.
    private func makeFrontDecal() -> SCNNode {
        let image = Badge3DTextures.symbol(named: symbolName, tint: style.ink)
        let node = decalNode(image: image, size: radius * 1.56)
        node.position = SCNVector3(0, 0, Float(faceZ + 0.004))
        return node
    }

    private func decalNode(image: UIImage, size: CGFloat) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = image
        material.isDoubleSided = false
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        plane.materials = [material]
        return SCNNode(geometry: plane)
    }

    // MARK: Materials

    private func metal(
        _ color: UIColor,
        roughness: CGFloat,
        grain: UIImage? = nil,
        innerShadow: UIImage? = nil,
        relief: Float = 0
    ) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = 1.0
        if let grain {
            // A roughness map, not a colour map: the grain shows up as the
            // highlight breaking into fine radial streaks as the badge turns.
            material.roughness.contents = grain
            material.roughness.intensity = 1.0
            material.roughness.wrapS = .clamp
            material.roughness.wrapT = .clamp
        } else {
            material.roughness.contents = roughness
        }
        if relief > 0 {
            material.normal.contents = Badge3DTextures.grainNormal(strength: 4)
            material.normal.intensity = CGFloat(relief)
            material.normal.wrapS = .repeat
            material.normal.wrapT = .repeat
        }
        if let innerShadow {
            material.multiply.contents = innerShadow
            material.multiply.wrapS = .clamp
            material.multiply.wrapT = .clamp
        }
        return material
    }
}

// MARK: - Paths

enum Badge3DPaths {
    /// Outer silhouette of the badge.
    static func outline(shape: Badge3DShape, radius: CGFloat, clockwise: Bool = true)
        -> UIBezierPath
    {
        let path: UIBezierPath
        switch shape {
        case .hexagon: path = hexagon(radius: radius, cornerRadius: 0.035, clockwise: clockwise)
        case .circle: path = circle(radius: radius, clockwise: clockwise)
        }
        return path
    }

    /// Outline with a concentric hole, for the rim band. The inner path runs the
    /// opposite direction so SceneKit's tessellator treats it as a hole.
    static func ring(shape: Badge3DShape, outer: CGFloat, inner: CGFloat) -> UIBezierPath {
        let path = outline(shape: shape, radius: outer)
        path.append(outline(shape: shape, radius: inner, clockwise: false))
        path.usesEvenOddFillRule = true
        return path
    }

    /// An explicit many-sided polygon rather than an arc. SCNShape flattens
    /// bezier curves at the path's own scale, and at radius 1 a four-curve arc
    /// collapses into a diamond.
    static func circle(radius: CGFloat, clockwise: Bool = true, segments: Int = 144)
        -> UIBezierPath
    {
        let path = UIBezierPath()
        let step = CGFloat.pi * 2 / CGFloat(segments)
        // Start the hole half a segment round, so its first vertex is not
        // radially colinear with the outer contour's first vertex. That
        // degenerate pairing makes the ring tessellate into black slivers.
        let phase = clockwise ? 0 : step / 2
        for i in 0..<segments {
            let t = CGFloat(i) * step + phase
            let angle = clockwise ? t : -t
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        return path
    }

    /// Pointy-top hexagon centred at the origin, with rounded corners.
    static func hexagon(radius: CGFloat, cornerRadius: CGFloat, clockwise: Bool = true)
        -> UIBezierPath
    {
        var points: [CGPoint] = (0..<6).map { i in
            let angle = CGFloat(i) * .pi / 3 + .pi / 2
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
        if !clockwise { points.reverse() }
        return roundedPolygon(points, cornerRadius: cornerRadius)
    }

    private static func roundedPolygon(_ points: [CGPoint], cornerRadius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let n = points.count
        for i in 0..<n {
            let prev = points[(i + n - 1) % n]
            let current = points[i]
            let next = points[(i + 1) % n]
            let inVec = normalized(CGPoint(x: current.x - prev.x, y: current.y - prev.y))
            let outVec = normalized(CGPoint(x: next.x - current.x, y: next.y - current.y))
            let start = CGPoint(
                x: current.x - inVec.x * cornerRadius, y: current.y - inVec.y * cornerRadius)
            let end = CGPoint(
                x: current.x + outVec.x * cornerRadius, y: current.y + outVec.y * cornerRadius)
            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, controlPoint: current)
        }
        path.close()
        return path
    }

    private static func normalized(_ v: CGPoint) -> CGPoint {
        let length = max(sqrt(v.x * v.x + v.y * v.y), 0.0001)
        return CGPoint(x: v.x / length, y: v.y / length)
    }
}

// MARK: - Textures

enum Badge3DTextures {
    /// Spun-metal grain as a roughness map: fine radial streaks from the centre,
    /// the way a lathe-turned or stamped coin face catches light. Cached, since
    /// building one costs a few milliseconds and the values never change.
    static func spunGrain(base: CGFloat, contrast: CGFloat) -> UIImage {
        let key = Int(base * 1000) * 1000 + Int(contrast * 100)
        if let cached = grainCache[key] { return cached }
        let side: CGFloat = 1024
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let spread: CGFloat = 0.045 * contrast
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(white: base, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

            let centre = CGPoint(x: side / 2, y: side / 2)
            let reach = side * 0.75
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func random() -> CGFloat {
                seed ^= seed << 13
                seed ^= seed >> 7
                seed ^= seed << 17
                return CGFloat(seed % 10_000) / 10_000
            }

            cg.setLineCap(.round)
            let spokes = 1400
            for i in 0..<spokes {
                let angle = CGFloat(i) / CGFloat(spokes) * .pi * 2 + random() * 0.004
                let value = base + (random() - 0.5) * 2 * spread
                cg.setStrokeColor(UIColor(white: max(0.05, min(0.95, value)), alpha: 1).cgColor)
                cg.setLineWidth(0.6 + random() * 1.4)
                let inner = side * 0.06
                cg.move(to: CGPoint(x: centre.x + cos(angle) * inner, y: centre.y + sin(angle) * inner))
                cg.addLine(to: CGPoint(x: centre.x + cos(angle) * reach, y: centre.y + sin(angle) * reach))
                cg.strokePath()
            }

            // Radial spokes all meet in the middle, which reads as a starburst.
            // Wash the centre back to the flat base value so the grain fades in.
            let fade = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: base, alpha: 1).cgColor,
                    UIColor(white: base, alpha: 1).cgColor,
                    UIColor(white: base, alpha: 0).cgColor,
                ] as CFArray,
                locations: [0, 0.25, 1])!
            cg.drawRadialGradient(
                fade, startCenter: centre, startRadius: 0, endCenter: centre,
                endRadius: side * 0.30, options: [])

            // Fine per-pixel grain over the whole face. The streaks give the
            // spun direction; this gives the metal its tooth.
            if let noise = noiseImage(side: 1024, centre: base, seed: 0x2545_F491_4F6C_DD1D) {
                cg.setAlpha(0.25)
                cg.draw(noise, in: CGRect(x: 0, y: 0, width: side, height: side))
                cg.setAlpha(1)
            }
        }
        grainCache[key] = image
        return image
    }

    private nonisolated(unsafe) static var grainCache: [Int: UIImage] = [:]

    /// A square of white noise, built straight into a byte buffer because
    /// stroking a million dots through CoreGraphics is far too slow.
    private static func noiseImage(side: Int, centre: CGFloat, seed: UInt64) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: side * side)
        var state = seed
        // Centre the noise on the surface's own roughness so blending it in
        // adds tooth without shifting the overall finish towards matte.
        let mid = Int(max(24, min(230, centre * 255)))
        let amplitude = 26
        for i in 0..<(side * side) {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            bytes[i] = UInt8(mid - amplitude + Int(state % UInt64(amplitude * 2)))
        }
        return bytes.withUnsafeMutableBytes { raw -> CGImage? in
            guard
                let ctx = CGContext(
                    data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                    bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return nil }
            return ctx.makeImage()
        }
    }

    /// A tangent-space normal map of fine metal tooth. Roughness noise alone is
    /// invisible: at this texel density mipmapping averages it back to flat.
    /// Perturbing the surface normal is what actually breaks up the highlight.
    static func grainNormal(strength: Float) -> UIImage {
        let key = Int(strength * 1000)
        if let cached = normalCache[key] { return cached }
        let side = 1024
        var height = [Float](repeating: 0, count: side * side)
        var state: UInt64 = 0xDEAD_BEEF_CAFE_BABE
        for i in 0..<(side * side) {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            height[i] = Float(state % 1024) / 1024
        }
        // A single box blur turns white noise into something that reads as
        // brushed tooth rather than television static.
        var smooth = height
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                var total: Float = 0
                for dy in -1...1 {
                    for dx in -1...1 { total += height[(y + dy) * side + (x + dx)] }
                }
                smooth[y * side + x] = total / 9
            }
        }

        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            let ym = (y - 1 + side) % side, yp = (y + 1) % side
            for x in 0..<side {
                let xm = (x - 1 + side) % side, xp = (x + 1) % side
                let dx = (smooth[y * side + xp] - smooth[y * side + xm]) * strength
                let dy = (smooth[yp * side + x] - smooth[ym * side + x]) * strength
                var nx = -dx, ny = -dy
                var nz: Float = 1
                let length = (nx * nx + ny * ny + nz * nz).squareRoot()
                nx /= length
                ny /= length
                nz /= length
                let offset = (y * side + x) * 4
                bytes[offset] = UInt8(max(0, min(255, (nx * 0.5 + 0.5) * 255)))
                bytes[offset + 1] = UInt8(max(0, min(255, (ny * 0.5 + 0.5) * 255)))
                bytes[offset + 2] = UInt8(max(0, min(255, (nz * 0.5 + 0.5) * 255)))
                bytes[offset + 3] = 255
            }
        }

        let image: UIImage = bytes.withUnsafeMutableBytes { raw in
            guard
                let ctx = CGContext(
                    data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                    bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                let cg = ctx.makeImage()
            else { return UIImage() }
            return UIImage(cgImage: cg)
        }
        normalCache[key] = image
        return image
    }

    private nonisolated(unsafe) static var normalCache: [Int: UIImage] = [:]

    /// Multiply map that darkens the inside edge of the recessed face, so the
    /// content reads as sunk below the rim rather than painted on top.
    ///
    /// This traces the badge's own silhouette. Drawing it as a radial gradient
    /// was wrong for anything but the circle: on a hexagon the darkening
    /// reached full strength on the inscribed circle, which showed up as a
    /// visible arc across the flat edges with bright corners left over.
    ///
    /// The texture is not square. `SCNShape` maps a texture across the *bounding
    /// box* of its path, and a pointy-top hexagon's box is `√3 : 2`. A square
    /// map therefore gets squeezed horizontally, which pulled the darkening in
    /// from the left and right edges and left a bright margin there. Matching
    /// the texture's aspect to the box keeps the scale uniform in both axes.
    ///
    /// - Parameters:
    ///   - plateRadius: radius of the plate the texture is applied to. Its
    ///     bounding box is what the texture is stretched across.
    ///   - visibleRadius: radius at which the rim starts covering the plate.
    ///     Only inside this is ever seen, so this is where the shadow sits.
    static func innerShadow(shape: Badge3DShape, plateRadius: CGFloat, visibleRadius: CGFloat)
        -> UIImage
    {
        let key = "\(shape.rawValue)-\(Int(plateRadius * 1000))-\(Int(visibleRadius * 1000))"
        if let cached = shadowCache[key] { return cached }

        let box = Badge3DPaths.outline(shape: shape, radius: plateRadius).cgPath.boundingBoxOfPath
        guard box.height > 0, box.width > 0 else { return UIImage() }

        let height: CGFloat = 512
        let width = (height * box.width / box.height).rounded()
        let scale = height / box.height

        var transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: width / 2, y: height / 2))
        guard
            let outline = Badge3DPaths.outline(shape: shape, radius: visibleRadius).cgPath
                .copy(using: &transform)
        else { return UIImage() }

        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            cg.saveGState()
            cg.addPath(outline)
            cg.clip()
            cg.setLineJoin(.miter)

            // Each pass is a wide stroke centred on the outline; the clip keeps
            // only its inner half. Narrowing the stroke pass by pass means the
            // band nearest the edge is painted by every pass and deeper ground
            // by progressively fewer, which is the falloff.
            let passes = 28
            // How far the darkening reaches inward, as a fraction of the
            // texture. Kept tight: a wide band stops reading as a shadow cast
            // by the rim and starts reading as a discoloured face.
            let deepest = height * 0.035
            cg.setStrokeColor(UIColor(white: 0, alpha: 0.020).cgColor)
            for i in 0..<passes {
                let t = CGFloat(i) / CGFloat(passes - 1)
                let stroke = deepest * pow(1 - t, 1.4)
                guard stroke > 0.5 else { continue }
                cg.setLineWidth(stroke * 2)
                cg.addPath(outline)
                cg.strokePath()
            }
            cg.restoreGState()
        }
        shadowCache[key] = image
        return image
    }

    private nonisolated(unsafe) static var shadowCache: [String: UIImage] = [:]

    /// Renders an SF Symbol into a square transparent texture, with a soft
    /// highlight below it so the glyph reads as stamped into the face.
    static func symbol(named name: String, tint: UIColor) -> UIImage {
        let side: CGFloat = 1024
        let config = UIImage.SymbolConfiguration(pointSize: 400, weight: .semibold)
        let symbol =
            (UIImage(systemName: name, withConfiguration: config)
            ?? UIImage(systemName: "star.fill", withConfiguration: config)!)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let maxSide = side * 0.62
            let scale = min(maxSide / symbol.size.width, maxSide / symbol.size.height)
            let drawSize = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
            let rect = CGRect(origin: origin, size: drawSize)
            // Light rim on the lower-right lip of the cut, then the dark glyph
            // itself: the pair reads as an impression rather than a sticker.
            symbol.withTintColor(UIColor(white: 1, alpha: 0.55), renderingMode: .alwaysOriginal)
                .draw(in: rect.offsetBy(dx: side * 0.006, dy: side * 0.008))
            symbol.withTintColor(tint, renderingMode: .alwaysOriginal).draw(in: rect)
        }
    }

    /// A generated equirectangular environment: a bright, slightly warm sky, a
    /// dark floor, and a couple of hard highlight streaks so the metal shows
    /// sharp reflections as it turns.
    static func environmentMap() -> UIImage {
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 1.00, green: 0.98, blue: 0.94, alpha: 1).cgColor,
                UIColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1).cgColor,
                UIColor(red: 0.35, green: 0.30, blue: 0.22, alpha: 1).cgColor,
                UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1).cgColor,
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                locations: [0, 0.42, 0.6, 1])!
            cg.drawLinearGradient(
                gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            for (x, width, alpha) in [(180.0, 70.0, 0.95), (520.0, 40.0, 0.7), (800.0, 110.0, 0.85)] {
                let streak = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor(white: 1, alpha: 0).cgColor,
                        UIColor(white: 1, alpha: alpha).cgColor,
                        UIColor(white: 1, alpha: 0).cgColor,
                    ] as CFArray,
                    locations: [0, 0.5, 1])!
                cg.saveGState()
                cg.clip(to: CGRect(x: x - width, y: 0, width: width * 2, height: size.height * 0.62))
                cg.drawLinearGradient(
                    streak, start: CGPoint(x: x - width, y: 0), end: CGPoint(x: x + width, y: 0),
                    options: [])
                cg.restoreGState()
            }
        }
    }
}

#Preview {
    Badge3DView(symbolName: "bolt.fill", shape: .circle)
        .frame(width: 320, height: 320)
        .background(Color(white: 0.97))
}
