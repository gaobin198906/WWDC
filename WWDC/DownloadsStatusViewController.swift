//
//  DownloadsStatusViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 18/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RxSwift

class DownloadsStatusViewController: NSViewController {

    let downloadManager: DownloadManager
    let storage: Storage
    let disposeBag = DisposeBag()

    init(downloadManager: DownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        downloadManager.downloadsObservable.subscribe(onNext: { [weak self] in
            self?.statusButton.isHidden = $0.isEmpty
        }).disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var statusButton: DownloadsStatusButton = {
        let v = DownloadsStatusButton(target: self, action: #selector(test))
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        let view = NSView()

        #if DEBUG
        view.addSubview(statusButton)
        statusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
        statusButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1, constant: 0).isActive = true
        statusButton.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1, constant: 0).isActive = true
        statusButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        #endif

        self.view = view
    }

    @objc
    func test(sender: NSButton) {
        if presentedViewControllers?.isEmpty == true {
            present(DownloadsManagementViewController(downloadManager: downloadManager, storage: storage), asPopoverRelativeTo: sender.bounds, of: sender, preferredEdge: .maxY, behavior: .semitransient)
        } else {
            presentedViewControllers?.forEach(dismiss)
        }
    }
}
