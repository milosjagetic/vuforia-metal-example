//
//  ARControllerDelegate.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 19/03/2021.
//

import Foundation

@objc protocol ARControllerDelegate: NSObjectProtocol
{
    func arController(_ controller: ARController, didStartTracking result: ARResult)
    func arController(_ controller: ARController, didStopTracking result: ARResult)
}
