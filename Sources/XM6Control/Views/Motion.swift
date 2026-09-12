import SwiftUI

/// Motion vocabulary for the app, kept in one place so timings don't drift between
/// controls.
///
/// Everything here is short and springy rather than long and eased: these are direct
/// manipulations of hardware, and a control that takes half a second to acknowledge a
/// click feels broken rather than smooth.
enum Motion {
    /// Presses and selection changes. Quick, with just enough bounce to read as
    /// physical.
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.62)
    /// Selection moving between options, and content appearing or collapsing.
    static let transition = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Hover, which should be felt more than seen.
    static let hover = Animation.easeOut(duration: 0.14)
    /// Switching between disconnected, connecting and the dashboard.
    static let sceneChange = Animation.spring(response: 0.45, dampingFraction: 0.85)
}

/// Tracks pointer hover for a single view.
///
/// An `ObservableObject` rather than `@State` because this project builds against the
/// Command Line Tools, which ship no SwiftUI macro plugin, so `@State` cannot compile
/// here at all. `@StateObject` works, and gives the same per-view lifetime.
final class HoverState: ObservableObject {
    @Published var isHovering = false
}

/// Springy press feedback for any button.
///
/// Uses `ButtonStyle`'s own `isPressed`, so it needs no view-local state and works on
/// every control uniformly, including the ones built out of plain shapes.
struct PressableButtonStyle: ButtonStyle {
    /// How far the control sinks. Circles can take more than wide chips before the
    /// movement starts to look like a glitch.
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Lifts a surface slightly under the pointer: a touch more elevation and a hair of
/// scale, so cards feel like objects rather than printed panels.
struct HoverLift: ViewModifier {
    @StateObject private var hover = HoverState()

    var scale: CGFloat = 1.006
    var shadowOpacity: Double = 0.22

    func body(content: Content) -> some View {
        content
            .scaleEffect(hover.isHovering ? scale : 1.0)
            .shadow(
                color: Color.black.opacity(hover.isHovering ? shadowOpacity : 0),
                radius: 18,
                y: 8
            )
            .animation(Motion.hover, value: hover.isHovering)
            .onHover { hover.isHovering = $0 }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.006, shadowOpacity: Double = 0.22) -> some View {
        modifier(HoverLift(scale: scale, shadowOpacity: shadowOpacity))
    }
}
