//
//  DownloadsManagementViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 3/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RxSwift

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

    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager

        super.init(nibName: nil, bundle: nil)

        // TODO: memory management
        downloadManager.downloadsObservable.subscribe(onNext: {
            self.downloads = Array($0.values).sorted(by: { left, right in
                // This sorting is fine but doesn't update when a task goes from 0/pending to active
                switch (left.task.countOfBytesExpectedToReceive, right.task.countOfBytesExpectedToReceive) {
                case (0, _):
                    return false
                case (_, 0):
                    return true
                default:
                    return left.task.taskIdentifier < right.task.taskIdentifier
                }
            })
        })
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
        return cellForDownload(downloads[row])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? WWDCTableRowView

        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }

        return rowView
    }

    private func cellForDownload(_ download: DownloadManager.Download) -> DownloadsManagementTableCellView? {
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier), owner: tableView) as? DownloadsManagementTableCellView

        if cell == nil {
            cell = DownloadsManagementTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier)
        }

        cell?.download = download

        return cell
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
