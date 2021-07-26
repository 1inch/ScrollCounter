//
//  EnchantedScrollCounter.swift
//  OneInch
//
//  Created by Denis Kirillov on 25.07.2021.
//

import UIKit

/// Enchanted version of ScrollCounter with dynamic type support, horizonal gradient and fadeout vertical gradient
public class EnchantedScrollCounter: UIView {
    
    /// Font color
    /// - Note: if `gradienColors` doesn't equal nil it will override this color
    public var textColor: UIColor {
        didSet {
            updateGradientColors()
        }
    }
    
    /// Colors for horizontal gradient
    public var gradienColors: (UIColor, UIColor)? {
        didSet {
            updateGradientColors()
        }
    }
    
    public var prefix: String? {
        get {
            scrollCounter.prefix
        }
        set {
            scrollCounter.prefix = newValue
        }
    }
    
    public var suffix: String? {
        get {
            scrollCounter.suffix
        }
        set {
            scrollCounter.suffix = newValue
        }
    }
    
    public var fractionalDelimiterSign: String {
        get {
            scrollCounter.seperator
        }
        set {
            scrollCounter.seperator = newValue
        }
    }
    
    public var groupDelimiterSign: String? {
        get {
            scrollCounter.delimeterSign
        }
        set {
            scrollCounter.delimeterSign = newValue
        }
    }
    
    public var decimalPlaces: Int {
        get {
            scrollCounter.decimalPlaces
        }
        set {
            scrollCounter.decimalPlaces = newValue
        }
    }
    
    public let initialValue: String
    
    private var font: UIFont
    private var fontSizeByCategories: [UIContentSizeCategory : CGFloat]
    private var fontBaseSize: CGFloat
    
    private lazy var scrollCounter: NumberScrollCounter = {
        let counter = NumberScrollCounter(
            value: initialValue,
            scrollDuration: 0.3,
            decimalPlaces: 0, // 0 for auto-detect mode
            prefix: nil,
            suffix: nil,
            seperator: ".",
            seperatorSpacing: 0.0,
            delimeterSign: ",",
            delimeterGroup: 3,
            font: font,
            textColor: textColor,
            animateInitialValue: false,
            gradientColor: nil, // turn off inner gradient
            gradientStop: 0
        )
        counter.translatesAutoresizingMaskIntoConstraints = false
        return counter
    }()
    
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = .init(x: 0.0, y: 0.5)
        layer.endPoint = .init(x: 1.0, y: 0.5)
        return layer
    }()

    /// Nested masks are unsupported so we use this proxy layer to fade out vertical borders
    private lazy var fadeProxyLayer: CALayer = {
        let layer = CALayer()
        layer.mask = fadeMaskLayer
        return layer
    }()

    private lazy var fadeMaskLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.locations = [0, 0.2, 0.8, 1] // 20% fade effect on vertical borders
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor,
        ]
        return layer
    }()
    
    // MARK: - Initialization
    
    public init(
        initialValue: String,
        font: UIFont,
        textColor: UIColor = .black,
        gradientColors: (UIColor, UIColor)? = nil
    ) {
        self.initialValue = initialValue
        self.font = font
        self.fontBaseSize = font.pointSize
        self.fontSizeByCategories = Self.buildFontSizeByCategories(for: font)
        self.textColor = textColor
        self.gradienColors = gradientColors

        super.init(frame: .zero)

        setup()
    }

    public func setValue(_ value: String, animated: Bool) {
        scrollCounter.setValue(value, animated: animated)
        invalidateIntrinsicContentSize()
    }

    public func setValue(_ value: Float, animated: Bool) {
        scrollCounter.setValue(value, animated: animated)
        invalidateIntrinsicContentSize()
    }

    private func setup() {
        // Attention here: no `addSubview(scrollCounter)` because it uses as mask
        layer.addSublayer(fadeProxyLayer)
        fadeProxyLayer.addSublayer(gradientLayer)
        gradientLayer.mask = scrollCounter.layer

        updateGradientColors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeChanged),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @objc
    private func preferredContentSizeChanged() {
        let category = UIApplication.shared.preferredContentSizeCategory
        updateFont(category: category)
    }

    public override var intrinsicContentSize: CGSize {
        scrollCounter.intrinsicContentSize
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        fadeProxyLayer.frame = bounds
        fadeMaskLayer.frame = bounds
        gradientLayer.frame = bounds
        scrollCounter.frame = bounds
        
        fitFontSizeIfNeeded()
    }
    
    // MARK: - Gradient setup

    private func updateGradientColors() {
        if let colors = gradienColors {
            gradientLayer.colors = [
                colors.0.cgColor,
                colors.1.cgColor
            ]
        }
        else {
            gradientLayer.colors = [
                textColor.cgColor,
                textColor.cgColor
            ]
        }
    }
    
    // MARK: - Dynamic type support
    
    private static func buildFontSizeByCategories(for font: UIFont) -> [UIContentSizeCategory : CGFloat] {
        let baseSize = font.pointSize
        let multipliers: [UIContentSizeCategory : CGFloat] = [
            .unspecified : 0.7,
            .extraSmall : 0.8,
            .small : 0.9,
            .medium : 1.0,
            .large : 1.05,
            .extraLarge : 1.1,
            .extraExtraLarge : 1.15,
            .extraExtraExtraLarge : 1.2,
            .accessibilityMedium : 1.25,
            .accessibilityLarge : 1.3,
            .accessibilityExtraLarge : 1.35,
            .accessibilityExtraExtraLarge : 1.4,
            .accessibilityExtraExtraExtraLarge: 1.45
        ]
        let categorySizePairs = multipliers.map { category, multiplier in
            (category, multiplier * baseSize)
        }
        let result = Dictionary(uniqueKeysWithValues: categorySizePairs)
        return result
    }
    
    private func updateFont(category: UIContentSizeCategory) {
        let newSize = fontSizeByCategories[category] ?? fontBaseSize
        updateFont(size: newSize)
    }
    
    private func updateFont(size: CGFloat) {
        let newFont = font.withSize(size)
        self.font = newFont
        scrollCounter.stopAnimations()
        scrollCounter.font = newFont
        scrollCounter.resetLayout()
        invalidateIntrinsicContentSize()
    }

    private func fitFontSizeIfNeeded() {
        let step: CGFloat = 0.05 // resize step = 5%
        let contentWidth = intrinsicContentSize.width.rounded(.down)
        let frameWidth = frame.width.rounded(.down)
        if contentWidth > frameWidth {
            let newSize = font.pointSize * (1.0 - step)
            updateFont(size: newSize)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
