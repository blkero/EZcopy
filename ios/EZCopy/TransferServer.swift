import Foundation
import CryptoKit
import Network
import Photos
import Security
import UIKit

final class TransferServer: ObservableObject {
    enum ServerState: Equatable {
        case stopped
        case starting
        case running(baseURL: URL, copyURL: URL, accessCode: String, expiresAt: Date)
        case failed(String)

        var label: String {
            switch self {
            case .stopped:
                return "Stopped"
            case .starting:
                return "Starting"
            case .running:
                return "Running"
            case .failed:
                return "Failed"
            }
        }

        var url: URL? {
            if case let .running(_, copyURL, _, _) = self {
                return copyURL
            }
            return nil
        }

        var expiresAt: Date? {
            if case let .running(_, _, _, expiresAt) = self {
                return expiresAt
            }
            return nil
        }

        var baseURL: URL? {
            if case let .running(baseURL, _, _, _) = self {
                return baseURL
            }
            return nil
        }

        var accessCode: String? {
            if case let .running(_, _, accessCode, _) = self {
                return accessCode
            }
            return nil
        }
    }

    @Published private(set) var state: ServerState = .stopped
    @Published private(set) var transferProgress: TransferProgress?
    @Published private(set) var cacheUsageText = "0 B"
    @Published private(set) var cacheMessage: String?
    @Published var includeMD5Checksums = true

    private let port: UInt16 = 8080
    private let sessionDuration: TimeInterval = 10 * 60
    private let queue = DispatchQueue(label: "com.ezcopy.transfer-server")
    private var listener: NWListener?
    private var media: [SelectedMedia] = []
    private var sessionCode: String?
    private var sessionExpiresAt: Date?
    private var sessionExpirationWorkItem: DispatchWorkItem?

    init() {
        refreshCacheUsage()
    }

    func start(media: [SelectedMedia]) {
        self.media = media

        guard listener == nil else {
            return
        }

        guard LocalNetworkAddress.wiFiIPv4Address() != nil else {
            state = .failed("EZCopy requires Wi-Fi. Cellular transfer is blocked.")
            return
        }

        state = .starting
        sessionCode = Self.makeSessionCode()
        sessionExpiresAt = Date().addingTimeInterval(sessionDuration)

        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.start(queue: queue)
        } catch {
            state = .failed(error.localizedDescription)
            listener = nil
            clearSession()
        }
    }

    func stop() {
        clearSession()
        listener?.cancel()
        listener = nil
        state = .stopped
        transferProgress = nil
    }

    func updateMedia(_ media: [SelectedMedia]) {
        self.media = media
    }

    func clearCache() {
        queue.async {
            do {
                try Self.removeCacheDirectories()
                DispatchQueue.main.async {
                    self.cacheMessage = "Cache cleared."
                    self.transferProgress = nil
                    self.refreshCacheUsage()
                }
            } catch {
                DispatchQueue.main.async {
                    self.cacheMessage = "Could not clear cache: \(error.localizedDescription)"
                    self.refreshCacheUsage()
                }
            }
        }
    }

    func refreshCacheUsage() {
        let bytes = Self.cacheSize()
        cacheUsageText = Self.formatBytes(Int64(bytes))
    }

    private func handleListenerState(_ listenerState: NWListener.State) {
        switch listenerState {
        case .ready:
            if let address = LocalNetworkAddress.wiFiIPv4Address(),
               let code = sessionCode,
               let expiresAt = sessionExpiresAt,
               let baseURL = URL(string: "http://\(address):\(port)"),
               let copyURL = URL(string: "http://\(address):\(port)/?code=\(code)") {
                state = .running(baseURL: baseURL, copyURL: copyURL, accessCode: code, expiresAt: expiresAt)
                scheduleSessionExpiration(at: expiresAt)
            } else {
                state = .failed("Could not find a Wi-Fi IP address. Cellular transfer is blocked.")
                clearSession()
            }
        case .failed(let error):
            state = .failed(error.localizedDescription)
            listener?.cancel()
            listener = nil
            clearSession()
        case .cancelled:
            if listener != nil {
                state = .stopped
            }
            clearSession()
        default:
            break
        }
    }

    private func clearSession() {
        sessionExpirationWorkItem?.cancel()
        sessionExpirationWorkItem = nil
        sessionCode = nil
        sessionExpiresAt = nil
    }

    private func scheduleSessionExpiration(at expiresAt: Date) {
        sessionExpirationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.expireSessionIfNeeded()
        }
        sessionExpirationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, expiresAt.timeIntervalSinceNow), execute: workItem)
    }

    private func expireSessionIfNeeded() {
        guard let expiresAt = sessionExpiresAt, Date() >= expiresAt else {
            return
        }

        sessionExpirationWorkItem?.cancel()
        sessionExpirationWorkItem = nil

        let activeListener = listener
        listener = nil
        activeListener?.cancel()

        sessionCode = nil
        sessionExpiresAt = nil
        transferProgress = nil
        state = .failed("EZCopy session expired. Start Receiver again to create a fresh link.")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveRequest(on: connection)
            }
        }
        connection.start(queue: queue)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            self.respond(to: request, on: connection)
        }
    }

    private func respond(to request: String, on connection: NWConnection) {
        let target = requestTarget(from: request)

        if target.method == "OPTIONS" {
            connection.send(content: optionsResponse(), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        guard isAuthorized(target) else {
            if target.path == "/" {
                let response = httpResponse(body: accessCodeHTML(), contentType: "text/html; charset=utf-8")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            sendError(
                "This EZCopy access code is invalid or expired. Copy a fresh link from the iPhone app.",
                status: "401 Unauthorized",
                on: connection
            )
            return
        }

        switch target.path {
        case "/manifest.json":
            let response = httpResponse(body: manifestJSON(), contentType: "application/json; charset=utf-8")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        case "/download":
            guard let id = target.query["id"],
                  let item = media.first(where: { $0.assetIdentifier == id || $0.id == id }) else {
                sendError("File not found.", status: "404 Not Found", on: connection)
                return
            }

            exportMedia(item) { result in
                switch result {
                case .success(let exportedFile):
                    self.streamFile(exportedFile, on: connection)
                case .failure(let error):
                    self.sendError(error.localizedDescription, status: "500 Internal Server Error", on: connection)
                }
            }
        case "/archive.zip":
            createArchive { result in
                switch result {
                case .success(let archive):
                    self.streamFile(url: archive.url, filename: archive.filename, contentType: "application/zip", deleteOnCompletion: archive.url, on: connection)
                case .failure(let error):
                    self.sendError(error.localizedDescription, status: "500 Internal Server Error", on: connection)
                }
            }
        default:
            let response = httpResponse(body: statusHTML(), contentType: "text/html; charset=utf-8")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func isAuthorized(_ target: RequestTarget) -> Bool {
        guard let code = sessionCode,
              let expiresAt = sessionExpiresAt,
              Date() < expiresAt else {
            DispatchQueue.main.async {
                self.expireSessionIfNeeded()
            }
            return false
        }

        return target.query["code"]?.uppercased() == code
    }

    private func requestTarget(from request: String) -> RequestTarget {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            return RequestTarget(method: "GET", path: "/", query: [:])
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return RequestTarget(method: "GET", path: "/", query: [:])
        }

        let method = String(parts[0])
        let rawTarget = String(parts[1])
        guard let components = URLComponents(string: "http://ezcopy.local\(rawTarget)") else {
            return RequestTarget(method: method, path: "/", query: [:])
        }

        let query = components.queryItems?.reduce(into: [String: String]()) { values, item in
            values[item.name] = item.value
        } ?? [:]

        return RequestTarget(method: method, path: components.path, query: query)
    }

    private func httpResponse(body: String, contentType: String) -> Data {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Access-Control-Expose-Headers: Content-Length, Content-Disposition\r
        Cache-Control: no-store\r
        Connection: close\r
        \r

        """
        var response = Data(header.utf8)
        response.append(bodyData)
        return response
    }

    private func sendError(_ message: String, status: String, on connection: NWConnection) {
        let body = """
        <!doctype html>
        <html lang="en">
        <body>
          <h1>\(Self.escapeHTML(status))</h1>
          <p>\(Self.escapeHTML(message))</p>
        </body>
        </html>
        """
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Cache-Control: no-store\r
        Connection: close\r
        \r

        """
        var response = Data(header.utf8)
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func optionsResponse() -> Data {
        let header = """
        HTTP/1.1 204 No Content\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Access-Control-Max-Age: 600\r
        Content-Length: 0\r
        Connection: close\r
        \r

        """
        return Data(header.utf8)
    }

    private func accessCodeHTML() -> String {
        let expiresText = sessionExpiresAt.map { Self.sessionTimeFormatter.string(from: $0) } ?? "-"

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>EZCopy Access Code</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #172026; background: #f4f7f6; }
            main { max-width: 520px; margin: 0 auto; }
            h1 { margin: 0 0 10px; font-size: 32px; }
            p { color: #5b6871; line-height: 1.5; }
            .panel { background: white; border: 1px solid #d8dee4; border-radius: 8px; padding: 20px; }
            label { display: block; color: #5b6871; font-weight: 700; margin-bottom: 8px; }
            input { width: 100%; box-sizing: border-box; min-height: 48px; border-radius: 8px; border: 1px solid #b7c5c8; padding: 0 14px; font-size: 24px; letter-spacing: 0.08em; text-transform: uppercase; }
            button { width: 100%; min-height: 48px; margin-top: 14px; border: 0; border-radius: 8px; background: #082032; color: #ffe8b7; font-weight: 800; font-size: 16px; }
            .hint { font-size: 13px; }
          </style>
        </head>
        <body>
          <main>
            <h1>EZCopy Receiver</h1>
            <p>Enter the 6-character access code shown on the iPhone app.</p>
            <section class="panel">
              <form method="get" action="/">
                <label for="code">Access Code</label>
                <input id="code" name="code" autocomplete="one-time-code" autocapitalize="characters" maxlength="6" placeholder="ABC123" required>
                <button type="submit">Continue</button>
              </form>
              <p class="hint">This session expires at \(Self.escapeHTML(expiresText)).</p>
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func statusHTML() -> String {
        let rows = media.map { item in
            """
            <tr>
              <td>\(Self.escapeHTML(item.originalName))</td>
              <td>\(item.mediaType.label)</td>
              <td>\(Self.escapeHTML(item.detailText))</td>
              <td>Pending</td>
            </tr>
            """
        }.joined()
        let codeQuery = sessionCode.map { "code=\($0)" } ?? ""
        let primaryAction = media.isEmpty
            ? "<span class=\"disabledButton\">No Media Selected</span>"
            : "<a class=\"button\" href=\"/archive.zip?\(codeQuery)\">Download EZCopy Package</a>"
        let expiresText = sessionExpiresAt.map { Self.sessionTimeFormatter.string(from: $0) } ?? "-"

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>EZCopy Receiver</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #172026; background: #f4f7f6; }
            main { max-width: 1080px; margin: 0 auto; }
            header { margin-bottom: 24px; }
            h1 { margin: 0; font-size: 32px; }
            p { color: #5b6871; }
            .panel { background: white; border: 1px solid #d8dee4; border-radius: 8px; padding: 20px; }
            .actions { display: flex; gap: 12px; align-items: center; justify-content: space-between; margin: 18px 0; }
            .button, .disabledButton { display: inline-flex; align-items: center; justify-content: center; border-radius: 8px; min-height: 42px; padding: 0 16px; text-decoration: none; font-weight: 700; white-space: nowrap; }
            .button { background: #126f74; color: white; }
            .disabledButton { background: #8ba1a3; color: white; }
            table { width: 100%; border-collapse: collapse; margin-top: 16px; }
            th, td { text-align: left; border-bottom: 1px solid #d8dee4; padding: 10px 8px; }
            th { color: #5b6871; font-size: 13px; }
            a { color: #126f74; font-weight: 700; }
            .status { font-weight: 700; color: #5b6871; }
            .ok { color: #17663a; }
            .active { color: #1b5ea8; }
            .error { color: #9e2f20; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>EZCopy Receiver</h1>
              <p>Your browser is connected to the iPhone app over local Wi-Fi. Download one transfer package that includes the selected media, metadata\(includeMD5Checksums ? ", MD5 checksums," : ",") and an EZCopy report.</p>
            </header>
            <section class="panel">
              <strong>Selected media: \(media.count)</strong>
              <div class="actions">
                <span id="supportText">Chrome or Edge will save the package with the browser download flow.</span>
                \(primaryAction)
              </div>
              <p>Transfer path: browser downloads from this iPhone Wi-Fi address. This secure session code expires at \(Self.escapeHTML(expiresText)). EZCopy blocks cellular transfer in the app and will not pull iCloud-only originals over the network.</p>
              <p><a href="/manifest.json?\(codeQuery)">View manifest JSON</a></p>
              <table>
                <thead>
                  <tr>
                    <th>File</th>
                    <th>Type</th>
                    <th>Details</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  \(rows)
                </tbody>
              </table>
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func manifestJSON() -> String {
        let manifest = makeManifest(sessionId: "EZCopy_\(Self.fileSafeDateFormatter.string(from: Date()))", archiveFiles: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(manifest),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private func makeManifest(sessionId: String, archiveFiles: [ArchiveMediaFile]?) -> ServerManifest {
        let files: [ServerManifestFile]

        if let archiveFiles {
            files = archiveFiles.map { file in
                ServerManifestFile(
                    id: file.item.assetIdentifier ?? file.item.id,
                    originalName: file.item.originalName,
                    relativePath: file.relativePath,
                    mediaType: file.item.mediaType.rawValue,
                    mimeType: file.item.mediaType == .photo ? "image/*" : "video/*",
                    size: Int64(file.metrics.size),
                    createdAt: file.item.createdAt.map(Self.isoDateFormatter.string(from:)),
                    duration: file.item.duration,
                    pixelWidth: file.item.pixelWidth,
                    pixelHeight: file.item.pixelHeight,
                    detailText: file.item.detailText,
                    sourceMd5: file.metrics.md5,
                    order: file.order
                )
            }
        } else {
            files = media.enumerated().map { index, item in
                ServerManifestFile(
                    id: item.assetIdentifier ?? item.id,
                    originalName: item.originalName,
                    relativePath: "\(item.mediaType == .photo ? "Photos" : "Videos")/\(item.originalName)",
                    mediaType: item.mediaType.rawValue,
                    mimeType: item.mediaType == .photo ? "image/*" : "video/*",
                    size: nil,
                    createdAt: item.createdAt.map(Self.isoDateFormatter.string(from:)),
                    duration: item.duration,
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight,
                    detailText: item.detailText,
                    sourceMd5: nil,
                    order: index
                )
            }
        }

        return ServerManifest(
            app: "EZCopy",
            schemaVersion: 1,
            sessionId: sessionId,
            deviceName: UIDevice.current.name,
            createdAt: Self.isoDateFormatter.string(from: Date()),
            files: files
        )
    }

    private func createArchive(completion: @escaping (Result<ArchiveFile, Error>) -> Void) {
        let sessionId = "EZCopy_\(Self.fileSafeDateFormatter.string(from: Date()))"
        let selectedMedia = media

        guard !selectedMedia.isEmpty else {
            completion(.failure(TransferServerError.noMediaSelected))
            return
        }

        exportArchiveMedia(selectedMedia) { result in
            switch result {
            case .success(let archiveMediaFiles):
                do {
                    let manifest = self.makeManifest(sessionId: sessionId, archiveFiles: archiveMediaFiles)
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let manifestData = try encoder.encode(manifest)
                    let reportData = Data(self.makeReportHTML(manifest: manifest).utf8)
                    let archiveDirectory = Self.archiveRootDirectory
                    try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
                    let archiveURL = archiveDirectory.appendingPathComponent("\(sessionId).zip")
                    if FileManager.default.fileExists(atPath: archiveURL.path) {
                        try FileManager.default.removeItem(at: archiveURL)
                    }

                    var entries = archiveMediaFiles.map { file in
                        ZipEntry(
                            path: "\(sessionId)/\(file.relativePath)",
                            source: .file(file.exported.url),
                            size: file.metrics.size,
                            crc32: file.metrics.crc32,
                            modificationDate: file.item.createdAt ?? Date()
                        )
                    }
                    entries.append(try ZipEntry(path: "\(sessionId)/EZCopy_Manifest.json", data: manifestData))
                    if self.includeMD5Checksums {
                        let checksumsData = Data(self.makeChecksumsText(from: archiveMediaFiles).utf8)
                        entries.append(try ZipEntry(path: "\(sessionId)/EZCopy_Checksums.md5", data: checksumsData))
                    }
                    entries.append(try ZipEntry(path: "\(sessionId)/EZCopy_Report.html", data: reportData))

                    let totalPayloadBytes = entries.reduce(UInt64(0)) { $0 + $1.size }
                    DispatchQueue.main.async {
                        self.transferProgress = TransferProgress(
                            filename: "\(sessionId).zip",
                            phase: "Building transfer package",
                            completedBytes: 0,
                            totalBytes: Int64(totalPayloadBytes),
                            fractionCompleted: 0
                        )
                    }

                    try ZipArchiveWriter.write(entries: entries, to: archiveURL) { written, total, currentPath in
                        DispatchQueue.main.async {
                            self.transferProgress = TransferProgress(
                                filename: currentPath,
                                phase: "Building transfer package",
                                completedBytes: Int64(written),
                                totalBytes: Int64(total),
                                fractionCompleted: total > 0 ? Double(written) / Double(total) : nil
                            )
                        }
                    }

                    DispatchQueue.main.async {
                        self.refreshCacheUsage()
                    }

                    completion(.success(ArchiveFile(url: archiveURL, filename: "\(sessionId).zip")))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func exportArchiveMedia(_ selectedMedia: [SelectedMedia], completion: @escaping (Result<[ArchiveMediaFile], Error>) -> Void) {
        var archiveFiles: [ArchiveMediaFile] = []
        var usedPaths = Set<String>()

        func exportNext(index: Int) {
            guard index < selectedMedia.count else {
                completion(.success(archiveFiles))
                return
            }

            let item = selectedMedia[index]
            exportMedia(item) { result in
                switch result {
                case .success(let exported):
                    do {
                        if self.includeMD5Checksums {
                            DispatchQueue.main.async {
                                self.transferProgress = TransferProgress(
                                    filename: item.originalName,
                                    phase: "Calculating MD5",
                                    completedBytes: 0,
                                    totalBytes: nil,
                                    fractionCompleted: nil
                                )
                            }
                        }
                        let metrics = try Self.fileMetrics(for: exported.url, includeMD5: self.includeMD5Checksums)
                        let relativePath = Self.uniqueRelativePath(for: item, usedPaths: &usedPaths)
                        archiveFiles.append(ArchiveMediaFile(order: index, item: item, exported: exported, relativePath: relativePath, metrics: metrics))
                        exportNext(index: index + 1)
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        exportNext(index: 0)
    }

    private func makeChecksumsText(from files: [ArchiveMediaFile]) -> String {
        files
            .sorted { $0.order < $1.order }
            .compactMap { file in
                file.metrics.md5.map { "\($0)  \(file.relativePath)" }
            }
            .joined(separator: "\n") + "\n"
    }

    private func makeReportHTML(manifest: ServerManifest) -> String {
        let rows = manifest.files.map { file in
            """
            <tr>
              <td>\(Self.escapeHTML(file.relativePath))</td>
              <td>\(Self.escapeHTML(file.mediaType))</td>
              <td>\(file.size.map { Self.formatBytes($0) } ?? "-")</td>
              <td>\(Self.escapeHTML(file.duration.map { Self.formatDuration($0) } ?? "-"))</td>
              <td>\(Self.escapeHTML(file.sourceMd5 ?? "Not enabled"))</td>
            </tr>
            """
        }.joined()

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>EZCopy DIT Report</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #172026; }
            table { width: 100%; border-collapse: collapse; }
            th, td { text-align: left; border-bottom: 1px solid #d8dee4; padding: 8px; }
            th { color: #5b6871; }
          </style>
        </head>
        <body>
          <h1>EZCopy DIT Report</h1>
          <p>Device: \(Self.escapeHTML(manifest.deviceName))</p>
          <p>Session: \(Self.escapeHTML(manifest.sessionId))</p>
          <p>Created: \(Self.escapeHTML(manifest.createdAt))</p>
          <p>Files: \(manifest.files.count)</p>
          <table>
            <thead>
              <tr>
                <th>Path</th>
                <th>Type</th>
                <th>Size</th>
                <th>Duration</th>
                <th>MD5</th>
              </tr>
            </thead>
            <tbody>
              \(rows)
            </tbody>
          </table>
        </body>
        </html>
        """
    }

    private func exportMedia(_ item: SelectedMedia, completion: @escaping (Result<ExportedFile, Error>) -> Void) {
        guard let identifier = item.assetIdentifier else {
            completion(.failure(TransferServerError.missingAssetIdentifier))
            return
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            completion(.failure(TransferServerError.assetNotFound))
            return
        }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = preferredResource(from: resources, mediaType: item.mediaType) else {
            completion(.failure(TransferServerError.resourceNotFound))
            return
        }

        let exportDirectory = Self.exportRootDirectory
            .appendingPathComponent(Self.safePathComponent(identifier), isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        } catch {
            completion(.failure(error))
            return
        }

        let fileURL = exportDirectory.appendingPathComponent(Self.safeFilename(item.originalName))
        if FileManager.default.fileExists(atPath: fileURL.path) {
            completion(.success(ExportedFile(url: fileURL, filename: item.originalName, mediaType: item.mediaType)))
            return
        }

        DispatchQueue.main.async {
            self.transferProgress = TransferProgress(
                filename: item.originalName,
                phase: "Preparing local original",
                completedBytes: 0,
                totalBytes: nil,
                fractionCompleted: 0
            )
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        options.progressHandler = { progress in
            DispatchQueue.main.async {
                self.transferProgress = TransferProgress(
                    filename: item.originalName,
                    phase: "Exporting from Photos",
                    completedBytes: nil,
                    totalBytes: nil,
                    fractionCompleted: progress
                )
            }
        }

        PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(ExportedFile(url: fileURL, filename: item.originalName, mediaType: item.mediaType)))
            }
        }
    }

    private func preferredResource(from resources: [PHAssetResource], mediaType: MediaType) -> PHAssetResource? {
        switch mediaType {
        case .photo:
            return resources.first { $0.type == .photo || $0.type == .fullSizePhoto } ?? resources.first
        case .video:
            return resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        }
    }

    private func streamFile(_ exportedFile: ExportedFile, on connection: NWConnection) {
        streamFile(url: exportedFile.url, filename: exportedFile.filename, contentType: "application/octet-stream", deleteOnCompletion: nil, on: connection)
    }

    private func streamFile(url: URL, filename: String, contentType: String, deleteOnCompletion: URL?, on connection: NWConnection) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let encodedFilename = Self.escapeHeaderValue(filename)
            let header = """
            HTTP/1.1 200 OK\r
            Content-Type: \(contentType)\r
            Content-Length: \(fileSize)\r
            Content-Disposition: attachment; filename="\(encodedFilename)"\r
            Access-Control-Allow-Origin: *\r
            Access-Control-Allow-Methods: GET, OPTIONS\r
            Access-Control-Allow-Headers: Content-Type\r
            Access-Control-Expose-Headers: Content-Length, Content-Disposition\r
            Cache-Control: no-store\r
            Connection: close\r
            \r

            """
            let fileHandle = try FileHandle(forReadingFrom: url)

            DispatchQueue.main.async {
                self.transferProgress = TransferProgress(
                    filename: filename,
                    phase: "Sending to browser",
                    completedBytes: 0,
                    totalBytes: fileSize,
                    fractionCompleted: 0
                )
            }

            connection.send(content: Data(header.utf8), completion: .contentProcessed { error in
                if error != nil {
                    try? fileHandle.close()
                    self.cleanupTemporaryDownload(deleteOnCompletion)
                    connection.cancel()
                    return
                }
                self.sendFileChunk(from: fileHandle, sentBytes: 0, totalBytes: fileSize, filename: filename, deleteOnCompletion: deleteOnCompletion, on: connection)
            })
        } catch {
            sendError(error.localizedDescription, status: "500 Internal Server Error", on: connection)
        }
    }

    private func sendFileChunk(from fileHandle: FileHandle, sentBytes: Int64, totalBytes: Int64, filename: String, deleteOnCompletion: URL?, on connection: NWConnection) {
        let chunk = fileHandle.readData(ofLength: 1024 * 1024)

        guard !chunk.isEmpty else {
            try? fileHandle.close()
            cleanupTemporaryDownload(deleteOnCompletion)
            DispatchQueue.main.async {
                self.transferProgress = TransferProgress(
                    filename: filename,
                    phase: "Sent",
                    completedBytes: totalBytes,
                    totalBytes: totalBytes,
                    fractionCompleted: 1
                )
            }
            connection.cancel()
            return
        }

        connection.send(content: chunk, completion: .contentProcessed { error in
            if error != nil {
                try? fileHandle.close()
                self.cleanupTemporaryDownload(deleteOnCompletion)
                connection.cancel()
                return
            }
            let nextSentBytes = sentBytes + Int64(chunk.count)
            DispatchQueue.main.async {
                self.transferProgress = TransferProgress(
                    filename: filename,
                    phase: "Sending to browser",
                    completedBytes: nextSentBytes,
                    totalBytes: totalBytes,
                    fractionCompleted: totalBytes > 0 ? Double(nextSentBytes) / Double(totalBytes) : nil
                )
            }
            self.sendFileChunk(from: fileHandle, sentBytes: nextSentBytes, totalBytes: totalBytes, filename: filename, deleteOnCompletion: deleteOnCompletion, on: connection)
        })
    }

    private func cleanupTemporaryDownload(_ url: URL?) {
        guard let url else {
            return
        }

        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.async {
            self.refreshCacheUsage()
        }
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escapeHeaderValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
    }

    private static func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = value.components(separatedBy: invalid)
        let filename = components.joined(separator: "_")
        return filename.isEmpty ? UUID().uuidString : filename
    }

    private static func safePathComponent(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func makeSessionCode() -> String {
        let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        var bytes = [UInt8](repeating: 0, count: 6)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if result == errSecSuccess {
            return bytes
                .map { String(alphabet[Int($0) % alphabet.count]) }
                .joined()
        }

        return String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }

    private static var exportRootDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("EZCopyExports", isDirectory: true)
    }

    private static var archiveRootDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("EZCopyArchives", isDirectory: true)
    }

    private static func removeCacheDirectories() throws {
        for directory in [exportRootDirectory, archiveRootDirectory] where FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private static func cacheSize() -> UInt64 {
        [exportRootDirectory, archiveRootDirectory].reduce(UInt64(0)) { total, directory in
            total + directorySize(directory)
        }
    }

    private static func directorySize(_ directory: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else {
                continue
            }
            total += UInt64(values?.fileSize ?? 0)
        }
        return total
    }

    private static func uniqueRelativePath(for item: SelectedMedia, usedPaths: inout Set<String>) -> String {
        let folder = item.mediaType == .photo ? "Photos" : "Videos"
        let filename = safeFilename(item.originalName)
        let baseURL = URL(fileURLWithPath: filename)
        let name = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension

        var candidate = "\(folder)/\(filename)"
        var suffix = 2

        while usedPaths.contains(candidate) {
            let nextFilename = ext.isEmpty ? "\(name)-\(suffix)" : "\(name)-\(suffix).\(ext)"
            candidate = "\(folder)/\(nextFilename)"
            suffix += 1
        }

        usedPaths.insert(candidate)
        return candidate
    }

    private static func fileMetrics(for url: URL, includeMD5: Bool) throws -> FileMetrics {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = UInt64((attributes[.size] as? NSNumber)?.int64Value ?? 0)

        guard includeMD5 else {
            return FileMetrics(size: size, crc32: nil, md5: nil)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var md5 = Insecure.MD5()
        var crc32 = CRC32()

        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty {
                break
            }
            md5.update(data: chunk)
            crc32.update(with: chunk)
        }

        let digest = md5.finalize().map { String(format: "%02x", $0) }.joined()
        return FileMetrics(size: size, crc32: crc32.finalize(), md5: digest)
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0

        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }

        if index == 0 {
            return "\(Int(value)) B"
        }

        return String(format: value >= 10 ? "%.1f %@" : "%.2f %@", value, units[index])
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fileSafeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    private static let sessionTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct TransferProgress: Equatable {
    let filename: String
    let phase: String
    let completedBytes: Int64?
    let totalBytes: Int64?
    let fractionCompleted: Double?

    var percentageText: String {
        guard let fractionCompleted else {
            return "-"
        }

        return "\(Int((fractionCompleted * 100).rounded()))%"
    }

    var detailText: String {
        if let completedBytes, let totalBytes, totalBytes > 0 {
            return "\(Self.formatBytes(completedBytes)) / \(Self.formatBytes(totalBytes))"
        }

        return percentageText
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0

        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }

        if index == 0 {
            return "\(Int(value)) B"
        }

        return String(format: value >= 10 ? "%.1f %@" : "%.2f %@", value, units[index])
    }
}

private struct RequestTarget {
    let method: String
    let path: String
    let query: [String: String]
}

private struct ExportedFile {
    let url: URL
    let filename: String
    let mediaType: MediaType
}

private struct ArchiveFile {
    let url: URL
    let filename: String
}

private struct ArchiveMediaFile {
    let order: Int
    let item: SelectedMedia
    let exported: ExportedFile
    let relativePath: String
    let metrics: FileMetrics
}

private struct FileMetrics {
    let size: UInt64
    let crc32: UInt32?
    let md5: String?
}

private enum TransferServerError: LocalizedError {
    case missingAssetIdentifier
    case assetNotFound
    case resourceNotFound
    case noMediaSelected

    var errorDescription: String? {
        switch self {
        case .missingAssetIdentifier:
            return "The selected media does not include a Photos asset identifier."
        case .assetNotFound:
            return "The selected media could not be found in the Photos library."
        case .resourceNotFound:
            return "The original media resource could not be found."
        case .noMediaSelected:
            return "No media is selected for the transfer package."
        }
    }
}

private struct ServerManifest: Encodable {
    let app: String
    let schemaVersion: Int
    let sessionId: String
    let deviceName: String
    let createdAt: String
    let files: [ServerManifestFile]
}

private struct ServerManifestFile: Encodable {
    let id: String
    let originalName: String
    let relativePath: String
    let mediaType: String
    let mimeType: String
    let size: Int64?
    let createdAt: String?
    let duration: TimeInterval?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let detailText: String
    let sourceMd5: String?
    let order: Int
}

private enum ZipEntrySource {
    case file(URL)
    case data(Data)
}

private struct ZipEntry {
    let path: String
    let source: ZipEntrySource
    let size: UInt64
    let crc32: UInt32?
    let modificationDate: Date

    init(path: String, source: ZipEntrySource, size: UInt64, crc32: UInt32?, modificationDate: Date) {
        self.path = path
        self.source = source
        self.size = size
        self.crc32 = crc32
        self.modificationDate = modificationDate
    }

    init(path: String, data: Data) throws {
        var crc32 = CRC32()
        crc32.update(with: data)
        self.init(path: path, source: .data(data), size: UInt64(data.count), crc32: crc32.finalize(), modificationDate: Date())
    }
}

private struct ZipArchiveWriter {
    struct CentralDirectoryEntry {
        let entry: ZipEntry
        let offset: UInt64
        let crc32: UInt32
    }

    static func write(entries: [ZipEntry], to url: URL, progress: (UInt64, UInt64, String) -> Void) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        let totalPayloadBytes = entries.reduce(UInt64(0)) { $0 + $1.size }
        var writtenPayloadBytes: UInt64 = 0
        var offset: UInt64 = 0
        var centralEntries: [CentralDirectoryEntry] = []

        for entry in entries {
            let entryOffset = offset
            let localHeader = localHeader(for: entry)
            handle.write(localHeader)
            offset += UInt64(localHeader.count)
            var computedCRC32 = CRC32()

            switch entry.source {
            case .data(let data):
                handle.write(data)
                if entry.crc32 == nil {
                    computedCRC32.update(with: data)
                }
                offset += UInt64(data.count)
                writtenPayloadBytes += UInt64(data.count)
                progress(writtenPayloadBytes, totalPayloadBytes, entry.path)
            case .file(let fileURL):
                let input = try FileHandle(forReadingFrom: fileURL)
                defer { try? input.close() }

                while true {
                    let chunk = input.readData(ofLength: 1024 * 1024)
                    if chunk.isEmpty {
                        break
                    }
                    handle.write(chunk)
                    if entry.crc32 == nil {
                        computedCRC32.update(with: chunk)
                    }
                    offset += UInt64(chunk.count)
                    writtenPayloadBytes += UInt64(chunk.count)
                    progress(writtenPayloadBytes, totalPayloadBytes, entry.path)
                }
            }

            let crc32 = entry.crc32 ?? computedCRC32.finalize()
            if entry.crc32 == nil {
                let descriptor = dataDescriptor(crc32: crc32, size: entry.size)
                handle.write(descriptor)
                offset += UInt64(descriptor.count)
            }
            centralEntries.append(CentralDirectoryEntry(entry: entry, offset: entryOffset, crc32: crc32))
        }

        let centralDirectoryOffset = offset
        var centralDirectory = Data()
        for centralEntry in centralEntries {
            centralDirectory.append(centralHeader(for: centralEntry.entry, offset: centralEntry.offset, crc32: centralEntry.crc32))
        }
        handle.write(centralDirectory)
        offset += UInt64(centralDirectory.count)

        let centralDirectorySize = UInt64(centralDirectory.count)
        let needsZip64 = centralEntries.count > UInt16.max
            || centralDirectorySize > UInt32.max
            || centralDirectoryOffset > UInt32.max
            || centralEntries.contains { $0.entry.size > UInt32.max || $0.offset > UInt32.max }

        if needsZip64 {
            let zip64EOCDOffset = offset
            let zip64EOCD = zip64EndOfCentralDirectory(
                entryCount: UInt64(centralEntries.count),
                centralDirectorySize: centralDirectorySize,
                centralDirectoryOffset: centralDirectoryOffset
            )
            handle.write(zip64EOCD)
            offset += UInt64(zip64EOCD.count)

            let locator = zip64EndOfCentralDirectoryLocator(zip64EOCDOffset: zip64EOCDOffset)
            handle.write(locator)
            offset += UInt64(locator.count)
        }

        handle.write(endOfCentralDirectory(
            entryCount: UInt64(centralEntries.count),
            centralDirectorySize: centralDirectorySize,
            centralDirectoryOffset: centralDirectoryOffset,
            needsZip64: needsZip64
        ))
    }

    private static func localHeader(for entry: ZipEntry) -> Data {
        let name = Data(entry.path.utf8)
        let zip64 = entry.size > UInt32.max
        let usesDataDescriptor = entry.crc32 == nil
        let dateTime = dosDateTime(from: entry.modificationDate)
        var extra = Data()

        if zip64 {
            extra.appendUInt16LE(0x0001)
            extra.appendUInt16LE(16)
            extra.appendUInt64LE(entry.size)
            extra.appendUInt64LE(entry.size)
        }

        var data = Data()
        data.appendUInt32LE(0x04034b50)
        data.appendUInt16LE(zip64 ? 45 : 20)
        data.appendUInt16LE(usesDataDescriptor ? 0x0808 : 0x0800)
        data.appendUInt16LE(0)
        data.appendUInt16LE(dateTime.time)
        data.appendUInt16LE(dateTime.date)
        data.appendUInt32LE(entry.crc32 ?? 0)
        data.appendUInt32LE(usesDataDescriptor ? (zip64 ? UInt32.max : 0) : (zip64 ? UInt32.max : UInt32(entry.size)))
        data.appendUInt32LE(usesDataDescriptor ? (zip64 ? UInt32.max : 0) : (zip64 ? UInt32.max : UInt32(entry.size)))
        data.appendUInt16LE(UInt16(name.count))
        data.appendUInt16LE(UInt16(extra.count))
        data.append(name)
        data.append(extra)
        return data
    }

    private static func centralHeader(for entry: ZipEntry, offset: UInt64, crc32: UInt32) -> Data {
        let name = Data(entry.path.utf8)
        let zip64Size = entry.size > UInt32.max
        let zip64Offset = offset > UInt32.max
        let zip64 = zip64Size || zip64Offset
        let usesDataDescriptor = entry.crc32 == nil
        let dateTime = dosDateTime(from: entry.modificationDate)
        var extra = Data()

        if zip64 {
            extra.appendUInt16LE(0x0001)
            extra.appendUInt16LE(UInt16((zip64Size ? 16 : 0) + (zip64Offset ? 8 : 0)))
            if zip64Size {
                extra.appendUInt64LE(entry.size)
                extra.appendUInt64LE(entry.size)
            }
            if zip64Offset {
                extra.appendUInt64LE(offset)
            }
        }

        var data = Data()
        data.appendUInt32LE(0x02014b50)
        data.appendUInt16LE(zip64 ? 45 : 20)
        data.appendUInt16LE(zip64 ? 45 : 20)
        data.appendUInt16LE(usesDataDescriptor ? 0x0808 : 0x0800)
        data.appendUInt16LE(0)
        data.appendUInt16LE(dateTime.time)
        data.appendUInt16LE(dateTime.date)
        data.appendUInt32LE(crc32)
        data.appendUInt32LE(zip64Size ? UInt32.max : UInt32(entry.size))
        data.appendUInt32LE(zip64Size ? UInt32.max : UInt32(entry.size))
        data.appendUInt16LE(UInt16(name.count))
        data.appendUInt16LE(UInt16(extra.count))
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(0)
        data.appendUInt32LE(zip64Offset ? UInt32.max : UInt32(offset))
        data.append(name)
        data.append(extra)
        return data
    }

    private static func dataDescriptor(crc32: UInt32, size: UInt64) -> Data {
        var data = Data()
        data.appendUInt32LE(0x08074b50)
        data.appendUInt32LE(crc32)

        if size > UInt32.max {
            data.appendUInt64LE(size)
            data.appendUInt64LE(size)
        } else {
            data.appendUInt32LE(UInt32(size))
            data.appendUInt32LE(UInt32(size))
        }

        return data
    }

    private static func zip64EndOfCentralDirectory(entryCount: UInt64, centralDirectorySize: UInt64, centralDirectoryOffset: UInt64) -> Data {
        var data = Data()
        data.appendUInt32LE(0x06064b50)
        data.appendUInt64LE(44)
        data.appendUInt16LE(45)
        data.appendUInt16LE(45)
        data.appendUInt32LE(0)
        data.appendUInt32LE(0)
        data.appendUInt64LE(entryCount)
        data.appendUInt64LE(entryCount)
        data.appendUInt64LE(centralDirectorySize)
        data.appendUInt64LE(centralDirectoryOffset)
        return data
    }

    private static func zip64EndOfCentralDirectoryLocator(zip64EOCDOffset: UInt64) -> Data {
        var data = Data()
        data.appendUInt32LE(0x07064b50)
        data.appendUInt32LE(0)
        data.appendUInt64LE(zip64EOCDOffset)
        data.appendUInt32LE(1)
        return data
    }

    private static func endOfCentralDirectory(entryCount: UInt64, centralDirectorySize: UInt64, centralDirectoryOffset: UInt64, needsZip64: Bool) -> Data {
        var data = Data()
        data.appendUInt32LE(0x06054b50)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(needsZip64 ? UInt16.max : UInt16(entryCount))
        data.appendUInt16LE(needsZip64 ? UInt16.max : UInt16(entryCount))
        data.appendUInt32LE(needsZip64 ? UInt32.max : UInt32(centralDirectorySize))
        data.appendUInt32LE(needsZip64 ? UInt32.max : UInt32(centralDirectoryOffset))
        data.appendUInt16LE(0)
        return data
    }

    private static func dosDateTime(from date: Date) -> (date: UInt16, time: UInt16) {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max(components.year ?? 1980, 1980), 2107)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2
        let dosDate = UInt16((year - 1980) << 9 | month << 5 | day)
        let dosTime = UInt16(hour << 11 | minute << 5 | second)
        return (dosDate, dosTime)
    }
}

private struct CRC32 {
    private static let table: [UInt32] = (0...255).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = 0xedb88320 ^ (crc >> 1)
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    private var value: UInt32 = 0xffffffff

    mutating func update(with data: Data) {
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            for index in 0..<buffer.count {
                let byte = baseAddress[index]
                let tableIndex = Int((value ^ UInt32(byte)) & 0xff)
                value = Self.table[tableIndex] ^ (value >> 8)
            }
        }
    }

    func finalize() -> UInt32 {
        value ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }

    mutating func appendUInt64LE(_ value: UInt64) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 32) & 0xff))
        append(UInt8((value >> 40) & 0xff))
        append(UInt8((value >> 48) & 0xff))
        append(UInt8((value >> 56) & 0xff))
    }
}

private enum LocalNetworkAddress {
    static func wiFiIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var pointer = interfaces

        while pointer != nil {
            guard let interface = pointer?.pointee else {
                break
            }

            defer { pointer = interface.ifa_next }

            let address = interface.ifa_addr.pointee
            guard address.sa_family == UInt8(AF_INET) else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else {
                continue
            }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(address.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            let ipAddress = String(cString: host)

            if name == "en0" {
                return ipAddress
            }
        }

        return nil
    }
}
