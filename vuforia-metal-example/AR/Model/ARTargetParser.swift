//
//  ARTargetParser.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 25/03/2021.
//

import UIKit

class ARTargetParser: XMLParser, XMLParserDelegate
{
    var targets: [ARTarget] = []
    
    //xml structure check
    private var isARConfiguration: Bool = false
    //xml structure check
    private var isDataSet: Bool = false
    
    private static let sizeFormatter: NumberFormatter =
    {
        let numberFormatter: NumberFormatter = NumberFormatter()
        numberFormatter.decimalSeparator = "."
        
        return numberFormatter
    }()

    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Lifecycle -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    override init(data: Data)
    {
        super.init(data: data)
        
        delegate = self
        
        parse()
    }
    
    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: XMLParserDelegate protocol implementation -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:])
    {
        switch elementName
        {
        case "QCARConfig": isARConfiguration = true
        case "Tracking": isDataSet = true
        case "ImageTarget":
            guard isARConfiguration && isDataSet else { break }
            
            guard let name = attributeDict["name"],
                  let sizeString = attributeDict["size"] else { break }
            
            let sizeComponents: [String] = sizeString.components(separatedBy: " ")
            guard sizeComponents.count == 2 else { break }
            
            guard let width = ARTargetParser.sizeFormatter.number(from: sizeComponents[0])?.doubleValue,
                  let height  = ARTargetParser.sizeFormatter.number(from: sizeComponents[1])?.doubleValue else { break }
            
            let target: ARTarget = ARTarget(name: name, size: CGSize(width: width, height: height))
            targets.append(target)
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        switch elementName
        {
        case "QCARConfig": isARConfiguration = false
        case "Tracking": isDataSet = false
        default: break
        }
    }
}
