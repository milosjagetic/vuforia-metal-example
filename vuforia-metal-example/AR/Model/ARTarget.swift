//
//  ARTarget.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 22/03/2021.
//

import UIKit

@objcMembers class ARTarget
{
    var name: String
    var size: CGSize
    
    init(name: String, size: CGSize)
    {
        self.name = name
        self.size = size
    }
}
