//
//  DownloadsManagementViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 3/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift
import ConfCore

class DownloadsManagementViewController: NSViewController {

    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()

        v.allowsEmptySelection = true

        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = Metrics.rowHeight
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true
        v.gridStyleMask = .solidHorizontalGridLineMask
        v.gridColor = .darkGridColor
        v.selectionHighlightStyle = .none // see WWDCTableRowView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "download"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.drawsBackground = false
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.autohidesScrollers = true
        v.hasHorizontalScroller = false
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        tableView.delegate = self
        tableView.dataSource = self

        // TODO: Put sizes into the metrics
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))

        view.addSubview(scrollView)
        scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    let downloadManager: DownloadManager
    let storage: Storage
    var disposeBag = DisposeBag()

    var downloads = [DownloadManager.Download]() {
        didSet {
            if downloads.count == 0 {
                view.window?.close()
            } else {
                tableView.reloadData()
                let height = min((Metrics.rowHeight + Metrics.tableGridLineHeight) * CGFloat(downloads.count) + Metrics.topPadding, preferredMaximumSize.height)
                self.preferredContentSize = NSSize(width: 500, height: height)
            }
        }
    }

    override var preferredMaximumSize: NSSize {
        // TODO: More stable way for this
        var mainSize = NSApp.keyWindow?.frame.size
        mainSize?.height -= 50

        return mainSize ?? NSSize(width: 500, height: 500) // TODO: Default must fit within a screen
    }

    init(downloadManager: DownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        // TODO: memory management
        let disposeBag = self.disposeBag
        downloadManager
            .downloadsObservable
            .subscribe(onNext: { [weak disposeBag, weak self] in
                guard let disposeBag = disposeBag else { return }
                guard let self = self else { return }

                self.downloads = $0.sorted(by: <)

                let statusObserverables = $0.compactMap { downloadManager.downloadStatusObservable(for: $0) }

                let allStatuses = Observable.combineLatest(statusObserverables)

                // TODO: Overall progress
//                allStatuses
//                    .map {
//                        $0.reduce(, <#T##nextPartialResult: (Result, DownloadStatus) throws -> Result##(Result, DownloadStatus) throws -> Result#>)
//                    }

                allStatuses
                    .throttle(4, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] _ in
                        guard let self = self else { return }
                        // Occassionally reorder the list to keep running downloads at the top, etc
                        self.downloads.sort(by: <)
                    }).disposed(by: disposeBag)
            }).disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DownloadsManagementViewController: NSTableViewDataSource, NSTableViewDelegate {

    fileprivate struct Metrics {
        static let topPadding: CGFloat = 20
        static let tableGridLineHeight: CGFloat = 2
        static let rowHeight: CGFloat = 64
    }

    private struct Constants {
        static let downloadStatusCellIdentifier = "downloadStatusCellIdentifier"
        static let rowIdentifier = "row"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return downloads.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let download = downloads[row]
        guard let session = storage.session(with: download.session.sessionIdentifier) else { return nil }

        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier), owner: tableView) as? DownloadsManagementTableCellView

        if cell == nil {
            cell = DownloadsManagementTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier)
        }

        cell?.sessionTitleLabel.stringValue = session.title
        cell?.status = downloadManager.downloadStatusObservable(for: download)
        cell?.download = download

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? WWDCTableRowView

        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return Metrics.rowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}

extension DownloadsManagementViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
