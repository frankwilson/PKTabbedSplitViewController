//
//  extensions.swift
//  TabbedSplitViewController
//
//  Created by Pavel Kazantsev on 1/27/17.
//  Copyright © 2017 PaKaz.net. All rights reserved.
//

import UIKit

extension UIViewController {

    /// Add a view as a child to this view controller's view
    ///  attaching all sides.
    ///
    /// - Parameter childView: a child view that will take all parent's space
    func addChildView(_ childView: UIView, leading: Bool = true, top: Bool = true, trailing: Bool = true, bottom: Bool = true) {
        view.addChildView(childView, leading: leading, top: top, trailing: trailing, bottom: bottom)
    }
    func addChildViewCentered(_ childView: UIView) {
        childView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childView)

        let constraints = [
            childView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            childView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            childView.widthAnchor.constraint(equalTo: view.widthAnchor),
            childView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
        view.setNeedsLayout()
    }
}

extension UIView {

    /// Adds a passed view as a vertical separator, setting a passed color (or `.gray` as a default value),
    /// and a passed width (or 1 screen pixel).
    ///
    /// The passed view will be alignet to the right side of this view with equal height.
    ///
    /// - Parameters:
    ///   - separator: view that will be set as a separator
    ///   - color: separator color
    ///   - width: separator width
    func addVerticalSeparator(_ separator: VerticalSeparatorView, color: UIColor = .gray, width: CGFloat? = nil) {
        addSubview(separator)
        let lineWidth = width ?? 1.0 / UIScreen.main.nativeScale
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = color
        separator.accessibilityIdentifier = "Vertical Separator"
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: lineWidth),
            separator.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            separator.rightAnchor.constraint(equalTo: rightAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func addChildView(_ childView: UIView, leading: Bool = true, top: Bool = true, trailing: Bool = true, bottom: Bool = true) {
        addSubview(childView)
        configureConstraints(to: childView, leading: leading, top: top, trailing: trailing, bottom: bottom)
    }
    func insertChildView(_ childView: UIView, belowSubview: UIView, leading: Bool = true, top: Bool = true, trailing: Bool = true, bottom: Bool = true) {
        insertSubview(childView, belowSubview: belowSubview)
        configureConstraints(to: childView, leading: leading, top: top, trailing: trailing, bottom: bottom)
    }

    func configureConstraints(to childView: UIView, leading: Bool = true, top: Bool = true, trailing: Bool = true, bottom: Bool = true) {
        childView.translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []

        if top { constraints.append(childView.topAnchor.constraint(equalTo: topAnchor)) }
        if bottom { constraints.append(childView.bottomAnchor.constraint(equalTo: bottomAnchor)) }
        if leading { constraints.append(childView.leadingAnchor.constraint(equalTo: leadingAnchor)) }
        if trailing { constraints.append(childView.trailingAnchor.constraint(equalTo: trailingAnchor)) }

        NSLayoutConstraint.activate(constraints)
        setNeedsLayout()
    }

    func constraint(for kind: NSLayoutConstraint.Attribute) -> NSLayoutConstraint? {
        return superview?.constraints.first {
            if let first = $0.firstItem as? UIView, first == self {
                return $0.firstAttribute == kind
            }
            if let second = $0.secondItem as? UIView, second == self {
                return $0.secondAttribute == kind
            }
            return false
        }
    }
}

extension Array where Element: NSLayoutConstraint {

    static func constraints(withVisualFormat format: String, options opts: NSLayoutConstraint.FormatOptions = [], metrics: [String : Any]? = nil, views: [String : Any]) -> [NSLayoutConstraint] {
        return NSLayoutConstraint.constraints(withVisualFormat: format, options: opts, metrics: metrics, views: views)
    }
}

protocol Then {}

extension Then where Self: Any {

    func then(_ block: (inout Self) -> Void) -> Self {
        var copy = self
        block(&copy)
        return copy
    }

}

extension NSObject: Then {}

public protocol DebugLogger {

    func log(_ message: @escaping @autoclosure () -> Any?, level: LogLevel, _ function: StaticString, _ line: Int)
}

extension DebugLogger {
    func log(_ message: @escaping @autoclosure () -> Any?, _ function: StaticString = #function, _ line: Int = #line) {
        log(message, level: .debug, function, line)
    }
}


public enum LogLevel {
    case debug
    case info
    case warning
    case error
}

extension CGSize {

    func adjustedForSafeAreaInitially(_ logger: DebugLogger?) -> CGSize {
        var screenSize = self
        // Can't get safe area insets from here
        if Utils.deviceHasNotch {
            if screenSize.isPortrait {
                logger?.log("Estemated safe area: \(UIEdgeInsets.init(top: 44, left: 0, bottom: 34, right: 0))")
                screenSize.height -= 44 /* top */ + 34 /* bottom */
            }
            else {
                logger?.log("Estemated safe area: \(UIEdgeInsets.init(top: 0, left: 44, bottom: 21, right: 44))")
                screenSize.width -= 44 /* left */ + 44 /* right */
                screenSize.height -= 21 /* bottom */
            }
        }
        else {
            logger?.log("Device does not have a notch")
        }
        return screenSize
    }

    func adjustedForSafeArea(of view: UIView, _ logger: DebugLogger?) -> CGSize {
        var size = self
        if #available(iOS 11.0, *) {
            logger?.log("Current safe area: \(view.safeAreaInsets)")
            size.width -= view.safeAreaInsets.left + view.safeAreaInsets.right
            size.height -= view.safeAreaInsets.top + view.safeAreaInsets.bottom
        }
        return size
    }

    var isPortrait: Bool {
        return width < height
    }
}

private let notchDeviceNames = [
    "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8"
]

enum Utils {

    static var deviceHasNotch: Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return notchDeviceNames.contains(identifier)
    }

}
