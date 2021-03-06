//
//  AppDelegate.swift
//  TabbedSplitViewControllerDemo
//
//  Created by Pavel Kazantsev on 29/06/15.
//  Copyright (c) 2015 Pavel Kazantsev. All rights reserved.
//

import UIKit
import TabbedSplitViewController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let minDetailWidth: CGFloat = 320
        let masterWidth: CGFloat = 320
        let tabBarWidth:CGFloat = 70

        if let viewController = self.window?.rootViewController as? TabbedSplitViewController {
            let logger = Logger()
            viewController.logger = logger
            var config = viewController.config
            config.showMasterAsSideBarWithSizeChange = { size, traits, config in
                logger.log("hideMaster: traits.userInterfaceIdiom = \(traits.userInterfaceIdiom)")
                logger.log("hideMaster: size.width = \(size.width)")
                /// Master should be hidden on iPad in Portrait or in multi-tasking mode unless it's iPhone-width.
                let should = traits.userInterfaceIdiom == .pad
                            && size.width >= 678 /* iPad 12" half-screen */
                            && size.width <= 978 /* iPad 12" 2/3 screen */

                logger.log("hideMaster: \(should)")
                return should
            }
            config.showDetailAsModalWithSizeChange = { size, traits, config in
                logger.log("hideDetail: traits.horizontalSizeClass = \(traits.horizontalSizeClass)")
                logger.log("hideDetail: size.width = \(size.width)")
                /// Use on iPad in compact mode and on iPhone except Plus models in landscape
                let should = traits.horizontalSizeClass == .compact
                            // iPhone X/Xs Landscape
                            && size.width < (tabBarWidth + masterWidth + minDetailWidth)
                logger.log("hideDetail: \(should)")
                return should
            }
            config.showTabBarAsSideBarWithSizeChange = { size, traits, config in
                logger.log("hideTabBar: traits.horizontalSizeClass = \(traits.horizontalSizeClass)")
                logger.log("hideTabBar: size.width = \(size.width)")
                /// Use on iPad in compact mode and on iPhone 4s/5/5s/SE
                let should = traits.horizontalSizeClass == .compact && size.width <= 375 /* Regular iPhone width */
                logger.log("hideTabBar: \(should)")
                return should
            }
            config.tabBarBackgroundColor = .purple
            config.detailBackgroundColor = .blue
            config.verticalSeparatorColor = .orange
            config.detailAsModalShouldStayInPlace = true

            viewController.config = config

            // Master view controllers
            let vc1 = configureMasterViewController1(with: viewController)
            let vc2 = configureMasterViewController2(with: viewController)

            // Default detail view controller, optional
            let defaultDetailVC = self.instantiateDetail()
            viewController.defaultDetailViewController = defaultDetailVC

            // Main tab bar – view controllers
            viewController.addToTabBar(PKTabBarItem(title: "Screen 1", image: #imageLiteral(resourceName: "Peotr"), selectedImage: #imageLiteral(resourceName: "Peotr2"), action: vc1.embeddedInNavigationController()))
            // Second screen's icon is rendered as template so it changes tint color when selected,
            //   unlike the first screen's icon.
            viewController.addToTabBar(PKTabBarItem(title: "Screen 2", image: #imageLiteral(resourceName: "Address"), action: vc2.embeddedInNavigationController()))
            // Actions bar – closures
            viewController.addToActionBar(PKTabBarItem(title: "About", image: #imageLiteral(resourceName: "About")) { [unowned viewController] in
                let alert = UIAlertController(title: "About", message: "TabbedSplitViewController v0.1", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .default))
                viewController.present(alert, animated: true)
            })

            viewController.addToTabBar(PKTabBarItem(title: "Full Width", image: UIImage(named: "Analytics")!, action: (vc: FullWidthViewController(), isFullWidth: true)))
        }

        return true
    }

    private func configureMasterViewController1(with split: TabbedSplitViewController) -> UIViewController {
        let vc = self.instantiateMaster()
        vc.screenText = "Screen 1111"
        vc.onButtonPressed = { [unowned split] text in
            let controller = DetailController(text: "Button: \(text)")
            controller.onCloseButtonPressed = {
                let time = Date()
                split.dismissDetailViewController(animated: $0) {
                    print("\(Date().timeIntervalSince(time)) Finished dismissing \("Button: \(text)")")
                }
            }
            let time = Date()
            split.showDetailViewController(controller.embeddedInNavigationController()) {
                print("\(Date().timeIntervalSince(time)) Finished presenting \("Button: \(text)")")
            }
        }
        vc.onTableButtonPressed = { [unowned split] text in
            let controller = UITableViewController(style: .plain)
            controller.title = "Generic Table View Controller"
            split.showDetailViewController(controller.embeddedInNavigationController())
        }
        vc.onSwitchTabButtonPressed = { [unowned split] text in
            split.selectedTabBarItemIndex = 1
        }

        return vc
    }
    private func configureMasterViewController2(with split: TabbedSplitViewController) -> UIViewController {
        let vc = self.instantiateMaster()
        vc.screenText = "Screen 22222"
        vc.onButtonPressed = { [unowned split] text in
            let controller = DetailController(text: "Button: \(text)")
            controller.onCloseButtonPressed = {
                let time = Date()
                split.dismissDetailViewController(animated: $0) {
                    print("\(Date().timeIntervalSince(time)) Finished dismissing \("Button: \(text)")")
                }
            }
            let time = Date()
            split.showDetailViewController(controller.embeddedInNavigationController()) {
                print("\(Date().timeIntervalSince(time)) Finished presenting \("Button: \(text)")")
            }
        }
        vc.onSwitchTabButtonPressed = { [unowned split] text in
            split.selectedTabBarItemIndex = 0
        }
        vc.onInsertTabButtonPressed = { [unowned split] text in
            self.insertNewTab(to: split, at: 1)
        }

        return vc
    }

    private func insertNewTab(to vc: TabbedSplitViewController, at index: Int) {
        let vc3 = self.instantiateMaster()
        vc3.screenText = "Screen 33333"
        vc3.onRemoveTabButtonPressed = { [unowned vc] text in
            vc.removeFromTabBar(at: index)
        }
        vc.insertToTabBar(PKTabBarItem(title: "Multiline Tab Title", image: #imageLiteral(resourceName: "Address"), action: (vc3.embeddedInNavigationController(), false)), at: index)
    }

    private func storyboard() -> UIStoryboard {
        return UIStoryboard(name: "Main", bundle: nil)
    }
    private func instantiateMaster() -> ViewController {
        storyboard().instantiateViewController(withIdentifier: "MasterViewController") as! ViewController
    }
    private func instantiateDetail() -> UIViewController {
        storyboard().instantiateViewController(withIdentifier: "DefaultDetailScreen")
    }
}

extension UIViewController {

    /// Returns navigation controller instance with current controller as a root view controller
    func embeddedInNavigationController() -> UINavigationController {
        return embeddedInNavigationController(presentationStyle: .none)
    }
    /// Returns navigation controller instance with current controller as a root view controller
    func embeddedInNavigationController(presentationStyle: UIModalPresentationStyle) -> UINavigationController {
        let navController = UINavigationController(rootViewController: self)
        navController.modalPresentationStyle = presentationStyle
        return navController
    }
    
}

extension UIUserInterfaceIdiom: CustomStringConvertible {

    public var description: String {
        switch self {
        case .unspecified: return ".unspecified"
        case .phone: return ".phone"
        case .pad: return ".pad"
        case .tv: return ".tv"
        case .carPlay: return ".carPlay"
        }
    }
}

extension UIUserInterfaceSizeClass: CustomStringConvertible {

    public var description: String {
        switch self {
        case .unspecified: return ".unspecified"
        case .compact: return ".compact"
        case .regular: return ".regular"
        }
    }
}

