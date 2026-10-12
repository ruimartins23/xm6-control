import SwiftUI

/// Motion vocabulary for the app, kept in one place so timings don't drift between
/// controls.
///
/// Short and springy rather than long and eased: these are direct manipulations of
/// hardware, and a control that takes half a second to acknowledge a click feels
/// broken rather than smooth.
enum Motion {
    /// Selection moving between options, and content appearing or collapsing.
    static let transition = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Switching between disconnected, connecting and the dashboard.
    static let sceneChange = Animation.spring(response: 0.45, dampingFraction: 0.85)
}
