//
//  DownloadsManagementTableCellView.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/17/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import RxSwift

final class DownloadsManagementTableCellView: NSTableCellView {

    static var byteCounterFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    static func statusString(for info: DownloadManager.DownloadInfo) -> String {
        var status = ""

        // TODO: Show an explicitly paused status, and/or update the sorting algorithm
        // so that running downloads show up above paused downloads
        if info.totalBytesExpectedToWrite == 0 {
            status = "Waiting..."
        } else {
            let formatter = DownloadsManagementTableCellView.byteCounterFormatter

            status += "\(formatter.string(fromByteCount: info.totalBytesWritten))"
            status += " of "
            status += "\(formatter.string(fromByteCount: info.totalBytesExpectedToWrite))"
        }

        return status
    }

    var disposeBag = DisposeBag()

    var download: DownloadManager.Download? {
        didSet {
            guard let download = download else { return }

            switch download.state {
            case .running:
                suspendResumeButton.state = .off
            case .suspended:
                suspendResumeButton.state = .on
            case .canceling, .completed: ()
                suspendResumeButton.isHidden = true
            }
        }
    }

    var status: Observable<DownloadStatus>? {
        didSet {
            disposeBag = DisposeBag()

            guard let status = status else { return }

            status
                .throttle(0.1, latest: true, scheduler: MainScheduler.instance)
                .subscribe(onNext: { [weak self] status in
                    guard let self = self else { return }

                    switch status {
                    case .downloading(let info):
                        if info.totalBytesExpectedToWrite > 0 {
                            self.progressIndicator.isIndeterminate = false
                            self.progressIndicator.doubleValue = info.progress
                        } else {
                            self.progressIndicator.isIndeterminate = true
                            self.progressIndicator.startAnimation(nil)
                        }
                        self.downloadStatusLabel.stringValue = DownloadsManagementTableCellView.statusString(for: info)
                    case .finished, .paused, .cancelled, .none, .failed: ()
                    }
            }).disposed(by: disposeBag)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        fatalError()
    }

    lazy var sessionTitleLabel: NSTextField = {
        let l = VibrantTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 13)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private lazy var downloadStatusLabel: NSTextField = {
        let l = VibrantTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private lazy var suspendResumeButton: NSButton = {
        // TODO: Better buttons, looks like AppKit doesn't have the right thing
        let v = NSButton(image: NSImage(named: "NSPauseTemplate")!, target: self, action: #selector(togglePause))
        v.alternateImage = NSImage(named: "NSPlayTemplate")
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isBordered = false
        v.imagePosition = .imageOnly
        v.setButtonType(.toggle)
        return v
    }()

    private lazy var cancelButton: NSButton = {
        let v = NSButton(image: NSImage(named: "NSStopProgressFreestandingTemplate")!, target: self, action: #selector(cancel))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isBordered = false
        v.imagePosition = .imageOnly
        return v
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let v = NSProgressIndicator(frame: .zero)
        v.minValue = 0
        v.maxValue = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    @objc
    private func togglePause() {
        // TODO: The button state should be wired to an observable
        if download?.state == .suspended {
            download?.resume()
            suspendResumeButton.state = .off
        } else if download?.state == .running {
            download?.pause()
            suspendResumeButton.state = .on
        }
    }

    @objc
    private func cancel() {
        download?.cancel()
    }

    private func setup() {

        addSubview(progressIndicator)
        addSubview(cancelButton)
        addSubview(sessionTitleLabel)
        addSubview(downloadStatusLabel)
        addSubview(suspendResumeButton)

        // Horizontal layout
        progressIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        progressIndicator.trailingAnchor.constraint(equalTo: suspendResumeButton.leadingAnchor).isActive = true

        suspendResumeButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor).isActive = true
        suspendResumeButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        suspendResumeButton.centerYAnchor.constraint(equalTo: progressIndicator.centerYAnchor).isActive = true

        cancelButton.centerYAnchor.constraint(equalTo: progressIndicator.centerYAnchor).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

        // Vertical layout
        sessionTitleLabel.bottomAnchor.constraint(equalTo: progressIndicator.topAnchor).isActive = true
        sessionTitleLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true
        downloadStatusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor).isActive = true
        downloadStatusLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true
    }
}
