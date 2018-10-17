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
        formatter.allowedUnits = [ByteCountFormatter.Units.useMB, .useGB]
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    var disposeBag = DisposeBag()
    weak var task: URLSessionDownloadTask? {
        didSet {
            disposeBag = DisposeBag()

            sessionTitleLabel.stringValue = task?.originalRequest?.url?.lastPathComponent ?? "Weird"
            guard let task = task else { return }

            task.rx.observeWeakly(Int64.self, "countOfBytesReceived").observeOn(MainScheduler.instance).subscribe(onNext: { [weak task] in
                guard let task = task else { return }

                self.progressIndicator.isIndeterminate = false
                self.progressIndicator.maxValue = Double(task.countOfBytesExpectedToReceive)
                self.progressIndicator.minValue = 0
                self.progressIndicator.doubleValue = Double($0 ?? 0)
                self.downloadStatusLabel.stringValue = "\(DownloadsManagementTableCellView.byteCounterFormatter.string(fromByteCount: task.countOfBytesReceived)) of \(DownloadsManagementTableCellView.byteCounterFormatter.string(fromByteCount: task.countOfBytesExpectedToReceive))"
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

    private lazy var sessionTitleLabel: NSTextField = {
        let l = VibrantTextField(labelWithString: "What's New In Swift")
        l.font = .systemFont(ofSize: 13)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private lazy var downloadStatusLabel: NSTextField = {
        let l = VibrantTextField(labelWithString: "0 of 0 - 0 seconds remaining")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    private lazy var stopButton: NSButton = {
        let v = NSButton(image: NSImage(named: "NSStopProgressFreestandingTemplate")!, target: self, action: #selector(cancel))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isBordered = false
        v.imagePosition = .imageOnly
        return v
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let v = NSProgressIndicator(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    @objc
    private func cancel() {
        task?.cancel()
    }

    private func setup() {

        addSubview(progressIndicator)
        addSubview(stopButton)
        addSubview(sessionTitleLabel)
        addSubview(downloadStatusLabel)

        // Horizontal layout
        progressIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        progressIndicator.trailingAnchor.constraint(equalTo: stopButton.leadingAnchor).isActive = true
        stopButton.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        stopButton.centerYAnchor.constraint(equalTo: progressIndicator.centerYAnchor).isActive = true
        stopButton.widthAnchor.constraint(equalToConstant: 40).isActive = true

        // Vertical layout
        sessionTitleLabel.bottomAnchor.constraint(equalTo: progressIndicator.topAnchor).isActive = true
        sessionTitleLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true
        downloadStatusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor).isActive = true
        downloadStatusLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true

        progressIndicator.startAnimation(nil)
    }
}
