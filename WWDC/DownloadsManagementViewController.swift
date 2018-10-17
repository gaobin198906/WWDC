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

    private lazy var summaryLabel: VibrantTextField = {
        let l = VibrantTextField(labelWithString: "Downloads")
        l.font = .systemFont(ofSize: 25)
        l.textColor = .secondaryLabelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()

        // We control the intial selection during initialization
        v.allowsEmptySelection = true

        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = Metrics.sessionRowHeight
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true
        v.gridStyleMask = .solidHorizontalGridLineMask
        v.gridColor = .darkGridColor
        v.selectionHighlightStyle = .none // see WWDCTableRowView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "session"))
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

        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        view.addSubview(summaryLabel)
        view.topAnchor.constraint(equalTo: summaryLabel.topAnchor, constant: -20).isActive = true
        view.centerXAnchor.constraint(equalTo: summaryLabel.centerXAnchor).isActive = true

        view.addSubview(scrollView)
        scrollView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    let downloadManager: DownloadManager

    var tasks = [URLSessionDownloadTask]() {
        didSet {
            if tasks.count == 0 {
                view.window?.close()
            } else {
                tableView.reloadData()
            }
        }
    }

    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager

        super.init(nibName: nil, bundle: nil)

        downloadManager.downloadsObservable.subscribe(onNext: {
            self.tasks = Array($0.values)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DownloadsManagementViewController: NSTableViewDataSource, NSTableViewDelegate {

    fileprivate struct Metrics {
        static let headerRowHeight: CGFloat = 20
        static let sessionRowHeight: CGFloat = 64
    }

    private struct Constants {
        static let sessionCellIdentifier = "sessionCell"
        static let titleCellIdentifier = "titleCell"
        static let rowIdentifier = "row"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tasks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = tasks[row]
//
//        switch sessionRow.kind {
//        case .session(let viewModel):
            return cellForTask(task)
//        case .sectionHeader(let title):
//            return cellForSectionTitle(title)
//        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? WWDCTableRowView

        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }
//
//        switch displayedRows[row].kind {
//        case .sectionHeader:
//            rowView?.isGroupRowStyle = true
//        default:
//            rowView?.isGroupRowStyle = false
//        }
//
        return rowView
    }

    private func cellForTask(_ task: URLSessionDownloadTask) -> DownloadsManagementTableCellView? {
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.sessionCellIdentifier), owner: tableView) as? DownloadsManagementTableCellView

        if cell == nil {
            cell = DownloadsManagementTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.sessionCellIdentifier)
        }
//
        cell?.task = task
//
        return cell
    }
//
//    private func cellForSectionTitle(_ title: String) -> TitleTableCellView? {
//        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.titleCellIdentifier), owner: tableView) as? TitleTableCellView
//
//        if cell == nil {
//            cell = TitleTableCellView(frame: .zero)
//            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.titleCellIdentifier)
//        }
//
//        cell?.title = title
//
//        return cell
//    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
//        switch displayedRows[row].kind {
//        case .session:
            return Metrics.sessionRowHeight
//        case .sectionHeader:
//            return Metrics.headerRowHeight
//        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
//        switch displayedRows[row].kind {
//        case .sectionHeader:
            return false
//        case .session:
//            return true
//        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
//        switch displayedRows[row].kind {
//        case .sectionHeader:
//            return true
//        case .session:
            return false
//        }
    }

}

extension DownloadsManagementViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {

        return true
    }
}
