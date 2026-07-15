import SwiftUI
import SonyHeadphonesKit

struct DisconnectedView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            Image(systemName: "headphones")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Not Connected")
                    .font(.title2.weight(.semibold))
                if let error = controller.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                } else {
                    Text("Looking for your WH-1000XM6\u{2026}")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                controller.autoConnect()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)

            if !controller.pairedDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OR CHOOSE A PAIRED DEVICE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ForEach(controller.pairedDevices) { device in
                            Button {
                                controller.connect(toAddress: device.id, name: device.name)
                            } label: {
                                HStack {
                                    Text(device.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if device.id != controller.pairedDevices.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }
            }

            Spacer(minLength: 20)
        }
        .padding()
        .task {
            controller.refreshPairedDevices()
        }
    }
}
