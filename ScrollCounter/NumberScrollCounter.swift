//
//  NumberScrollCounter.swift
//  ScrollCounter
//
//  Created by Shant Tokatyan on 12/7/19.
//  Copyright © 2019 Stokaty. All rights reserved.
//

import UIKit

/**
 A view that composes a collection of `DigitScrollCounter`s and punctuations to create a number that can be animated with a scrolling effect as seen in the Robinhood app.
 */
public class NumberScrollCounter: UIView {
    
    // MARK: - Parameters
    
    /// The `DigitScrollCounter`s that are stacked horizontally to make up the displayed number.
    private var digitScrollers = [DigitScrollCounter]()

    /// The animation duration used when fading-out a `DigitScrollCounter`.  This is calculated as half of `slideDuration`.
    private var fadeOutDuration: TimeInterval {
        return slideDuration / 2
    }
    /// The animation duration used when a `DigitScrollCounter` is scrolling to a number.
    public var scrollDuration: TimeInterval
    /// The animation duration when the items in `digitScrollers` are slid to their new origins.
    public var slideDuration: TimeInterval = 0.5
    
    /// The current value being displayed, or the number being animated to if the `NumberScrollCounter` is still animating.
    public private(set) var currentValueString: String?
    /// The current string being displayed as-is (with prexix, suffix, separator and delimiters)
    public private(set) var currentString: String?
    /// Negative value flag calculated from `currentValueString`
    private var isCurrentValueNagative: Bool = false
    /// The current completion closure
    private var currentCopmletion: (() -> Void)?
    
    /// The spacing between the `seperator` and the adjacent items in `digitScrollers`.
    public var seperatorSpacing: CGFloat
    /// The font to use for all of the labels used in building the `NumberScrollCounter`.
    public var font: UIFont
    /// The text color to use for all of the labels used in building the `NumberScrollCounter`.
    public let textColor: UIColor
    /// The number of decimal places that should be displayed. Set 0 to display all digits after `seperator` in `currentValueString`
    public var decimalPlaces: Int {
        didSet {
            if let currentValueString = currentValueString {
                setValue(currentValueString, animated: false)
            }
        }
    }
    /// Calculated number of decimal places that should be displayed. It has different value from `decimalPlaces` is it value equals 0.
    private var calculatedDecimalPlaces: Int = 0
    
    /// The string to use as a prefix to the items in `digitScrollers`.
    public var prefix: String? {
        didSet {
            if let prefixLabel = prefixView as? UILabel, prefixLabel.text != prefix {
                prefixLabel.text = prefix
                prefixLabel.sizeToFit()
            }
        }
    }
    /// The string to use as a suffix to the items in `digitScrollers`.
    public var suffix: String? {
        didSet {
            if let suffixLabel = suffixView as? UILabel, suffixLabel.text != suffix {
                suffixLabel.text = suffix
                suffixLabel.sizeToFit()
            }
        }
    }
    /// The string to use as the decimal indicator for the items in `digitScrollers`.
    public var seperator: String {
        didSet {
            if let seperatorLabel = seperatorView as? UILabel {
                seperatorLabel.text = seperator
                seperatorLabel.sizeToFit()
            }
        }
    }
    /// The string that will be used to represent negative values.
    public let negativeSign = "-"

    /// The string to use as the delimiter for the items in `digitScrollers`.
    public var delimeterSign: String? {
        didSet {
            delimeterViews
                .compactMap {
                    $0 as? UILabel
                }
                .forEach {
                    $0.text = delimeterSign ?? ""
                }
        }
    }
    /// Number of digits in whole number part to seperate by `delimeterSign`.
    public let delimeterGroup: Int
    /// Calulated delimiter indexes for `currentValueString`
    private var delimeterPositions: Set<Int> = []
    /// Delimiter presentation views
    private var delimeterViews: [UIView] = []
    
    /// The view that holds the prefix, or `nil` if there is no prefix.
    private var prefixView: UIView?
    /// The view that holds the suffix, or `nil` if there is no suffix.
    private var suffixView: UIView?
    /// The view that holds the seperator, or `nil` if there is no seperator.
    private var seperatorView: UIView?
    /// The view that holds the negative sign, or `nil` if the number is not negative.
    private var negativeSignView: UIView?
    
    private let gradientColor: UIColor?
    private let gradientStop: Float?
    
    /// The animator controlling the current animation in the ScrollableCounter.
    private var animator: UIViewPropertyAnimator?
    
    /// The animation curve for a scroll animation.
    var animationCurve: AnimationCurve = .easeInOut
    
    /// The starting x-coordinate for the stacked views, this only changes when a negative sign needs to be displayed.
    private var startingXCoordinate: CGFloat {
        var startingX: CGFloat = 0
        if let prefixView = prefixView {
            startingX += prefixView.frame.width
        }
        if let negativeSignView = negativeSignView, isCurrentValueNagative {
            startingX += negativeSignView.frame.width
        }
        return startingX
    }

    public override var intrinsicContentSize: CGSize {
        .init(
            width: suffixView?.frame.maxX ?? digitScrollers.last?.frame.maxX ?? frame.width,
            height: digitScrollers.first?.frame.height ?? frame.height
        )
    }
    
    // MARK: - Init
    
    /**
     Initialize a `NumberScrollCounter` with the given parameters.
     
     After the view is initializes, it's digit scrollers will be set to the given values, and the frame will be resized using `sizeToFit()`.
     
     - note:
     To get a design similar to Robinhood, try using `"Avenir-Black"` as the font.
     
     - parameters:
        - value: The initial value to display.
        - scrollDuration: The duration that is used when animating a single digit's scrolling animation.  Defaults to `0.3`.
        - decimalPlaces: The number of decimals to display.  Defaults to `0`.
        - prefix: The prefix to use in front of the displayed number.  Defaults to `nil`, which results in no prefix.
        - suffix: The suffix to use at the end of the displayed number.  Defaults to `nil`, which results in no suffix.
        - seperator: The seperator to use to represent a decimal.  Defaults to `"."`.
        - seperatorSpacing: The spacing to use between the seperator and the adjacent digits.  Defaults to `5`.
        - font: The font to use for the digits, prefix, suffix, and seperator.
        - textColor: The text color to use for the digits, prefix, suffix, and seperator.
        - animateInitialValue: Whether or not the initial value should be animated to. Defaults to `false`.
        - gradientColor: The color to use for the vertical gradient.  If this is `nil`, then no gradient is applied.
        - gradientStop: The stopping point for the gradient, where the bottom stopping point is (1 - gradientStop).  If gradientStop is not less than 0.5 than it is ignored.  If this is `nil`, then no gradient is applied.
     */
    public init(
        value: String,
        scrollDuration: TimeInterval = 0.3,
        decimalPlaces: Int = 0,
        prefix: String? = nil,
        suffix: String? = nil,
        seperator: String = ".",
        seperatorSpacing: CGFloat = 0,
        delimeterSign: String? = nil,
        delimeterGroup: Int = 0,
        font: UIFont = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize),
        textColor: UIColor = .black,
        animateInitialValue: Bool = false,
        gradientColor: UIColor? = nil,
        gradientStop: Float? = nil
    ) {

        self.currentValueString = value
        self.decimalPlaces = decimalPlaces
        self.font = font
        self.textColor = textColor
        
        self.prefix = prefix
        self.suffix = suffix
        self.seperator = seperator
        self.seperatorSpacing = seperatorSpacing
        self.delimeterSign = delimeterSign
        self.delimeterGroup = delimeterGroup
        
        self.scrollDuration = scrollDuration
        self.gradientColor = gradientColor
        if let stoppingPoint = gradientStop, stoppingPoint < 0.5 {
            self.gradientStop = gradientStop
        } else {
            self.gradientStop = nil
        }
        
        super.init(frame: CGRect.zero)
        
        setValue(value, animated: animateInitialValue)
        frame.size.height = digitScrollers.first!.height
        
        sizeToFit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func sizeToFit() {
        var width: CGFloat = 0
        
        if let suffixView = suffixView {
            width = suffixView.frame.origin.x + suffixView.frame.width
        } else if let lastDigit = digitScrollers.last {
            width = lastDigit.frame.origin.x + lastDigit.frame.width
        }
        
        self.frame.size.width = width
    }
    
    /**
     Recreate all views to apply Dynamic Type changes
     */
    public func resetLayout() {
        
        animator?.stopAnimation(true)
        
        let scrollersCount = digitScrollers.count
        updateScrollers(remove: scrollersCount, animated: false)
        if let seperatorView = seperatorView {
            if seperatorView.superview != nil {
                seperatorView.removeFromSuperview()
            }
            self.seperatorView = nil
        }
        
        if let prefixView = prefixView {
            if prefixView.superview != nil {
                prefixView.removeFromSuperview()
            }
            self.prefixView = nil
        }
        
        if let suffixView = suffixView {
            if suffixView.superview != nil {
                suffixView.removeFromSuperview()
            }
            self.suffixView = nil
        }
        
        if let negativeSignView = negativeSignView {
            if negativeSignView.superview != nil {
                negativeSignView.removeFromSuperview()
            }
            self.negativeSignView = nil
        }
        
        delimeterViews.forEach {
            $0.removeFromSuperview()
        }
        delimeterViews = []
        
        if let valueStr = currentValueString {
            setValue(valueStr, animated: false)
        }
    }
    
    public func stopAnimations() {
        animator?.stopAnimation(true)
    }
    
    // MARK: - Control
    
    /**
     Updates the value to be displayed, and then immediately displays it or animates into it.
     - parameters:
        - value: The value to display.
        - animated: Whether or not the scrolling should be animated.  Defaults to `true`.
     */
    public func setValue(_ value: Float, animated: Bool = true, completion: (() -> Void)? = nil) {
        let stringValue = String(format: "%.\(decimalPlaces)f", value)
        setValue(stringValue, animated: animated, completion: completion)
    }
    
    /**
     Updates the value to be displayed, and then immediately displays it or animates into it.
     - parameters:
        - value: The string value to display. Suitable to display Decimal type values.
        - animated: Whether or not the scrolling should be animated.  Defaults to `true`.
     */
    public func setValue(_ value: String, animated: Bool = true, completion: (() -> Void)? = nil) {
        currentValueString = value
        isCurrentValueNagative = value.hasPrefix(negativeSign)
        currentCopmletion = completion
        
        var digitString = getStringArray(fromValue: value)
        if let sepraratorIdx = digitString.lastIndex(of: seperator) {
            let numberOfFractionalDigits = digitString.count - 1 - sepraratorIdx
            if decimalPlaces == 0 {
                calculatedDecimalPlaces = numberOfFractionalDigits
            }
            else {
                if decimalPlaces < numberOfFractionalDigits {
                    let dropCount = numberOfFractionalDigits - decimalPlaces
                    digitString.removeLast(dropCount)
                    calculatedDecimalPlaces = decimalPlaces
                }
                else {
                    calculatedDecimalPlaces = numberOfFractionalDigits
                }
            }
        }
        else {
            calculatedDecimalPlaces = 0
        }
        
        var digitsOnly = [Int]()
        for entry in digitString {
            if let value = Int(entry) {
                digitsOnly.append(value)
            }
        }
        
        if digitsOnly.count > digitScrollers.count {
            let digitsToAdd = digitsOnly.count - digitScrollers.count
            updateScrollers(add: digitsToAdd)
        } else if digitScrollers.count > digitsOnly.count {
            let digitsToRemove = digitScrollers.count - digitsOnly.count
            updateScrollers(remove: digitsToRemove, animated: animated)
        }
        
        let wholeDigitCount = digitsOnly.count - calculatedDecimalPlaces
        
        updateScrollers(withDigits: digitsOnly, animated: animated)
        updateDelimeters(digitPositions: wholeDigitCount, delimeterGroup: delimeterGroup)
        updateScrollerLayout(animated: animated)
    }
    
    private func getStringArray(fromValue value: String) -> [String] {
        value.compactMap { character -> String in
            var entry = String(character)
            let result = character.wholeNumberValue
            if let resultNumber = result {
                entry = "\(resultNumber)"
            }
            return entry
        }
    }
    
    // MARK: - Scroller Updates
    
    /**
     Updates the layout of the subviews used for displaying the current number.
     
     The updates to the layouts involves the following steps:
        1. Stop the animator if it is currently animating.
        2. Update the negative sign (whether or not it exists).
        3. Update the prefix (the position will change depending on the negative signs existance).
        4. Create the decimal seperator if it is needed and one does not exist.
        5. Update the layout of each item in`digitScrollers`, the negative sign, prefix, and decimal.
        6. Update the location of the suffix.
        7. Animate the transition to the updated layout.
     
     - parameters:
        - animated: Whether or not the scrolling should be animated.  Defaults to `true`.
     */
    private func updateScrollerLayout(animated: Bool) {
        if let animator = self.animator {
            animator.stopAnimation(true)
        }
        
        var animationDuration = slideDuration
        if !animated {
            animationDuration = ScrollableCounter.noAnimationDuration
        }
        animator = UIViewPropertyAnimator(duration: animationDuration, curve: animationCurve, animations: nil)
        
        updateNegativeSign()
        updatePrefix()
        createSeperatorViewIfNeeded()
        updateDigitScrollersLayout()
        updateSuffix()
                
        animator!.addCompletion({ position in
            if position == .end, let completion = self.currentCopmletion {
                completion()
            }
            self.animator = nil
        })

        invalidateIntrinsicContentSize()
        animator?.addAnimations { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
        animator!.startAnimation()
    }
    
    /**
     Creates a seperator view if one is needed but does not exist.  This does not update the layout of the seperator view.
     */
    private func createSeperatorViewIfNeeded() {
        guard calculatedDecimalPlaces > 0, seperatorView == nil else {
            return
        }
        
        let seperatorLabel = UILabel()
        seperatorLabel.text = seperator
        seperatorLabel.textColor = textColor
        seperatorLabel.font = font
        seperatorLabel.adjustsFontForContentSizeCategory = false
        seperatorLabel.sizeToFit()
        seperatorLabel.frame.size.width += 2 * seperatorSpacing
        seperatorLabel.textAlignment = .center
        seperatorLabel.frame.origin = CGPoint.zero
        addSubview(seperatorLabel)
        
        seperatorLabel.alpha = 0
        seperatorView = seperatorLabel
    }
    
    /**
     Updates the layout of each item in `digitScrollers` and the seperator accordingly.
     */
    private func updateDigitScrollersLayout() {
        guard let animator = self.animator else {
            return
        }
        
        let startingX = startingXCoordinate
        let seperatorIndex = digitScrollers.count - calculatedDecimalPlaces
        var trailingX = startingX
        var delimeterIndex = 0
        
        for (index, scroller) in digitScrollers.enumerated() {
            if delimeterPositions.contains(index) {
                let delimeterView = delimeterViews[delimeterIndex]
                delimeterView.frame.origin.x = trailingX
                delimeterIndex += 1
                trailingX += delimeterView.frame.width
                animator.addAnimations {
                    delimeterView.alpha = 1
                }
            }
            
            let separatorPosition = trailingX
            if index == seperatorIndex, let seperatorView = seperatorView {
                animator.addAnimations {
                    seperatorView.alpha = 1
                    seperatorView.frame.origin.x = separatorPosition
                }
                trailingX += seperatorView.frame.size.width
            }
            
            let scrollerPosition = trailingX
            if scroller.superview == nil {
                addSubview(scroller)
                scroller.frame.origin.x = scrollerPosition
                scroller.alpha = 0
                animator.addAnimations {
                    scroller.alpha = 1
                }
            }
            else {
                animator.addAnimations {
                    scroller.alpha = 1
                    scroller.frame.origin.x = scrollerPosition
                }
            }
            trailingX += scroller.frame.size.width
        }
    }

    /**
     Updates whether or not a negative sign is needed, and then animates any changes accordingly.
     */
    private func updateNegativeSign() {
        guard let animator = self.animator else {
            return
        }
        
        if isCurrentValueNagative {
            if let negativeSignView = negativeSignView, negativeSignView.alpha != 1 {
                animator.addAnimations {
                    negativeSignView.alpha = 1
                }
            } else if negativeSignView == nil {
                let negativeLabel = UILabel()
                negativeLabel.text = negativeSign
                negativeLabel.textColor = textColor
                negativeLabel.font = font
                negativeLabel.adjustsFontForContentSizeCategory = false
                negativeLabel.sizeToFit()
                negativeLabel.frame.origin = CGPoint.zero
                addSubview(negativeLabel)
                
                negativeLabel.alpha = 0
                negativeSignView = negativeLabel
                animator.addAnimations {
                    negativeLabel.alpha = 1
                }
            }
        } else {
            if let negativeSignView = negativeSignView {
                animator.addAnimations {
                    negativeSignView.alpha = 0
                }
                animator.addCompletion { _ in
                    negativeSignView.removeFromSuperview()
                    self.negativeSignView = nil
                }
            }
        }
    }
    
    /**
     Updates the location of the prefix (if there is one), and then animates any changes accordingly.
    */
    private func updatePrefix() {
        guard let animator = self.animator else {
            return
        }
        
        if prefixView == nil, let prefix = prefix {
            let prefixLabel = UILabel()
            prefixLabel.text = prefix
            prefixLabel.textColor = textColor
            prefixLabel.font = font
            prefixLabel.adjustsFontForContentSizeCategory = false
            prefixLabel.sizeToFit()
            prefixLabel.frame.origin = CGPoint.zero
            addSubview(prefixLabel)

            prefixLabel.alpha = 0
            prefixView = prefixLabel
        }
        
        if let prefixView = self.prefixView {
            var prefixX: CGFloat = 0
            if let negativeSignView = negativeSignView, isCurrentValueNagative {
                prefixX = negativeSignView.frame.width
            }
            animator.addAnimations {
                prefixView.frame.origin.x = prefixX
                prefixView.alpha = 1
            }
        }
    }
    
    /**
     Updates the location of the suffix (if there is one), and then animates any changes accordingly.
    */
    private func updateSuffix() {
        guard let animator = self.animator else {
            return
        }
        
        if suffixView == nil, let suffix = suffix {
            let suffixLabel = UILabel()
            suffixLabel.text = suffix
            suffixLabel.textColor = textColor
            suffixLabel.font = font
            suffixLabel.adjustsFontForContentSizeCategory = false
            suffixLabel.sizeToFit()
            suffixLabel.frame.origin = CGPoint.zero
            addSubview(suffixLabel)

            suffixLabel.alpha = 0
            suffixView = suffixLabel
        }

        if let suffixView = self.suffixView, let scroller = digitScrollers.first {
            var suffixX: CGFloat = 0
            suffixX += scroller.frame.width * CGFloat(digitScrollers.count)
            if let view = seperatorView {
                suffixX += view.frame.width
            }
            if let view = prefixView {
                suffixX += view.frame.width
            }
            if let view = negativeSignView, isCurrentValueNagative {
                suffixX += view.frame.width
            }
            if let delimeterView = delimeterViews.first {
                suffixX += delimeterView.frame.width * CGFloat(delimeterViews.count)
            }
            
            animator.addAnimations {
                suffixView.frame.origin.x = suffixX
                suffixView.alpha = 1
            }
        }
    }
    
    /**
     Updates the number of items in `digitScrollers` by adding the given number of additional scrollers.
     
     Items are added by inserting them to the beggining of `digitScrollers`.
     This is reflected as digits being inserted before the left-most digit of the number.
     
     - parameters:
        - count: The number of digits to add.
     */
    private func updateScrollers(add count: Int) {
        var newScrollers = [DigitScrollCounter]()
        for _ in 0..<count {
            let digitScrollCounter = DigitScrollCounter(
                font: font,
                textColor: textColor,
                backgroundColor: .clear,
                scrollDuration: scrollDuration,
                gradientColor: gradientColor,
                gradientStop: gradientStop
            )
            newScrollers.append(digitScrollCounter)
        }
        digitScrollers.append(contentsOf: newScrollers)
    }
    
    /**
    Updates the number of items in `digitScrollers` by removing the given number of scrollers.
    
    Items are removed by removing them from the beggining of `digitScrollers`.
    This is reflected as the left-most digit of the number being removed.
    
    - parameters:
       - count: The number of digits to remove.
       - animated: Whether or not the scrolling should be animated.
    */
    private func updateScrollers(remove count: Int, animated: Bool) {
        var animationDuration = fadeOutDuration
        if !animated {
            animationDuration = ScrollableCounter.noAnimationDuration
        }
        for _ in 0..<count {
            let scroller = digitScrollers.removeLast()
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
                scroller.alpha = 0
            }) { _ in
                scroller.removeFromSuperview()
            }
        }
    }
    
    /**
     Updates the digit displayed by each item in `digitScrollers`.
     
     - note:
     This funciton will do nothing if `digits` does not have the same number of elements as `digitScrollers`.
     
     - parameters:
        - digits: The digits that each item in `digitScrollers` should be scroleld to.
        - animated: Whether or not the scrolling should be animated.  Defaults to `true`.
     */
    private func updateScrollers(withDigits digits: [Int], animated: Bool) {
        if digits.count == digitScrollers.count {
            for (i, scroller) in digitScrollers.enumerated() {
                scroller.scrollToItem(atIndex: digits[i], animated: animated)
            }
        }
    }
    
    // MARK: - Delimiters
    
    /**
     Updates the delimiters displayed between `digitScrollers`.
     */
    private func updateDelimeters(digitPositions: Int, delimeterGroup: Int) {
        delimeterPositions = delimeterIndexes(for: digitPositions, digitsInGroup: delimeterGroup)
        let diff = delimeterViews.count - delimeterPositions.count
        if diff < 0 { // Add delimeters
            for _ in 0..<diff.magnitude {
                let delimeterView = buildDelimeterView()
                addSubview(delimeterView)
                delimeterViews.append(delimeterView)
            }
        }
        else if diff > 0 {
            for _ in 0..<diff.magnitude {
                let delimeterToRemove = delimeterViews.removeFirst()
                delimeterToRemove.removeFromSuperview()
            }
        }
    }
    
    /**
     Builds view to delimiter presentation
     */
    private func buildDelimeterView() -> UIView {
        let delimeterLabel = UILabel()
        delimeterLabel.text = delimeterSign
        delimeterLabel.textColor = textColor
        delimeterLabel.font = font
        delimeterLabel.adjustsFontForContentSizeCategory = false
        delimeterLabel.sizeToFit()
        delimeterLabel.textAlignment = .center
        delimeterLabel.frame.origin = CGPoint.zero
        delimeterLabel.alpha = 0
        return delimeterLabel
    }
    
    /**
     Calculates delimiter positions.
     
     - parameters:
        - digitsCount: total number of digits for that delimiter positions will be calculated
        - digitsInGroup: number of digits in groups that will be separated by delimiters
     */
    private func delimeterIndexes(for digitsCount: Int, digitsInGroup: Int) -> Set<Int> {
        guard digitsCount > 0, digitsInGroup > 0 else {
            return []
        }

        var delimetersCount = digitsCount / digitsInGroup
        if digitsCount % digitsInGroup == 0 {
            delimetersCount -= 1 // No delimeter before first digit
        }
        guard delimetersCount > 0 else {
            return []
        }
        
        var result = Set<Int>()
        for i in 1...delimetersCount {
            let pos = digitsCount - i * digitsInGroup
            result.insert(pos)
        }
        return result
    }
}
