//
//  Helper.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 14/04/2021.
//

import Foundation

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: UIView helpers -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
extension UIView
{
    var x: CGFloat
    {
        get { return frame.origin.x }
        set { frame = CGRect(x: newValue, y: y, width: frame.width, height: frame.height) }
    }
    
    var y: CGFloat
    {
        get { return frame.origin.y }
        set { frame = CGRect(x: x, y: newValue, width: frame.width, height: frame.height) }
    }
    
    var width: CGFloat
    {
        get { return frame.size.width }
        set { frame = CGRect(x: x, y: y, width: newValue, height: height)}
    }
    
    var height: CGFloat
    {
        get { return frame.size.height }
        set { frame = CGRect(x: x, y: y, width: width, height: newValue) }
    }
    
    var deepSubviews: [UIView]
    {
        return subviews + subviews.flatMap({$0.deepSubviews})
    }
}


extension UIView
{    
    func pinToSuperview(padding: UIEdgeInsets = .zero)
    {
        guard let _ = self.superview else { return }
        
        pinToSuperview(axis: .horizontal, padding: padding)
        pinToSuperview(axis: .vertical, padding: padding)
    }
    
    func pinToSuperview(axis: NSLayoutConstraint.Axis, padding: UIEdgeInsets = .zero)
    {
        let dir: String = axis == .horizontal ? "H" : "V"
        let leadingPadding: CGFloat = axis == .horizontal ? padding.left : padding.top
        let trailingPadding: CGFloat = axis == .horizontal ? padding.right : padding.bottom
        
        NSLayoutConstraint.constrain("\(dir):|-\(leadingPadding)-[x]-\(trailingPadding)-|", view: self)
    }

    func addAndPinToSuperview(superview: UIView, padding: UIEdgeInsets = .zero)
    {
        superview.addSubview(self)
        pinToSuperview(padding: padding)
    }
}

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: NSLayoutConstraint helpers -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
extension NSLayoutConstraint
{
    static func constrain(_ format: String, views: [String: Any]? = nil)
    {
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: format, options: [], metrics: nil, views: views ?? [:]))
    }
    
    static func constrain(_ format: String, view: UIView)
    {
        constrain(format, views: ["x" : view])
    }
}
