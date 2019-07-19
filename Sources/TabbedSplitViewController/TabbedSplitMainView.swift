//
//  TabbedSplitMainView.swift
//  TabbedSplitViewController
//
//  Created by Pavel Kazantsev on 1/24/17.
//  Copyright © 2017 PaKaz.net. All rights reserved.
//

import UIKit

private enum StackViewItem: Int {
    case tabBar
    case master
    case detail

    var index: Int {
        return rawValue
    }
    var hierarchyIndex: Int {
        switch self {
        case .tabBar: return 2
        case .master: return 1
        case .detail: return 0
        }
    }
}

private let sideBarAnimationDuration: TimeInterval = 0.35

@IBDesignable
class PKTabbedSplitView: UIView {

    var masterViewWidth: CGFloat = 320 {
        didSet {
            masterViewWidthConstraint.constant = masterViewWidth
        }
    }
    var navigationBarWidth: CGFloat = 280 {
        didSet {
            navigationBarWidthConstraint?.constant = navigationBarWidth
        }
    }
    let masterViewWidthConstraint: NSLayoutConstraint
    private(set) var navigationBarWidthConstraint: NSLayoutConstraint?

    var hideTabBarView: Bool = false
    var hideMasterView: Bool = false
    var hideDetailView: Bool = false {
        didSet {
            // When detail view is hidden the master view takes all available space
            masterViewWidthConstraint.isActive = !hideDetailView
        }
    }

    var logger: DebugLogger?

    private(set) var sideBarIsHidden = true

    private var sideBarGestRecHelper: SideBarGestureRecognizerHelper?

    private let stackView = UIStackView().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.alignment = .fill
        $0.distribution = .fill
        $0.axis = .horizontal
        $0.spacing = 0
    }
    /// Views saved here for us to be able to remove them from stack view and add back
    private let stackViewItems: [UIView]

    private func view(for item: StackViewItem) -> UIView {
        return stackViewItems[item.index]
    }

    init(tabBarView: UIView, masterView: UIView, detailView: UIView) {
        stackViewItems = [tabBarView, masterView, detailView]
        stackViewItems.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        masterViewWidthConstraint = masterView.widthAnchor.constraint(equalToConstant: masterViewWidth)
        // For a case when we don't have detail view and we stretch master to all the parent width
        masterViewWidthConstraint.priority = UILayoutPriority(900)

        super.init(frame: .zero)

        // Different order from stackViewItems order due to layers order
        // (details view should be at the bottom, then master view, tab bar should be at the top)
        stackView.addSubview(detailView)
        stackView.addSubview(masterView)
        stackView.addSubview(tabBarView)

        for view in stackViewItems {
            stackView.addArrangedSubview(view)
        }

        if #available(iOS 11.0, *) {
            addSubview(stackView)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            let constraints = [
                stackView.leftAnchor.constraint(equalTo: leftAnchor),
                stackView.topAnchor.constraint(equalTo: topAnchor),
                stackView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ]
            NSLayoutConstraint.activate(constraints)
        }
        else {
            addChildView(stackView)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Presenting detail view in-place

    /// Present detail view in-place, hiding master and detail, if not already hidden
    func presentDetailViewSolo(hidingTabBar: Bool, hidingMaster: Bool, animationFinished: (() -> Void)?) {
        let masterNewFrame = hidingMaster ? prepareForHiding(.master) : nil
        let tabBarNewFrame = hidingTabBar ? prepareForHiding(.tabBar) : nil

        let detailView = self.view(for: .detail)
        // Just add as a subview, will add to arranged after the animation
        stackView.insertSubview(detailView, at: StackViewItem.detail.hierarchyIndex)

        // Set frame to full screen and hide behind right edge
        detailView.frame = stackView.frame
        detailView.frame.origin.x = stackView.frame.maxX
        detailView.isHidden = false

        UIView.animate(withDuration: 0.33, animations: {
            if let newFrame = masterNewFrame {
                self.view(for: .master).frame = newFrame
            }
            if let newFrame = tabBarNewFrame {
                self.view(for: .tabBar).frame = newFrame
            }
            detailView.frame.origin.x = 0
        }) { _ in
            self.view(for: .master).isHidden = true
            self.view(for: .tabBar).isHidden = true
            self.addArrangedView(.detail)
            animationFinished?()
        }
    }

    /// Hide detail view in-place, showing tab bar and master
    ///  if they were hidden by `presentDetailViewSolo(hidingTabBar:hidingMaster:)`
    ///  but otherwise should be shown
    ///
    /// - Parameters:
    ///   - keepShown: keep detail view on screen
    ///   - addingTabBar: add the tab bar back
    ///   - addingMaster: add the master view back
    func hideDetailViewSolo(keepShown: Bool, addingTabBar: Bool, addingMaster: Bool, animationFinished: (() -> Void)?) {
        func prepareForShowing(_ item: StackViewItem, pushRight: Bool = false) {
            let view = self.view(for: item)
            stackView.removeArrangedSubview(view)
            stackView.insertSubview(view, at: item.hierarchyIndex)
            view.translatesAutoresizingMaskIntoConstraints = true
            view.frame.size.height = stackView.frame.height
            if !pushRight {
                view.frame.origin.x = -view.frame.width
            }
            view.isHidden = false
        }
        if addingTabBar {
            prepareForShowing(.tabBar)
        }
        if addingMaster {
            prepareForShowing(.master)
        }
        let detailNewFrame: CGRect
        if keepShown {
            detailNewFrame = .zero
            prepareForShowing(.detail, pushRight: true)
        } else {
            detailNewFrame = prepareForHiding(.detail, pushRight: true)
        }
        UIView.animate(withDuration: 0.33, animations: {
            if addingTabBar {
                self.view(for: .tabBar).frame.origin.x = 0
            }
            if addingMaster {
                let masterX: CGFloat = addingTabBar ? self.view(for: .tabBar).frame.width : 0
                self.view(for: .master).frame.origin.x = masterX
            }
            if keepShown {
                var detailX: CGFloat = 0
                if addingTabBar {
                    detailX += self.view(for: .tabBar).frame.width
                }
                if addingMaster {
                    detailX += self.view(for: .master).frame.width
                }
                self.view(for: .detail).frame.origin.x = detailX
            } else {
                self.view(for: .detail).frame = detailNewFrame
            }
        }) { _ in
            if addingTabBar {
                self.addArrangedView(.tabBar)
            }
            if addingMaster {
                self.addArrangedView(.master)
            }
            if keepShown {
                self.addArrangedView(.detail)
            } else {
                self.view(for: .detail).isHidden = true
            }
            animationFinished?()
        }
    }

    private func prepareForHiding(_ item: StackViewItem, pushRight: Bool = false) -> CGRect {
        let view = self.view(for: item)
        var newFrame = view.frame
        view.translatesAutoresizingMaskIntoConstraints = true
        stackView.removeArrangedSubview(view)
        newFrame.origin.x = pushRight ? stackView.frame.maxX : -view.frame.width

        return newFrame
    }

    // MARK: - Switching mods for split-view

    /// Add **detail** view back to the stack view
    func addDetailView() {
        let item = StackViewItem.detail
        let view = self.view(for: item)

        view.isHidden = true
        stackView.insertSubview(view, at: item.hierarchyIndex)
        addArrangedView(item)
        view.isHidden = false
    }
    /// Remove **detail** view from the stack view
    func removeDetailView(removeFromViewHierarchy: Bool) {
        let view = self.view(for: .detail)
        if removeFromViewHierarchy {
            view.removeFromSuperview()
        } else {
            view.isHidden = true
        }
    }

    private func addArrangedView(_ item: StackViewItem) {
        let view = self.view(for: item)
        view.translatesAutoresizingMaskIntoConstraints = false
        if item.index >= stackView.arrangedSubviews.count {
            stackView.addArrangedSubview(view)
        } else {
            stackView.insertArrangedSubview(view, at: item.index)
        }
    }

    /// Creates a side bar then adds a master view there.
    /// Should be called after removing the view from the stack view!
    func addMasterSideBar(tabBarWidth: CGFloat) {
        logger?.log("Entered")
        sideBarIsHidden = true
        let sideBarView = self.view(for: .master)
        // Remove the master view from the stack view but only to get rid of all the constraints
        sideBarView.removeFromSuperview()
        stackView.insertSubview(sideBarView, at: StackViewItem.master.hierarchyIndex)

        sideBarView.translatesAutoresizingMaskIntoConstraints = false
        sideBarView.topAnchor.constraint(equalTo: stackView.topAnchor).isActive = true
        sideBarView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor).isActive = true
        sideBarView.isHidden = false

        let leading = sideBarView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: -masterViewWidth)
        leading.isActive = true

        let helper = SideBarGestureRecognizerHelper(base: self, target: sideBarView, targetX: leading, targetWidth: masterViewWidth, leftOffset: tabBarWidth)
        helper.logger = logger
        helper.didOpen = { [unowned self] in
            self.sideBarIsHidden = false
        }
        helper.didClose = { [unowned self] in
            self.sideBarIsHidden = true
        }
        sideBarGestRecHelper = helper
    }
    func addNavigationBar(_ sideBarView: UIView) {
        logger?.log("Entered")
        sideBarIsHidden = true
        self.view(for: .tabBar).removeFromSuperview()
        addSubview(sideBarView)

        sideBarView.translatesAutoresizingMaskIntoConstraints = false
        sideBarView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        sideBarView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        sideBarView.isHidden = false

        let leading = sideBarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -navigationBarWidth)
        leading.isActive = true

        let width = sideBarView.widthAnchor.constraint(equalToConstant: navigationBarWidth)
        width.isActive = true
        navigationBarWidthConstraint = width

        let helper = SideBarGestureRecognizerHelper(base: self, target: sideBarView, targetX: leading, targetWidth: navigationBarWidth)
        helper.logger = logger
        helper.didOpen = { [unowned self] in
            self.sideBarIsHidden = false
        }
        helper.didClose = { [unowned self] in
            self.sideBarIsHidden = true
        }
        sideBarGestRecHelper = helper
    }

    func removeMasterSideBar() {
        logger?.log("Entered")
        sideBarGestRecHelper = nil

        let view = self.view(for: .master)
        view.removeFromSuperview()
        view.isHidden = false
        stackView.insertSubview(view, at: StackViewItem.master.hierarchyIndex)
        stackView.insertArrangedSubview(view, at: StackViewItem.master.index)
    }
    func removeNavigationBar(_ view: UIView, keepTabBarHidden: Bool) {
        logger?.log("\(view)")
        sideBarGestRecHelper = nil
        view.removeFromSuperview()

        let tabBar = self.view(for: .tabBar)
        if !keepTabBarHidden {
            tabBar.isHidden = false
        }
        stackView.insertSubview(tabBar, at: StackViewItem.tabBar.hierarchyIndex)
        stackView.insertArrangedSubview(tabBar, at: StackViewItem.tabBar.index)
    }

    func hideSideBar() {
        guard !sideBarIsHidden else { return }
        logger?.log("Closing side bar")
        sideBarGestRecHelper?.close(withDuration: sideBarAnimationDuration, animated: true, wasClosing: true)
    }
    func showSideBar() {
        guard sideBarIsHidden else { return }
        logger?.log("Opening side bar")
        sideBarGestRecHelper?.open(withDuration: sideBarAnimationDuration, animated: true, wasOpening: true)
    }

    func setSideBarGestureRecognizerEnabled(_ enabled: Bool) {
        sideBarGestRecHelper?.isEnabled = enabled
    }
    
}

private let maxOverlayAlpha: CGFloat = 0.25
private let minOverlayAlpha: CGFloat = 0.0

private class SideBarGestureRecognizerHelper {

    private let sourceView: UIView
    private let targetView: UIView
    private let xConstraint: NSLayoutConstraint
    private let viewWidth: CGFloat
    private let leftOffset: CGFloat

    private let openViewRec: UIGestureRecognizer
    private let closeViewRec: UIGestureRecognizer
    fileprivate var didOpen: (() -> Void)?
    fileprivate var didClose: (() -> Void)?

    fileprivate var isEnabled: Bool = true {
        didSet {
            openViewRec.isEnabled = isEnabled
            closeViewRec.isEnabled = isEnabled
        }
    }

    private var startingPoint: CGFloat = 0

    private let overlayView = UIView().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isHidden = true
        $0.backgroundColor = .black
        $0.alpha = minOverlayAlpha
    }

    var logger: DebugLogger?

    fileprivate init(base: UIView, target: UIView, targetX: NSLayoutConstraint, targetWidth: CGFloat, leftOffset: CGFloat = 0) {
        sourceView = base
        targetView = target
        xConstraint = targetX
        viewWidth = targetWidth
        self.leftOffset = leftOffset

        let rec1 = UIScreenEdgePanGestureRecognizer()
        sourceView.addGestureRecognizer(rec1)
        openViewRec = rec1

        let rec2 = UIPanGestureRecognizer()
        targetView.addGestureRecognizer(rec2)
        closeViewRec = rec2

        rec1.edges = .left
        rec1.addTarget(self, action: #selector(handleGesture(_:)))
        rec2.addTarget(self, action: #selector(handleGesture(_:)))

        targetView.superview?.insertChildView(overlayView, belowSubview: targetView)

        let overlayTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOverlay))
        overlayView.addGestureRecognizer(overlayTapGestureRecognizer)
    }
    deinit {
        showShadow(false)
        overlayView.removeFromSuperview()
        sourceView.removeGestureRecognizer(openViewRec)
        targetView.removeGestureRecognizer(closeViewRec)
        xConstraint.isActive = false
        logger?.log("Deinit \(type(of: self))")
    }

    @objc private func handleGesture(_ rec: UIGestureRecognizer) {
        let isOpenGestRec = (rec == openViewRec)
        switch rec.state {
        case .began:
            let point = rec.location(ofTouch: 0, in: sourceView).x
            startingPoint = point
            targetView.superview?.insertChildView(overlayView, belowSubview: targetView)
            overlayView.alpha = isOpenGestRec ? minOverlayAlpha : maxOverlayAlpha
            overlayView.isHidden = false
            showShadow(true)
        case .changed:
            let point = rec.location(ofTouch: 0, in: sourceView).x
            if isOpenGestRec {
                let maxPoint = viewWidth + startingPoint
                xConstraint.constant = ((point < maxPoint) ? point - startingPoint - viewWidth : 0) + leftOffset
            } else {
                xConstraint.constant = ((point < startingPoint) ? point - startingPoint : 0) + leftOffset
            }
            let percent = (-xConstraint.constant + leftOffset) / viewWidth
            overlayView.alpha = maxOverlayAlpha - maxOverlayAlpha * percent
        case .ended:
            let openRemainder = abs(xConstraint.constant - leftOffset)
            let shouldOpen = openRemainder < viewWidth / 2
            let remainder = ((openRemainder / 2) / (viewWidth / 2))
            let duration = sideBarAnimationDuration * TimeInterval(remainder)

            if shouldOpen {
                open(withDuration: duration, animated: true, wasOpening: isOpenGestRec)
            } else {
                close(withDuration: duration, animated: true, wasClosing: !isOpenGestRec)
            }
        case .cancelled:
            break
        default:
            break
        }
    }
    @objc private func didTapOverlay(_ rec: UIGestureRecognizer) {
        close(withDuration: sideBarAnimationDuration)
    }

    func close(withDuration duration: TimeInterval, animated: Bool = true, wasClosing: Bool = true) {
        xConstraint.constant = -viewWidth + leftOffset
        logger?.log("Constant: \(self.xConstraint.constant)")
        UIView.animate(withDuration: duration, animations: {
            self.sourceView.layoutIfNeeded()
            self.overlayView.alpha = minOverlayAlpha
        }) { completed in
            if completed, wasClosing {
                self.showShadow(false)
                self.openViewRec.isEnabled = true
                self.overlayView.isHidden = true
                self.didClose?()
            }
        }
    }
    func open(withDuration duration: TimeInterval, animated: Bool = true, wasOpening: Bool = true) {
        showShadow(true)
        xConstraint.constant = leftOffset
        logger?.log("Constant: \(self.xConstraint.constant)")
        overlayView.isHidden = false
        UIView.animate(withDuration: duration, animations: {
            self.sourceView.layoutIfNeeded()
            self.overlayView.alpha = maxOverlayAlpha
        }) { completed in
            if completed, wasOpening {
                self.openViewRec.isEnabled = false
                self.didOpen?()
            }
        }
    }

    func showShadow(_ show: Bool) {
        if show {
            targetView.layer.shadowColor = UIColor.black.cgColor
            targetView.layer.shadowOffset = CGSize(width: 2.0, height: 0.0)
            targetView.layer.shadowOpacity = 0.5
            targetView.layer.shadowRadius = 2.5
        }
        targetView.layer.masksToBounds = !show
    }

}
