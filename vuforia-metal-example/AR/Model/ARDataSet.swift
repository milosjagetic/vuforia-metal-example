//
//  ARTarget.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 17/03/2021.
//

import Foundation

@objcMembers class ARDataSet: NSObject
{
    @objc private(set) var fileName: String!
    
    private(set) var targets: [ARTarget] = []
    
    init(fileName: String)
    {
        self.fileName = fileName
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil),
              let data = try? Data(contentsOf: url) else { return }
        
        targets = ARTargetParser(data: data).targets
    }
    
    override init() { fatalError("this init is not supported") }
}
