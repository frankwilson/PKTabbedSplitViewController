//
//  VerticalSeparatorView.swift
//  TabbedSplitViewController
//
//  Created by Pavel Kazantsev on 10/27/18.
//  Copyright © 2018 PaKaz.net. All rights reserved.
//

import UIKit

final class VerticalSeparatorView: UIView {

    private let solidPart: UIView = UIView()
    private let gradientLayer: CAGradientLayer = CAGradientLayer()

    override var backgroundColor: UIColor? {
        get {
            return solidPart.backgroundColor
        }
        set {
            solidPart.backgroundColor = newValue
            updateGradient()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addChildView(solidPart, top: false)
        solidPart.topAnchor.constraint(equalTo: topAnchor, constant: 22).isActive = true
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 22)
        layer.addSublayer(gradientLayer)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        gradientLayer.frame.size.width = layer.frame.width
    }

    private func updateGradient() {
        guard let color = backgroundColor else {
            gradientLayer.colors = nil
            return
        }
        gradientLayer.colors = [UIColor.clear.cgColor,
                                color.withAlphaComponent(0.4).cgColor,
                                color.cgColor]
    }
}
