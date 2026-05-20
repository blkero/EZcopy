import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = MediaSelectionViewModel()
    @StateObject private var transferServer = TransferServer()
    @State private var linkCopyMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeader(state: transferServer.state)

                    ReceiverPanel(
                        state: transferServer.state,
                        selectedCount: viewModel.selectedMedia.count,
                        cacheUsage: transferServer.cacheUsageText,
                        copyMessage: linkCopyMessage,
                        onStart: {
                            linkCopyMessage = nil
                            transferServer.start(media: viewModel.selectedMedia)
                        },
                        onStop: {
                            linkCopyMessage = nil
                            transferServer.stop()
                        },
                        onCopyLink: copyReceiverLink
                    )

                    if case let .failed(message) = transferServer.state {
                        AlertBanner(text: message, systemImage: "exclamationmark.triangle", tint: .red)
                    }

                    if let progress = transferServer.transferProgress {
                        TransferProgressView(progress: progress)
                    }

                    TransferOptionsPanel(
                        includeMD5Checksums: $transferServer.includeMD5Checksums,
                        cacheUsage: transferServer.cacheUsageText,
                        cacheMessage: transferServer.cacheMessage,
                        onClearCache: { transferServer.clearCache() }
                    )

                    MediaPickerPanel(
                        pickerItems: $viewModel.pickerItems,
                        photoCount: viewModel.photoCount,
                        videoCount: viewModel.videoCount
                    ) {
                        viewModel.refreshSelection()
                        transferServer.updateMedia(viewModel.selectedMedia)
                    }

                    if viewModel.unsupportedCount > 0 {
                        AlertBanner(
                            text: "\(viewModel.unsupportedCount) unsupported item(s) were skipped.",
                            systemImage: "info.circle",
                            tint: AppTheme.muted
                        )
                    }

                    if viewModel.unavailableCount > 0 {
                        AlertBanner(
                            text: "\(viewModel.unavailableCount) item(s) could not be linked to a local Photos asset and were skipped. Allow full Photos access, then re-select the files.",
                            systemImage: "photo.badge.exclamationmark",
                            tint: .orange
                        )
                    }

                    if viewModel.selectedMedia.isEmpty {
                        EmptySelectionView()
                    } else {
                        SelectedMediaList(media: viewModel.selectedMedia)
                    }

                    FooterSignature()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                viewModel.requestPhotoLibraryAccess()
                transferServer.refreshCacheUsage()
            }
        }
    }

    private func copyReceiverLink() {
        guard let url = transferServer.state.url else {
            linkCopyMessage = "Start the receiver before copying the link."
            return
        }

        UIPasteboard.general.string = url.absoluteString
        linkCopyMessage = "Link copied. You can also type the address and access code manually."
    }
}

private struct BrandHeader: View {
    let state: TransferServer.ServerState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.ink)
                Text("EZ")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.cream)
            }
            .frame(width: 58, height: 58)
            .overlay(alignment: .bottom) {
                Image(systemName: "wifi")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.red)
                    .offset(y: -5)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("EZCopy")
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .foregroundStyle(AppTheme.ink)

                Text("Local Wi-Fi media transfer for creators")
                    .font(.callout)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            StatusPill(state: state)
        }
    }
}

private struct StatusPill: View {
    let state: TransferServer.ServerState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private var tint: Color {
        switch state {
        case .running:
            return .green
        case .starting:
            return AppTheme.teal
        case .failed:
            return .red
        case .stopped:
            return AppTheme.muted
        }
    }
}

private struct ReceiverPanel: View {
    let state: TransferServer.ServerState
    let selectedCount: Int
    let cacheUsage: String
    let copyMessage: String?
    let onStart: () -> Void
    let onStop: () -> Void
    let onCopyLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Receiver", subtitle: "Open the session URL in desktop Chrome or Edge.", systemImage: "network")

            VStack(spacing: 10) {
                MetricRow(title: "Address", value: state.baseURL?.absoluteString ?? "Start receiver first", monospaced: true)
                AccessCodeRow(code: state.accessCode)
                MetricRow(title: "Expires", value: state.expiresAt.map(Self.expiryFormatter.string(from:)) ?? "-")
                MetricRow(title: "Selected", value: "\(selectedCount) files")
                MetricRow(title: "Network", value: "Wi-Fi only")
                MetricRow(title: "Cache", value: cacheUsage)
            }

            if state.url != nil {
                ForegroundRunNote()
            }

            HStack(spacing: 12) {
                Button(action: onStart) {
                    Label("Start Receiver", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(SecondaryIconButtonStyle())
                .disabled(state == .stopped)
            }

            Button(action: onCopyLink) {
                Label("Copy Link", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CopyLinkButtonStyle())
            .disabled(state.url == nil)

            if let copyMessage {
                Text(copyMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
        }
        .panelStyle()
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ForegroundRunNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .frame(width: 24, height: 24)

            Text("Keep EZCopy open in the foreground while the browser connects and downloads.")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.teal.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AccessCodeRow: View {
    let code: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Access Code")
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
            Spacer(minLength: 10)
            Text(code ?? "-")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .monospaced()
                .foregroundStyle(AppTheme.ink)
                .tracking(2)
                .lineLimit(1)
        }
    }
}

private struct TransferOptionsPanel: View {
    @Binding var includeMD5Checksums: Bool
    let cacheUsage: String
    let cacheMessage: String?
    let onClearCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Transfer Options", subtitle: "Tune package creation before downloading.", systemImage: "slider.horizontal.3")

            Toggle(isOn: $includeMD5Checksums) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Generate MD5 checksums")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Disable to skip the extra verification pass on large videos.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
            }
            .tint(AppTheme.teal)

            Divider()

            HStack(spacing: 12) {
                Label(cacheUsage, systemImage: "externaldrive")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Button(action: onClearCache) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(CompactBorderedButtonStyle())
                .disabled(cacheUsage == "0 B")
            }

            if let cacheMessage {
                Text(cacheMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .panelStyle()
    }
}

private struct MediaPickerPanel: View {
    @Binding var pickerItems: [PhotosPickerItem]
    let photoCount: Int
    let videoCount: Int
    let onSelectionChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Media", subtitle: "Choose iPhone photos and videos for the next package.", systemImage: "photo.on.rectangle")

            HStack(spacing: 10) {
                CountTile(title: "Photos", value: "\(photoCount)", systemImage: "photo")
                CountTile(title: "Videos", value: "\(videoCount)", systemImage: "video")
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 0,
                matching: .any(of: [.images, .videos]),
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                Label("Select Photos and Videos", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .onChange(of: pickerItems) {
                onSelectionChange()
            }
        }
        .panelStyle()
    }
}

private struct TransferProgressView: View {
    let progress: TransferProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.doc")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.red)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(progress.filename)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text("\(progress.phase) · \(progress.detailText)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Text(progress.percentageText)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            ProgressView(value: progress.fractionCompleted ?? 0)
                .tint(AppTheme.red)
        }
        .panelStyle()
    }
}

private struct SelectedMediaList: View {
    let media: [SelectedMedia]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Selected Media", subtitle: "\(media.count) ready for packaging", systemImage: "rectangle.stack")

            LazyVStack(spacing: 8) {
                ForEach(media) { item in
                    SelectedMediaRow(item: item)
                }
            }
        }
    }
}

private struct SelectedMediaRow: View {
    let item: SelectedMedia

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.mediaType == .photo ? "photo" : "video")
                .font(.headline)
                .foregroundStyle(item.mediaType == .photo ? AppTheme.teal : AppTheme.red)
                .frame(width: 38, height: 38)
                .background((item.mediaType == .photo ? AppTheme.teal : AppTheme.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(item.detailText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

private struct EmptySelectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(AppTheme.teal)

            Text("No media selected")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("Select a few local iPhone photos or videos to prepare the EZCopy transfer package.")
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.teal)
                .frame(width: 26, height: 26)
                .background(AppTheme.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
            Spacer(minLength: 10)
            Text(value)
                .font(monospaced ? .callout.monospaced() : .callout.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct CountTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.teal)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AlertBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(4)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct FooterSignature: View {
    var body: some View {
        Text("EZCopy · Created by BLKero · 2026")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .accessibilityLabel("EZCopy Created by BLKero 2026")
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(AppTheme.cream)
            .frame(minHeight: 48)
            .padding(.horizontal, 14)
            .background(configuration.isPressed ? AppTheme.ink.opacity(0.86) : AppTheme.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SecondaryIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(isEnabled ? AppTheme.red : AppTheme.muted.opacity(0.45))
            .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct CompactBorderedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isEnabled ? AppTheme.red : AppTheme.muted.opacity(0.45))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct CopyLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(isEnabled ? AppTheme.ink : AppTheme.muted.opacity(0.45))
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(AppTheme.teal.opacity(isEnabled ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.teal.opacity(isEnabled ? 0.32 : 0.12), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.ink.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

private enum AppTheme {
    static let background = Color(red: 0.96, green: 0.965, blue: 0.955)
    static let surface = Color(red: 1.0, green: 0.992, blue: 0.965)
    static let surfaceAlt = Color(red: 0.95, green: 0.965, blue: 0.955)
    static let ink = Color(red: 0.02, green: 0.12, blue: 0.18)
    static let cream = Color(red: 1.0, green: 0.91, blue: 0.72)
    static let teal = Color(red: 0.11, green: 0.48, blue: 0.47)
    static let red = Color(red: 0.82, green: 0.18, blue: 0.12)
    static let muted = Color(red: 0.35, green: 0.42, blue: 0.45)
    static let stroke = Color.black.opacity(0.08)
}

#Preview {
    ContentView()
}
