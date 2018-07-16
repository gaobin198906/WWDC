//
//  WWDCTabViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

class WWDCTabViewController<Tab: RawRepresentable>: NSTabViewController where Tab.RawValue == Int {

    var activeTab: Tab {
        get {
            return Tab(rawValue: selectedTabViewItemIndex)!
        }
        set {
            selectedTabViewItemIndex = newValue.rawValue
        }
    }

    private var activeTabVar = Variable<Tab>(Tab(rawValue: 0)!)

    var rxActiveTab: Observable<Tab> {
        return activeTabVar.asObservable()
    }

    override var selectedTabViewItemIndex: Int {
        didSet {
            guard selectedTabViewItemIndex != oldValue else { return }
            guard selectedTabViewItemIndex >= 0 && selectedTabViewItemIndex < tabViewItems.count else { return }

            tabViewItems.forEach { item in
                guard let identifier = item.viewController?.identifier else { return }
                guard let view = tabItemViews.first(where: { $0.controllerIdentifier == identifier.rawValue }) else { return }

                if indexForChild(with: identifier.rawValue) == selectedTabViewItemIndex {
                    view.state = .on
                } else {
                    view.state = .off
                }
            }

            activeTabVar.value = Tab(rawValue: selectedTabViewItemIndex)!
        }
    }

    init(windowController: NSWindowController) {
        super.init(nibName: nil, bundle: nil)

        // Preserve the window's size, essentially passing in saved window frame sizes
        let superFrame = view.frame
        if let windowFrame = windowController.window?.frame {
            view.frame = NSRect(origin: superFrame.origin, size: windowFrame.size)
        }

        tabStyle = .unspecified
        identifier = NSUserInterfaceItemIdentifier(rawValue: "tabs")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
    }

//    private func tabItem(with identifier: String) -> NSTabViewItem? {
//        return tabViewItems.first { $0.identifier as? String == identifier }
//    }

    var isTopConstraintAdded = false

    override func  updateViewConstraints() {
        super.updateViewConstraints()

        if !isTopConstraintAdded, let window = view.window {
            isTopConstraintAdded = true
            NSLayoutConstraint(item: tabView,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: window.contentLayoutGuide,
                               attribute: .top,
                               multiplier: 1,
                               constant: 0).isActive = true
        }
    }

    override func transition(from fromViewController: NSViewController, to toViewController: NSViewController, options: NSViewController.TransitionOptions = [], completionHandler completion: (() -> Void)? = nil) {

        // Disable the crossfade animation here instead of removing it from the transition options
        // This works around a bug in NSSearchField in which the animation of resigning first responder
        // would get stuck if you switched tabs while the search field was first responder. Upon returning
        // to the original tab, you would see the search field's placeholder animate back to center
        // search_field_responder_tag
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)
        })
    }

//    override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {

        // Center the tab bar's NSToolbarItem's be putting flexible space at the beginning and end of
        // the array. Super's implementation returns the NSToolbarItems that represent the NSTabViewItems
//        var defaultItemIdentifiers = super.toolbarDefaultItemIdentifiers(toolbar)
//        defaultItemIdentifiers.insert(.flexibleSpace, at: 0)
//        defaultItemIdentifiers.insert(.wwdcTabLeadingStackView, at: 0)
//        defaultItemIdentifiers.insert(.flexibleSpace, at: 1)
//        defaultItemIdentifiers.insert(.flexibleSpace, at: 2)
//        defaultItemIdentifiers.append(.flexibleSpace)
//        defaultItemIdentifiers.append(.wwdcTabTrailingStackView)
//        defaultItemIdentifiers.append(.flexibleSpace)

//        windowController.window?.toolbar?.insertItem(withItemIdentifier: .init("MyThing"), at: 5)
//        windowController.window?.toolbar?.insertItem(withItemIdentifier: .flexibleSpace, at: 6)

//        return defaultItemIdentifiers
//    }

//    @objc
//    func test(sender: NSButton) {
//        if presentedViewControllers?.isEmpty == true {
//            self.presentViewController(DownloadsStatusViewController(nibName: nil, bundle: nil), asPopoverRelativeTo: sender.bounds, of: sender, preferredEdge: .maxY, behavior: .semitransient)
//        } else {
//            presentedViewControllers?.forEach(dismissViewController)
//        }
//    }

//    func makeTabCenteringItem(identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
//        let item = NSToolbarItem(itemIdentifier: identifier)
//
//        let stackView = NSStackView()
//        stackView.translatesAutoresizingMaskIntoConstraints = true
//        stackView.autoresizingMask = [.width, .height, .minXMargin, .maxXMargin]
//        item.view = stackView
//
//        item.minSize = .zero
//        item.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
//        return item
//    }
//
//    func addTrailingTabItem(view: NSView) {
//
//    }

//    override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

//        if [.wwdcTabTrailingStackView, .wwdcTabLeadingStackView].contains(itemIdentifier) {
//            let simpleItem = NSToolbarItem(itemIdentifier: itemIdentifier)
//
//            let b = NSButton(title: itemIdentifier == .wwdcTabLeadingStackView ? "Leading" : "Downloads", target: self, action: #selector(test))
////            let b2 = NSButton(title: itemIdentifier == .wwdcTabLeadingStackView ? "Leading" : "Downloads", target: self, action: #selector(test))
//            b.sizeToFit()
////            b2.sizeToFit()
//            simpleItem.view = b
//
////            stack.addView(b, in: .center)
////            stack.addView(b2, in: .center)
//            simpleItem.minSize = b.bounds.size
//            simpleItem.maxSize = b.bounds.size//CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
//
//            return simpleItem
//        }
//        if [.wwdcTabTrailingStackView, .wwdcTabLeadingStackView].contains(itemIdentifier) {
//            let item = makeTabCenteringItem(identifier: itemIdentifier)
//
//            if itemIdentifier == .wwdcTabTrailingStackView {
//                let b = NSButton(title: itemIdentifier == .wwdcTabLeadingStackView ? "Leading" : "Downloads", target: self, action: #selector(test))
//                b.sizeToFit()
//
//                (item.view as! NSStackView).addView(b, in: .center)
//            }
//            return item
//        }
//        guard let tabItem = tabItem(with: itemIdentifier.rawValue) else { return nil }
//
//        let itemView = TabItemView(frame: .zero)
//
//        itemView.title = tabItem.label
//        itemView.controllerIdentifier = (tabItem.viewController?.identifier).map { $0.rawValue } ?? ""
//        itemView.image = NSImage(named: NSImage.Name(rawValue: itemView.controllerIdentifier.lowercased()))
//        itemView.alternateImage = NSImage(named: NSImage.Name(rawValue: itemView.controllerIdentifier.lowercased() + "-filled"))
//
//        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
//
//        item.minSize = itemView.bounds.size
//        item.maxSize = itemView.bounds.size
//        item.view = itemView
//
//        item.target = self
//        item.action = #selector(changeTab)
//
//        itemView.state = (tabViewItems.index(of: tabItem) == selectedTabViewItemIndex) ? .on : .off
//
//        return item
//    }

//    @objc private func changeTab(_ sender: TabItemView) {
//        guard let index = indexForChild(with: sender.controllerIdentifier) else { return }
//
//        selectedTabViewItemIndex = index
//    }

    private func indexForChild(with identifier: String) -> Int? {
        return tabViewItems.index { $0.viewController?.identifier?.rawValue == identifier }
    }

    private var tabItemViews: [TabItemView] {
        return view.window?.toolbar?.items.compactMap { $0.view as? TabItemView } ?? []
    }

    private var loadingView: ModalLoadingView?

    func showLoading() {
        loadingView = ModalLoadingView.show(attachedTo: view)
    }

    func hideLoading() {
        loadingView?.hide()
    }

}

//extension NSToolbarItem.Identifier {
//    fileprivate static let wwdcTabLeadingStackView = NSToolbarItem.Identifier("MyThingLeading")
//    fileprivate static let wwdcTabTrailingStackView = NSToolbarItem.Identifier("MyThingTrailing")
//}

extension NSWindow {

    func toolbarHeight() -> CGFloat {
        var toolbarHeight = CGFloat(0.0)
        var windowFrame: NSRect

        if let toolbar = toolbar,
            toolbar.isVisible {

            windowFrame = NSWindow.contentRect(forFrameRect: self.frame, styleMask: self.styleMask)
            toolbarHeight = windowFrame.height - (self.contentView?.frame)!.height
        }

        return toolbarHeight
    }
}
