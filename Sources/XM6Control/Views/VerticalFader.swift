import SwiftUI
import AppKit

/// A real vertical slider for the equalizer bands.
///
/// SwiftUI's `Slider` is horizontal only on macOS, and rotating it with
/// `rotationEffect` leaves the control unrendered and its hit area in the wrong
/// place. `NSSlider` supports vertical orientation natively, and comes with tick
/// marks, snapping, and keyboard support for free, so the fader is wrapped rather
/// than reimplemented with a drag gesture.
struct VerticalFader: NSViewRepresentable {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: Double(value),
            minValue: Double(range.lowerBound),
            maxValue: Double(range.upperBound),
            target: context.coordinator,
            action: #selector(Coordinator.sliderChanged(_:))
        )
        slider.isVertical = true
        slider.controlSize = .small
        // Fire while the knob is being dragged, not just on release, so the
        // headphones follow the fader live. The controller coalesces the stream.
        slider.isContinuous = true
        // One tick per whole step, and snap to them: the wire format is integral, so
        // a continuous slider would only ever round to these positions anyway.
        slider.numberOfTickMarks = range.count
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .leading
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.onChange = onChange
        // Only write back when the model genuinely differs, so a change coming from
        // the headphones moves the knob without fighting an in-progress drag. During a
        // drag the slider already holds the model's value, so this doesn't fire and
        // the knob stays glued to the pointer; it runs for external changes such as
        // picking a preset or resetting to flat, where a knob teleporting across the
        // track reads as a glitch.
        if Int(nsView.doubleValue.rounded()) != value {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                nsView.animator().doubleValue = Double(value)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject {
        var onChange: (Int) -> Void

        init(onChange: @escaping (Int) -> Void) {
            self.onChange = onChange
        }

        @objc func sliderChanged(_ sender: NSSlider) {
            onChange(Int(sender.doubleValue.rounded()))
        }
    }
}
