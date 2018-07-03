//
//  DownloadsStatusViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/3/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class WWDCVibrantTextField: NSTextField {

    override var allowsVibrancy: Bool {
        return true
    }
}

class DownloadsStatusViewController: NSViewController {

    private lazy var summaryLabel: WWDCVibrantTextField = {
        let l = WWDCVibrantTextField(labelWithString: "Downloads")
        l.font = .systemFont(ofSize: 50)
        l.textColor = .secondaryLabelColor
//        l.cell?.backgroundStyle = .dark
//        l.isSelectable = true
//        l.lineBreakMode = .byWordWrapping
//        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
//        l.allowsDefaultTighteningForTruncation = true
//        l.maximumNumberOfLines = 20
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        view.addSubview(summaryLabel)

        view.topAnchor.constraint(equalTo: summaryLabel.topAnchor, constant: -20).isActive = true
        view.centerXAnchor.constraint(equalTo: summaryLabel.centerXAnchor).isActive = true
    }
}

extension DownloadsStatusViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
