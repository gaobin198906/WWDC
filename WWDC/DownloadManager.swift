//
//  DownloadManager.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import ConfCore
import RealmSwift
import os.log

extension Notification.Name {

    static let DownloadManagerFileAddedNotification = Notification.Name("DownloadManagerFileAddedNotification")
    static let DownloadManagerFileDeletedNotification = Notification.Name("DownloadManagerFileDeletedNotification")
    static let DownloadManagerDownloadStarted = Notification.Name("DownloadManagerDownloadStarted")
    static let DownloadManagerDownloadCancelled = Notification.Name("DownloadManagerDownloadCancelled")
    static let DownloadManagerDownloadPaused = Notification.Name("DownloadManagerDownloadPaused")
    static let DownloadManagerDownloadResumed = Notification.Name("DownloadManagerDownloadResumed")
    static let DownloadManagerDownloadFailed = Notification.Name("DownloadManagerDownloadFailed")
    static let DownloadManagerDownloadFinished = Notification.Name("DownloadManagerDownloadFinished")
    static let DownloadManagerDownloadProgressChanged = Notification.Name("DownloadManagerDownloadProgressChanged")

}

enum DownloadStatus {
    case none
    case downloading(DownloadManager.DownloadInfo)
    case paused
    case cancelled
    case finished
    case failed(Error?)
}

extension URL {

    var isDirectory: Bool {
        guard isFileURL else { return false }
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory) ? directory.boolValue : false
    }

    var subDirectories: [URL] {
        guard isDirectory else { return [] }
        return (try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { $0.isDirectory }) ?? []
    }

}

final class DownloadManager: NSObject {

    // Changing this dynamically isn't supported. Delete all downloads when switching
    // from one quality to another otherwise you'll encounter minor unexpected behavior
    static let downloadQuality = SessionAssetType.hdVideo

    struct Download {
        let session: SessionIdentifier
        fileprivate var remoteURL: String
        fileprivate weak var task: URLSessionDownloadTask?

        func pause() {
            guard let task = task else { return }
            task.suspend()
            NotificationCenter.default.post(name: .DownloadManagerDownloadPaused, object: remoteURL)
        }

        func resume() {
            guard let task = task else { return }
            task.resume()
            NotificationCenter.default.post(name: .DownloadManagerDownloadResumed, object: remoteURL)
        }

        func cancel() {
            guard let task = task else { return }
            task.cancel()
        }

        var state: URLSessionTask.State {
            return task?.state ?? .canceling
        }

        static func < (lhs: Download, rhs: Download) -> Bool {
            guard let left = lhs.task, let right = rhs.task else { return false }

            switch (left.countOfBytesExpectedToReceive, right.countOfBytesExpectedToReceive) {
            case (0, _):
                return false
            case (_, 0):
                return true
            default:
                return left.taskIdentifier < right.taskIdentifier
            }
        }
    }

    private let log = OSLog(subsystem: "WWDC", category: "DownloadManager")
    private let configuration = URLSessionConfiguration.background(withIdentifier: "WWDC Video Downloader")
    private var backgroundSession: Foundation.URLSession!
    private var downloadTasks: [String: Download] = [:] {
        didSet {
            downloadTasksSubject.onNext(Array(downloadTasks.values))
        }
    }
    private let downloadTasksSubject = BehaviorSubject<[Download]>(value: [])
    var downloadsObservable: Observable<[Download]> {
        return downloadTasksSubject.asObservable()
    }
    private let defaults = UserDefaults.standard

    var storage: Storage!

    static let shared: DownloadManager = DownloadManager()

    override init() {
        super.init()

        backgroundSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }

    // MARK: - Public API

    func start(with storage: Storage) {
        self.storage = storage

        backgroundSession.getTasksWithCompletionHandler { _, _, pendingTasks in
            for task in pendingTasks {
                if let key = task.originalRequest?.url!.absoluteString,
                    let remoteURL = URL(string: key),
                    let asset = storage.asset(with: remoteURL),
                    let session = asset.session.first {

                    self.downloadTasks[key] = Download(session: SessionIdentifier(session.identifier), remoteURL: key, task: task)
                } else {
                    // We have a task that is not associated with a session at all, lets cancel it
                    task.cancel()
                }
            }
        }

        _ = NotificationCenter.default.addObserver(forName: .LocalVideoStoragePathPreferenceDidChange, object: nil, queue: nil) { _ in
            self.monitorDownloadsFolder()
        }

        updateDownloadedFlagsOfPreviouslyDownloaded()
        monitorDownloadsFolder()
    }

    func download(_ session: Session) {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return }

        let url = asset.remoteURL

        if isDownloading(url) || hasVideo(url) {
            return
        }

        let task = backgroundSession.downloadTask(with: URL(string: url)!)
        if let key = task.originalRequest?.url!.absoluteString {
            downloadTasks[key] = Download(session: SessionIdentifier(session.identifier), remoteURL: key, task: task)
            task.resume()
            NotificationCenter.default.post(name: .DownloadManagerDownloadStarted, object: url)
        } else {
            NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: url)
        }
    }

    private func pauseDownload(_ url: String) -> Bool {
        if let download = downloadTasks[url] {
            download.pause()
            return true
        }

        os_log("Unable to pause download of %{public}@ because there's no task for that URL",
               log: log,
               type: .error,
               url)

        return false
    }

    func resumeDownload(_ url: String) -> Bool {
        if let download = downloadTasks[url] {
            download.resume()
            return true
        }

        os_log("Unable to resume download of %{public}@ because there's no task for that URL",
               log: log,
               type: .error,
               url)

        return false
    }

    func cancelDownload(_ session: Session) -> Bool {
        guard let url = session.asset(ofType: DownloadManager.downloadQuality)?.remoteURL else { return false }

        return cancelDownload(url)
    }

    func isDownloading(_ session: Session) -> Bool {
        guard let url = session.asset(ofType: DownloadManager.downloadQuality)?.remoteURL else { return false }

        return isDownloading(url)
    }

    func downloadedFileURL(for session: Session) -> URL? {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return nil }

        let path = localStoragePath(for: asset)

        guard FileManager.default.fileExists(atPath: path) else { return nil }

        return URL(fileURLWithPath: path)
    }

    func hasVideo(_ session: Session) -> Bool {
        guard let url = session.asset(ofType: DownloadManager.downloadQuality)?.remoteURL else { return false }

        return hasVideo(url)
    }

    func deleteDownloadedFile(for session: Session) {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return }

        do {
            try removeDownload(asset.remoteURL)
        } catch {
            WWDCAlert.show(with: error)
        }
    }

    func downloadStatusObservable(for download: Download) -> Observable<DownloadStatus>? {
        guard let downloadingAsset = storage.asset(with: URL(string: download.remoteURL)!) else { return nil }

        return downloadStatusObservable(for: downloadingAsset)
    }

    func downloadStatusObservable(for session: Session) -> Observable<DownloadStatus>? {
        guard let asset = session.asset(ofType: DownloadManager.downloadQuality) else { return nil }

        return downloadStatusObservable(for: asset)
    }

    func downloadStatusObservable(for asset: SessionAsset) -> Observable<DownloadStatus>? {

        return Observable<DownloadStatus>.create { observer -> Disposable in
            let nc = NotificationCenter.default
            var latestInfo: DownloadInfo = .unknown

            let checkDownloadedState = {
                if let download = self.downloadTasks[asset.remoteURL] {

                    if let task = download.task {
                        latestInfo = DownloadInfo(task: task)
                    }

                    observer.onNext(.downloading(latestInfo))
                } else if self.hasVideo(asset.remoteURL) {
                    observer.onNext(.finished)
                } else {
                    observer.onNext(.none)
                }
            }

            checkDownloadedState()

            let fileDeleted = nc.dm_addObserver(forName: .DownloadManagerFileDeletedNotification, filteredBy: asset.relativeLocalURL) { _ in

                observer.onNext(.none)
            }

            let fileAdded = nc.dm_addObserver(forName: .DownloadManagerFileAddedNotification, filteredBy: asset.relativeLocalURL) { _ in

                observer.onNext(.finished)
            }

            let started = nc.dm_addObserver(forName: .DownloadManagerDownloadStarted, filteredBy: asset.remoteURL) { _ in

                observer.onNext(.downloading(.unknown))
            }

            let cancelled = nc.dm_addObserver(forName: .DownloadManagerDownloadCancelled, filteredBy: asset.remoteURL) { _ in

                observer.onNext(.cancelled)
            }

            let paused = nc.dm_addObserver(forName: .DownloadManagerDownloadPaused, filteredBy: asset.remoteURL) { _ in

                observer.onNext(.paused)
            }

            let resumed = nc.dm_addObserver(forName: .DownloadManagerDownloadResumed, filteredBy: asset.remoteURL) { _ in

                observer.onNext(.downloading(latestInfo))
            }

            let failed = nc.dm_addObserver(forName: .DownloadManagerDownloadFailed, filteredBy: asset.remoteURL) { note in

                let error = note.userInfo?["error"] as? Error
                observer.onNext(.failed(error))
            }

            let finished = nc.dm_addObserver(forName: .DownloadManagerDownloadFinished, filteredBy: asset.remoteURL) { _ in

                observer.onNext(.finished)
            }

            let progress = nc.dm_addObserver(forName: .DownloadManagerDownloadProgressChanged, filteredBy: asset.remoteURL) { note in

                if let info = note.userInfo?["info"] as? DownloadInfo {
                    latestInfo = info
                    observer.onNext(.downloading(info))
                } else {
                    observer.onNext(.downloading(.unknown))
                }
            }

            return Disposables.create {
                [fileDeleted, fileAdded, started, cancelled,
                 paused, resumed, failed, finished, progress].forEach(nc.removeObserver)
            }
        }
    }

    // MARK: - URL-based Internal API

    fileprivate func localStoragePath(for asset: SessionAsset) -> String {
        return Preferences.shared.localVideoStorageURL.appendingPathComponent(asset.relativeLocalURL).path
    }

    private func cancelDownload(_ url: String) -> Bool {
        if let download = downloadTasks[url] {
            download.task?.cancel()
            return true
        }

        os_log("Unable to cancel download of %{public}@ because there's no task for that URL",
               log: log,
               type: .error,
               url)

        return false
    }

    private func isDownloading(_ url: String) -> Bool {
        return downloadTasks.keys.contains { $0 == url }
    }

    private func lookupAssetLocalVideoPath(remoteURL: String) -> String? {
        guard let url = URL(string: remoteURL) else { return nil }

        guard let asset = storage.asset(with: url) else {
            return nil
        }

        let path = localStoragePath(for: asset)

        return path
    }

    private func hasVideo(_ url: String) -> Bool {
        guard let path = lookupAssetLocalVideoPath(remoteURL: url) else { return false }

        return FileManager.default.fileExists(atPath: path)
    }

    enum RemoveDownloadError: Error {
        case notDownloaded
        case fileSystem(Error)
        case internalError(String)
    }

    private func removeDownload(_ url: String) throws {
        if isDownloading(url) {
            _ = cancelDownload(url)
            return
        }

        if hasVideo(url) {
            guard let path = lookupAssetLocalVideoPath(remoteURL: url) else {
                throw RemoveDownloadError.internalError("Unable to generate local video path from remote URL")
            }

            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw RemoveDownloadError.fileSystem(error)
            }
        } else {
            throw RemoveDownloadError.notDownloaded
        }
    }

    // MARK: - File observation

    fileprivate var topFolderMonitor: DTFolderMonitor!
    fileprivate var subfoldersMonitors: [DTFolderMonitor] = []
    fileprivate var existingVideoFiles = [String]()

    func syncWithFileSystem() {
        let videosPath = Preferences.shared.localVideoStorageURL.path
        updateDownloadedFlagsByEnumeratingFilesAtPath(videosPath)
    }

    private func monitorDownloadsFolder() {
        if topFolderMonitor != nil {
            topFolderMonitor.stopMonitoring()
            topFolderMonitor = nil
        }

        subfoldersMonitors.forEach({ $0.stopMonitoring() })
        subfoldersMonitors.removeAll()

        let url = Preferences.shared.localVideoStorageURL

        topFolderMonitor = DTFolderMonitor(for: url) { [unowned self] in
            self.setupSubdirectoryMonitors(on: url)

            self.updateDownloadedFlagsByEnumeratingFilesAtPath(url.path)
        }

        setupSubdirectoryMonitors(on: url)

        topFolderMonitor.startMonitoring()
    }

    private func setupSubdirectoryMonitors(on mainDirURL: URL) {
        subfoldersMonitors.forEach({ $0.stopMonitoring() })
        subfoldersMonitors.removeAll()

        mainDirURL.subDirectories.forEach { subdir in
            guard let monitor = DTFolderMonitor(for: subdir, block: { [unowned self] in
                self.updateDownloadedFlagsByEnumeratingFilesAtPath(mainDirURL.path)
            }) else { return }

            subfoldersMonitors.append(monitor)

            monitor.startMonitoring()
        }
    }

    fileprivate func updateDownloadedFlagsOfPreviouslyDownloaded() {
        let expectedOnDisk = storage.sessions.filter(NSPredicate(format: "isDownloaded == true"))
        var notPresent = [String]()

        for session in expectedOnDisk {
            if let asset = session.asset(ofType: DownloadManager.downloadQuality) {
                if !hasVideo(asset.remoteURL) {
                    notPresent.append(asset.relativeLocalURL)
                }
            }
        }

        storage.updateDownloadedFlag(false, forAssetsAtPaths: notPresent)
        notPresent.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }
    }

    /// Updates the downloaded status for the sessions on the database based on the existence of the downloaded video file
    fileprivate func updateDownloadedFlagsByEnumeratingFilesAtPath(_ path: String) {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return }
        guard let files = enumerator.allObjects as? [String] else { return }

        storage.updateDownloadedFlag(true, forAssetsAtPaths: files)

        files.forEach { NotificationCenter.default.post(name: .DownloadManagerFileAddedNotification, object: $0) }

        if existingVideoFiles.count == 0 {
            existingVideoFiles = files
            return
        }

        let removedFiles = existingVideoFiles.filter { !files.contains($0) }

        storage.updateDownloadedFlag(false, forAssetsAtPaths: removedFiles)

        removedFiles.forEach { NotificationCenter.default.post(name: .DownloadManagerFileDeletedNotification, object: $0) }
    }

    // MARK: Teardown

    deinit {
        if topFolderMonitor != nil {
            topFolderMonitor.stopMonitoring()
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url else { return }

        let originalAbsoluteURLString = originalURL.absoluteString

        guard let localPath = lookupAssetLocalVideoPath(remoteURL: originalAbsoluteURLString) else { return }
        let destinationUrl = URL(fileURLWithPath: localPath)
        let destinationDir = destinationUrl.deletingLastPathComponent()

        do {
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
            }

            try FileManager.default.moveItem(at: location, to: destinationUrl)

            downloadTasks.removeValue(forKey: originalAbsoluteURLString)

            NotificationCenter.default.post(name: .DownloadManagerDownloadFinished, object: originalAbsoluteURLString)
        } catch {
            NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: ["error": error])
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let originalURL = task.originalRequest?.url else { return }

        let originalAbsoluteURLString = originalURL.absoluteString

        downloadTasks.removeValue(forKey: originalAbsoluteURLString)

        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                NotificationCenter.default.post(name: .DownloadManagerDownloadCancelled, object: originalAbsoluteURLString)
            } else {
                NotificationCenter.default.post(name: .DownloadManagerDownloadFailed, object: originalAbsoluteURLString, userInfo: ["error": error])
            }
        }
    }

    struct DownloadInfo {
        let totalBytesWritten: Int64
        let totalBytesExpectedToWrite: Int64
        let progress: Double

        init(task: URLSessionTask) {
            totalBytesExpectedToWrite = task.countOfBytesExpectedToReceive
            totalBytesWritten = task.countOfBytesReceived
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }

        init(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, progress: Double) {
            self.totalBytesWritten = totalBytesWritten
            self.totalBytesExpectedToWrite = totalBytesExpectedToWrite
            self.progress = progress
        }

        static let unknown = DownloadInfo(totalBytesWritten: 0, totalBytesExpectedToWrite: 0, progress: -1)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let originalURL = downloadTask.originalRequest?.url?.absoluteString else { return }

        let info = DownloadInfo(task: downloadTask)
        NotificationCenter.default.post(name: .DownloadManagerDownloadProgressChanged, object: originalURL, userInfo: ["info": info])
    }
}

extension NotificationCenter {

    fileprivate func dm_addObserver<T: Equatable>(forName name: NSNotification.Name, filteredBy object: T, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        return self.addObserver(forName: name, object: nil, queue: .main) { note in
            guard object == note.object as? T else { return }

            block(note)
        }
    }
}
