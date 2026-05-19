import Foundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class MediaSelectionViewModel: ObservableObject {
    @Published var pickerItems: [PhotosPickerItem] = []
    @Published private(set) var selectedMedia: [SelectedMedia] = []
    @Published private(set) var unsupportedCount = 0
    @Published private(set) var unavailableCount = 0
    @Published private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var photoCount: Int {
        selectedMedia.filter { $0.mediaType == .photo }.count
    }

    var videoCount: Int {
        selectedMedia.filter { $0.mediaType == .video }.count
    }

    func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            Task { @MainActor in
                self.authorizationStatus = status
                self.refreshSelection()
            }
        }
    }

    func refreshSelection() {
        let assetIdentifiers = pickerItems.compactMap(\.itemIdentifier)
        let assetsByIdentifier = fetchAssetsByIdentifier(assetIdentifiers)
        var media: [SelectedMedia] = []
        var unsupported = 0
        var unavailable = 0

        for item in pickerItems {
            guard let mediaType = MediaType(item: item) else {
                unsupported += 1
                continue
            }

            guard let assetIdentifier = item.itemIdentifier,
                  let asset = assetsByIdentifier[assetIdentifier],
                  let resource = preferredResource(for: asset, mediaType: mediaType) else {
                unavailable += 1
                continue
            }

            let filename = resource.originalFilename

            media.append(
                SelectedMedia(
                    id: assetIdentifier,
                    originalName: filename,
                    mediaType: mediaType,
                    createdAt: asset.creationDate,
                    duration: mediaType == .video ? asset.duration : nil,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    assetIdentifier: assetIdentifier
                )
            )
        }

        selectedMedia = media
        unsupportedCount = unsupported
        unavailableCount = unavailable
    }

    private func fetchAssetsByIdentifier(_ identifiers: [String]) -> [String: PHAsset] {
        guard !identifiers.isEmpty else { return [:] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [String: PHAsset] = [:]

        result.enumerateObjects { asset, _, _ in
            assets[asset.localIdentifier] = asset
        }

        return assets
    }

    private func preferredResource(for asset: PHAsset, mediaType: MediaType) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        switch mediaType {
        case .photo:
            return resources.first { $0.type == .photo || $0.type == .fullSizePhoto } ?? resources.first
        case .video:
            return resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        }
    }

}

struct SelectedMedia: Identifiable, Equatable {
    let id: String
    let originalName: String
    let mediaType: MediaType
    let createdAt: Date?
    let duration: TimeInterval?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let assetIdentifier: String?

    var detailText: String {
        var details: [String] = [mediaType.label]

        if let pixelWidth, let pixelHeight, pixelWidth > 0, pixelHeight > 0 {
            details.append("\(pixelWidth)x\(pixelHeight)")
        }

        if let duration {
            details.append(Self.durationFormatter.string(from: duration) ?? "\(Int(duration))s")
        }

        if let createdAt {
            details.append(Self.dateFormatter.string(from: createdAt))
        }

        return details.joined(separator: " • ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

extension MediaType {
    init?(item: PhotosPickerItem) {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            self = .video
        } else if item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) {
            self = .photo
        } else {
            return nil
        }
    }

    var label: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        }
    }
}
