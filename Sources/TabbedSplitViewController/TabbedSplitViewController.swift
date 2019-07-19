//
//  TabbedSplitViewController.swift
//
//  Created by Pavel Kazantsev on 29/06/15.
//  Copyright (c) 2015 Pavel Kazantsev. All rights reserved.
//

import UIKit

public typealias TabBarAction = () -> Void
public typealias ConfigureNavigationBar = ([PKTabBarItem<UIViewController>], [PKTabBarItem<TabBarAction>], @escaping (PKTabBarItem<UIViewController>, Int) -> Void, ((PKTabBarItem<TabBarAction>, Int) -> Void)?, Int) -> UIViewController

private typealias State = (tabBarHidden: Bool, masterHidden: Bool, detailHidden: Bool)

public struct PKTabBarItem<T> {

    /// Item title
    public let title: String
    /// Tab Bar item image
    public let image: UIImage
    /// Tab Bar item image – selected state
    public var selectedImage: UIImage?
    /// Navigation Bar item image
    public var navigationBarImage: UIImage?
    /// Navigation Bar item image – selected state
    public var navigationBarSelectedImage: UIImage?
    /// An action value that will be passed to the `OnSelection` callback
    ///
    /// Default types are `UIViewController` for the main tab bar and
    ///   `TabBarAction` closure for the action bar.
    public let action: T

    ///
    public init(title: String, image: UIImage, selectedImage: UIImage? = nil, navigationBarImage: UIImage? = nil, navigationBarSelectedImage: UIImage? = nil, action: T) {
        self.title = title
        self.image = image
        self.selectedImage = selectedImage
        self.action = action

        self.navigationBarImage = navigationBarImage
        self.navigationBarSelectedImage = navigationBarSelectedImage
    }
}

// MARK: - Main view controller

public class TabbedSplitViewController: UIViewController {

    public typealias SizeChangedCallback = ((CGSize, UITraitCollection, Configuration) -> Bool)

    public struct Configuration {
        /// Width of a vertical TabBar. **Default – 70**.
        public var tabBarWidth: CGFloat = 70
        /// Width of a master view. **Default – 320**.
        public var masterViewWidth: CGFloat = 320
        /// Minimal width of a detail view. **Default – 320**.
        ///
        /// If there is no space for a detail view it is hidden to be presented as a modal view.
        public var detailViewMinWidth: CGFloat = 320
        /// Color of a vertical TabBar. **Default – .white**.
        public var tabBarBackgroundColor: UIColor = .white
        /// Color of a detail view area when there's no detail view open. **Default – .white**.
        public var detailBackgroundColor: UIColor = .white
        /// Color of a vertical separator between tab bar and master view,
        ///   between master view and detail view.
        ///
        /// **Default – .gray**.
        public var verticalSeparatorColor: UIColor = .gray
        /// Set to true if you don't want the detail view be displayed as modal on
        ///   iPad in 1/3 split-view, but instead keep it in main view, and not
        ///   allow master and tab bar be displayed while detail is on.
        ///
        /// Is crucial on iPad when switching between split-view modes with an
        ///   app modal screen presented.
        ///
        /// **Default – false**.
        public var detailAsModalShouldStayInPlace: Bool = false

        /// Called when ether size or traits collection of the view is changed
        ///  to determine if tab bar should be hidden from main view and shown
        ///   as a slidable side bar.
        public var showTabBarAsSideBarWithSizeChange: SizeChangedCallback?
        /// Called when ether size or traits collection of the view is changed
        ///   to determine if master view should be hidden from main view and shown
        ///   as a slidable side bar.
        ///
        /// **Should not return true when** `showTabBarAsSideBarWithSizeChange` **callback returns true!**
        public var showMasterAsSideBarWithSizeChange: SizeChangedCallback?
        /// Called when ether size or traits collection of the view is changed
        ///   to determine if detail view should be hidden from main view and shown
        ///   as a modal view.
        ///
        /// **Should not return true when** `showMasterAsSideBarWithSizeChange` **callback returns true!**
        public var showDetailAsModalWithSizeChange: SizeChangedCallback?

        fileprivate func widthChanged(old oldValue: Configuration) -> Bool {
            return tabBarWidth != oldValue.tabBarWidth
                || masterViewWidth != oldValue.masterViewWidth
                || detailViewMinWidth != oldValue.detailViewMinWidth
        }

        fileprivate static let zero: Configuration = Configuration(tabBarWidth: 0, masterViewWidth: 0, detailViewMinWidth: 0, tabBarBackgroundColor: .white, detailBackgroundColor: .white, verticalSeparatorColor: .gray, detailAsModalShouldStayInPlace: false, showTabBarAsSideBarWithSizeChange: nil, showMasterAsSideBarWithSizeChange: nil, showDetailAsModalWithSizeChange: nil)
    }

    /// Tabbed Split View Controller Configuration
    public var config: Configuration {
        didSet {
            update(oldConfig: oldValue)
        }
    }

    /// This block returns a configured View Controller for a case when
    /// a tab bar is hidden and a slidable navigation bar is used instead.
    /// Accepts an array of items to configure the navigation view controller,
    /// and a callback that should be called when an item is selected
    public var configureNavigationBar: ConfigureNavigationBar = { items, actionItems, callback, actionCallback, selectedItemIndex in
        let vc = PKTabBarAsSideBar()
        vc.items = items
        vc.actionItems = actionItems
        vc.didSelectCallback = callback
        vc.actionSelectedCallback = actionCallback
        vc.selectedItemIndex = selectedItemIndex
        return vc
    }

    public var logger: DebugLogger? {
        didSet {
            mainView.logger = logger
        }
    }

    /// Currently open detail view controller
    public private(set) var detailViewController: UIViewController?

    public var selectedTabBarItemIndex: Int = -1 {
        didSet {
            // Double check – the same check is done on tab bar level.
            guard selectedTabBarItemIndex >= 0 || selectedTabBarItemIndex < tabBarVC.tabBar.items.count else {
                selectedTabBarItemIndex = oldValue
                return
            }
            if tabBarVC.tabBar.selectedItemIndex != selectedTabBarItemIndex {
                tabBarVC.tabBar.selectedItemIndex = selectedTabBarItemIndex
            }
        }
    }

    /// A view controller that, if set, will be displayed as a detail screen
    ///   before a detail screen opened and after a detail screen closed.
    public var defaultDetailViewController: UIViewController? {
        didSet {
            detailVC.defaultViewController = self.defaultDetailViewController
        }
    }

    private let masterVC = PKMasterViewController()
    private let detailVC = PKDetailViewController()
    private let tabBarVC = PKTabBar()
    private let mainView: PKTabbedSplitView

    private var configured: Bool = false

    private var futureTraits: UITraitCollection?
    private var futureSize: CGSize?
    private var sideNavigationBarViewController: UIViewController?

    private var state: State = (true, true, true)

    // MARK: - Init

    public init(items: [PKTabBarItem<UIViewController>], actionItems: [PKTabBarItem<TabBarAction>] = [], config: Configuration? = nil) {
        self.config = config ?? Configuration()
        mainView = PKTabbedSplitView(tabBarView: tabBarVC.view, masterView: masterVC.view, detailView: detailVC.view)

        super.init(nibName: nil, bundle: nil)

        update(oldConfig: .zero)
        tabBarVC.tabBar.items = items
        tabBarVC.actionsBar.items = actionItems
    }

    public required init?(coder aDecoder: NSCoder) {
        self.config = Configuration()
        mainView = PKTabbedSplitView(tabBarView: tabBarVC.view, masterView: masterVC.view, detailView: detailVC.view)

        super.init(coder: aDecoder)
        update(oldConfig: .zero)
    }

    // MARK: - View lifecycle

    public override func loadView() {
        view = mainView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tabBarVC.tabBar.didSelectCallback = { [unowned self] item, selectedIndex in
            let isTheSameItem = (item.action == self.masterVC.viewController)
            if !isTheSameItem {
                self.selectedTabBarItemIndex = selectedIndex
                self.masterVC.viewController = item.action

                self.logger?.log("Hide tab bar: \(self.mainView.hideTabBarView)")
                self.logger?.log("Hide master view: \(self.mainView.hideMasterView)")
            }
            if self.mainView.hideTabBarView {
                // Hide navigation view while opening a detail
                self.mainView.hideSideBar()
            }
            else if self.mainView.hideMasterView {
                if self.mainView.sideBarIsHidden {
                    self.mainView.showSideBar()
                    self.tabBarVC.tabBar.isOpen = true
                } else if isTheSameItem {
                    self.mainView.hideSideBar()
                    self.tabBarVC.tabBar.isOpen = false
                } else {
                    self.tabBarVC.tabBar.isOpen = true
                }
            }
        }
        tabBarVC.actionsBar.didSelectCallback = { [unowned self] item, selectedIndex in
            if self.mainView.hideTabBarView {
                self.mainView.hideSideBar()
            }
            item.action()
            self.tabBarVC.actionsBar.selectedItemIndex = -1
        }

        addChild(tabBarVC)
        addChild(masterVC)
        addChild(detailVC)

        update(oldConfig: .zero)

        view.backgroundColor = .white
    }

    public override func viewWillAppear(_ animated: Bool) {
        if configured {
            super.viewWillAppear(animated)
            return
        }

        selectedTabBarItemIndex = 0

        let screenSize = view.frame.size.adjustedForSafeAreaInitially(logger)
        let traits = futureTraits ?? traitCollection

        var state: State = (true, true, true)

        if let hideTabBar = config.showTabBarAsSideBarWithSizeChange?(screenSize, traits, config) {
            // Update only if it's changed
            if mainView.hideTabBarView != hideTabBar {
                mainView.hideTabBarView = hideTabBar
                if hideTabBar {
                    addNavigationSideBar()
                }
            }
            state.tabBarHidden = hideTabBar
        }
        tabBarVC.didMove(toParent: self)

        if let hideMaster = config.showMasterAsSideBarWithSizeChange?(screenSize, traits, config) {
            // Update only if it's changed
            if mainView.hideMasterView != hideMaster {
                mainView.hideMasterView = hideMaster
                if hideMaster {
                    mainView.addMasterSideBar(tabBarWidth: config.tabBarWidth)
                }
            }
            tabBarVC.tabBar.shouldDisplayArrow = hideMaster
            state.masterHidden = hideMaster
        }
        masterVC.didMove(toParent: self)

        // Hide detail from main view if there is not enough width
        if let hideDetail = config.showDetailAsModalWithSizeChange?(screenSize, traits, config) {
            if mainView.hideDetailView != hideDetail {
                mainView.hideDetailView = hideDetail
                if hideDetail {
                    mainView.removeDetailView(removeFromViewHierarchy: !config.detailAsModalShouldStayInPlace)
                }
            }
            state.detailHidden = hideDetail
        }
        detailVC.didMove(toParent: self)
        self.state = state

        tabBarVC.tabBarWidthConstraint.isActive = true
        tabBarVC.actionBarWidthConstraint.isActive = true
        mainView.masterViewWidthConstraint.isActive = true

        super.viewWillAppear(animated)
        configured = true
    }

    public override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        logger?.log("\(newCollection)")
        futureTraits = newCollection
    }
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        var hideDetail = false
        var hideMaster = false
        var hideTabBar = false

        var updateDetail = false
        var updateMaster = false
        var updateTabBar = false

        coordinator.animate(alongsideTransition: { _ in
            // Only here we could get our hand on the correct safe area values, not earlier
            let realSize = size.adjustedForSafeArea(of: self.view, self.logger)
            self.logger?.log("View is transitioning to \(realSize)")
            self.futureSize = realSize

            let traits = self.futureTraits ?? self.traitCollection
            if let hideDetailFunc = self.config.showDetailAsModalWithSizeChange {
                hideDetail = hideDetailFunc(realSize, traits, self.config)
                self.logger?.log("hide detail view: \(hideDetail)")
            }
            if let hideMasterFunc = self.config.showMasterAsSideBarWithSizeChange {
                hideMaster = hideMasterFunc(realSize, traits, self.config)
                self.logger?.log("hide master view: \(hideMaster)")
            }
            if hideDetail && hideMaster {
                self.logger?.log("We can't hide master and details at the same time!", level: .error, #function, #line)
            }
            else if let hideTabBarFunc = self.config.showTabBarAsSideBarWithSizeChange {
                hideTabBar = hideTabBarFunc(realSize, traits, self.config)
                self.logger?.log("hide Tab Bar: \(hideTabBar)")
            }
            updateDetail = self.mainView.hideDetailView != hideDetail
            updateMaster = self.mainView.hideMasterView != hideMaster
            updateTabBar = self.mainView.hideTabBarView != hideTabBar

            self.state = (hideTabBar, hideMaster, hideDetail)

            guard updateDetail || updateMaster || updateTabBar else { return }

            if updateMaster, !hideMaster {
                self.mainView.hideMasterView = false
            }
            if updateDetail, !hideDetail, !self.config.detailAsModalShouldStayInPlace {
                self.hideDetailAsModal()
            }

            let keepTabBarHidden = hideDetail && !hideTabBar && self.detailViewController != nil

            self.tabBarVC.tabBar.shouldDisplayArrow = hideMaster

            // First, adding to the Stack view
            if updateTabBar, !hideTabBar {
                self.removeNavigationSideBar(keepTabBarHidden: keepTabBarHidden)
            }
            if updateMaster, !hideMaster {
                self.mainView.removeMasterSideBar()
            }
            if updateDetail, !hideDetail {
                if self.config.detailAsModalShouldStayInPlace {
                    self.hideDetailAsModalInPlace()
                }
                self.mainView.addDetailView()
            }
            // Then, removing from the stack view
            if updateTabBar, hideTabBar {
                self.addNavigationSideBar()
            }
            if updateMaster, hideMaster, !hideDetail {
                self.mainView.addMasterSideBar(tabBarWidth: self.config.tabBarWidth)
            }
        }, completion: { _ in
            if updateMaster, hideMaster, !hideDetail {
                self.mainView.hideMasterView = true
            }
            if updateTabBar {
                self.mainView.hideTabBarView = hideTabBar
            }
            if updateDetail {
                self.mainView.hideDetailView = hideDetail
                if hideDetail {
                    self.presentDetailAsModal()
                }
            }
        })

        futureTraits = nil
    }

    // MARK: - Private functions

    private func presentDetailAsModal() {
        if config.detailAsModalShouldStayInPlace {
            if detailViewController != nil {
                presentDetailInPlace()
            } else {
                self.mainView.removeDetailView(removeFromViewHierarchy: true)
            }
        } else {
            self.mainView.removeDetailView(removeFromViewHierarchy: true)
            if let detail = detailViewController {
                // Remove the view controller from the DetailVC, but keep it saved in TSVC
                detailVC.setViewController(nil, animate: false)
                detail.view.translatesAutoresizingMaskIntoConstraints = true
                self.present(detail, animated: false)
            }
        }
    }
    private func hideDetailAsModal() {
        if let detail = detailViewController {
            dismiss(animated: false) {
                self.detailVC.setViewController(detail, animate: false)
            }
        }
    }
    private func hideDetailAsModalInPlace() {
        logger?.log("Move detail back to the stack view")
        hideDetailInPlace(keepShown: !self.state.detailHidden, then: nil)
    }

    private func presentDetailInPlace() {
        self.mainView.presentDetailViewSolo(hidingTabBar: !self.state.tabBarHidden,
                                            hidingMaster: !self.state.masterHidden,
                                            animationFinished: nil)
        self.mainView.setSideBarGestureRecognizerEnabled(false)
    }
    private func hideDetailInPlace(keepShown: Bool, then completion: (() -> Void)?) {
        self.mainView.hideDetailViewSolo(keepShown: keepShown,
                                     addingTabBar: !self.state.tabBarHidden,
                                     addingMaster: !self.state.masterHidden,
                                     animationFinished: completion)
        self.mainView.setSideBarGestureRecognizerEnabled(true)
    }

    private func addNavigationSideBar() {
        let navVC = configureNavigationBar(tabBarVC.tabBar.items, tabBarVC.actionsBar.items, tabBarVC.tabBar.didSelectCallback!, tabBarVC.actionsBar.didSelectCallback!, selectedTabBarItemIndex)
        sideNavigationBarViewController = navVC
        addChild(navVC)
        mainView.addNavigationBar(navVC.view)
        navVC.didMove(toParent: self)
    }
    private func removeNavigationSideBar(keepTabBarHidden: Bool) {
        guard let navVC = sideNavigationBarViewController else { return }

        navVC.willMove(toParent: nil)
        self.mainView.removeNavigationBar(navVC.view, keepTabBarHidden: keepTabBarHidden)
        navVC.removeFromParent()
        sideNavigationBarViewController = nil
    }

    // MARK: - Public functions

    /// Use TabbedSplitViewController.showDetailViewController(_:completion:) instead.
    public override func showDetailViewController(_ vc: UIViewController, sender: Any? = nil) {
        showDetailViewController(vc, completion: nil)
    }
    public func showDetailViewController(_ vc: UIViewController, completion: (() -> Void)? = nil) {
        // Show Detail screen if needed
        if mainView.hideDetailView {
            // Hide master view while opening a detail
            mainView.hideSideBar()

            if config.detailAsModalShouldStayInPlace {
                presentDetailInPlace()
                detailVC.setViewController(vc, animate: false, completion: completion)
            } else {
                present(vc, animated: true, completion: completion)
            }
        } else {
            if mainView.hideMasterView {
                // Hide master view while opening a detail
                mainView.hideSideBar()
            }
            detailVC.setViewController(vc, animate: true, completion: completion)
        }
        self.detailViewController = vc
    }

    public func dismissDetailViewController(animated flag: Bool = true, completion: (() -> Void)? = nil) {
        if mainView.hideDetailView {
            if config.detailAsModalShouldStayInPlace {
                hideDetailInPlace(keepShown: false, then: {
                    self.detailVC.setViewController(nil, animate: false, completion: completion)
                })
            } else {
                dismiss(animated: flag, completion: completion)
            }
        }
        else if detailViewController != nil {
            logger?.log("Removing presented detail VC from parent VC")
            detailVC.setViewController(nil, animate: true, completion: completion)
        }
        self.detailViewController = nil
    }

    /// Add an item with a view controller to open to the main tab bar
    /// - parameters:
    ///   - item: A tab bar item with a view controller as an action
    public func addToTabBar(_ item: PKTabBarItem<UIViewController>) {
        tabBarVC.tabBar.appendItem(item)
    }
    /// Insert an item with a view controller at a specific position on the tab bar
    /// - parameters:
    ///   - item: A tab bar item with a view controller as an action
    ///   - index: Position on the tab bar
    public func insertToTabBar(_ item: PKTabBarItem<UIViewController>, at index: Int) {
        guard index >= 0 && index < tabBarVC.tabBar.items.count else { return }
        tabBarVC.tabBar.insertItem(item, at: index)
    }
    public func removeFromTabBar(at index: Int) {
        guard index >= 0 && index < tabBarVC.tabBar.items.count else { return }
        tabBarVC.tabBar.removeItem(at: index)
    }
    /// Add an item with a closure to the bottom action bar
    /// - parameters:
    ///   - item: A tab bar item with a closure as an action
    public func addToActionBar(_ item: PKTabBarItem<TabBarAction>) {
        tabBarVC.actionsBar.appendItem(item)
    }
    /// Insert an item with a closure to the bottom action bar at a specific position on the tab bar
    /// - parameters:
    ///   - item: A tab bar item with a closure as an action
    ///   - index: Position on the action bar
    public func insertToActionBar(_ item: PKTabBarItem<TabBarAction>, at index: Int) {
        guard index >= 0 && index < tabBarVC.actionsBar.items.count else { return }
        tabBarVC.actionsBar.insertItem(item, at: index)
    }
    public func removeFromActionBar(at index: Int) {
        guard index >= 0 && index < tabBarVC.actionsBar.items.count else { return }
        tabBarVC.actionsBar.removeItem(at: index)
    }

    private func update(oldConfig: Configuration) {
        if config.tabBarWidth != oldConfig.tabBarWidth {
            tabBarVC.tabBarWidth = config.tabBarWidth
        }
        if config.masterViewWidth != oldConfig.masterViewWidth {
            mainView.masterViewWidth = config.masterViewWidth
        }
        if config.tabBarBackgroundColor != oldConfig.tabBarBackgroundColor {
            tabBarVC.backgroundColor = config.tabBarBackgroundColor
        }
        if config.detailBackgroundColor != oldConfig.detailBackgroundColor {
            detailVC.backgroundColor = config.detailBackgroundColor
        }
        if config.verticalSeparatorColor != oldConfig.verticalSeparatorColor {
            tabBarVC.verticalSeparatorColor = config.verticalSeparatorColor
            masterVC.verticalSeparatorColor = config.verticalSeparatorColor
        }
    }

}

// MARK: - Master view controller

private class PKMasterViewController: UIViewController {

    fileprivate var viewController: UIViewController? {
        didSet {
            if let prev = oldValue {
                prev.willMove(toParent: nil)
                prev.view.removeFromSuperview()
                prev.removeFromParent()
            }
            if let next = viewController {
                addChild(next)
                addChildView(next.view)
                if shouldAddVerticalSeparator {
                    view.addVerticalSeparator(verticalSeparator, color: verticalSeparatorColor)
                }
                view.layoutIfNeeded()
                next.didMove(toParent: self)
            }
        }
    }
    fileprivate var shouldAddVerticalSeparator: Bool = true
    fileprivate var verticalSeparatorColor: UIColor = .gray {
        didSet {
            verticalSeparator.backgroundColor = verticalSeparatorColor
        }
    }
    private let verticalSeparator = VerticalSeparatorView()

    fileprivate init() {
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate override func viewDidLoad() {
        super.viewDidLoad()

        if shouldAddVerticalSeparator {
            view.addVerticalSeparator(verticalSeparator, color: verticalSeparatorColor)
        }

        view.accessibilityIdentifier = "Master View"
        view.backgroundColor = .white
    }

}

// MARK: - Detail view controller

private class PKDetailViewController: UIViewController {

    private var viewController: UIViewController?

    fileprivate var defaultViewController: UIViewController? {
        didSet {
            // Don't replace current VC if it's presented
            if viewController == nil, defaultViewController != nil {
                setViewController(defaultViewController, animate: false)
            }
        }
    }
    fileprivate var backgroundColor: UIColor = .white {
        didSet {
            view.backgroundColor = backgroundColor
        }
    }

    fileprivate init() {
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate override func viewDidLoad() {
        super.viewDidLoad()

        view.accessibilityIdentifier = "Detail View"
        view.backgroundColor = backgroundColor
    }

    fileprivate func setViewController(_ newVC: UIViewController?, animate: Bool, completion: (() -> Void)? = nil) {
        let oldVC = viewController
        viewController = newVC ?? defaultViewController
        replaceViewController(oldVC, with: viewController, animate: animate, completion: completion)
    }

    private func replaceViewController(_ oldVC: UIViewController?, with newVC: UIViewController?, animate: Bool, completion: (() -> Void)?) {

        if let next = newVC {
            addChild(next)
            addChildViewCentered(next.view)
        }
        oldVC?.willMove(toParent: nil)

        let completion = { [unowned self] in
            oldVC?.removeFromParent()
            oldVC?.view.removeFromSuperview()
            newVC?.didMove(toParent: self)
            completion?()
        }

        guard animate else {
            completion()
            return
        }

        if let prev = oldVC, let next = newVC {
            // Switching between two view controllers
            if let nextXPosition = next.view.constraint(for: .centerX) {
                nextXPosition.constant = -view.bounds.width
                view.layoutIfNeeded()

                nextXPosition.constant = 0
                prev.view.constraint(for: .centerX)?.constant = view.bounds.width
            }

            transition(from: prev, to: next, duration: 0.33, options: [.curveEaseInOut], animations: {
                self.view.layoutIfNeeded()
            }) { finished in
                if finished {
                    completion()
                }
            }
        } else if let view = oldVC?.view ?? newVC?.view {
            let isClosing = (newVC == nil)
            view.alpha = isClosing ? 1.0 : 0.0
            UIView.transition(with: view, duration: 0.33, options: [.curveEaseInOut], animations: {
                view.alpha = isClosing ? 0.0 : 1.0
            }) { finished in
                if finished {
                    completion()
                }
            }
        }
    }

}
