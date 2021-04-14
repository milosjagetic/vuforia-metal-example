//
//  VuforiaSceneView.swift
//  VuforiaSample
//
//  Created by Milos Jagetic on 11/03/2021.
//

import UIKit
import MetalKit
import SceneKit

protocol VuforiaSceneViewDataSource: class
{
    func scene(for view: VuforiaView, userInfo: [String : Any]) -> SCNScene
}


enum VuforiaViewError: Error
{
    case prepareError(message: String)
    case noCameraAccess
}

class VuforiaView: UIView
{
    struct DebugOptions: OptionSet
    {
        let rawValue: Int
        
        static let showTargetBounds: DebugOptions = DebugOptions(rawValue: 1 << 0)
        static let showWorldOrigin: DebugOptions = DebugOptions(rawValue: 1 << 1)
    }

    var debugOptions: DebugOptions = []
    
    var configurationChanged = true
    
    weak var sceneDataSource: VuforiaSceneViewDataSource?

    let renderer: MetalRenderer

    override class var layerClass: AnyClass
    {
        return CAMetalLayer.self
    }
        
    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Lifecycle -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    init(renderer: MetalRenderer, frame: CGRect)
    {
        self.renderer = renderer
        
        super.init(frame: frame)
        
        let layer = self.layer as! CAMetalLayer
        layer.device = renderer.metalDevice
        layer.pixelFormat = renderer.pixelFormat
        layer.framebufferOnly = true
        layer.contentsScale = renderer.contentScale

    }
    
    override init(frame: CGRect) { fatalError("This init is not implemented. Use `init(renderer:)`.") }
    
    required convenience init?(coder: NSCoder) { fatalError("This init is not implemented. Use `init(renderer:)`.") }

    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: SceneKit -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    func setNeedsChangeScene(userInfo: [String : Any])
    {
        guard let scene = self.sceneDataSource?.scene(for: self, userInfo: userInfo) else { return }

        renderer.replaceSceneKitScene(scene)
    }

    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Vuforia -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    func configureVuforia()
    {
        let screenSize = bounds.size

        ARController.shared.configureRendering(withWidth: screenSize.width * self.contentScaleFactor,
                                      height: screenSize.height * self.contentScaleFactor,
                                      orientation: window?.windowScene?.interfaceOrientation ?? .portrait)
    }
    
    
    @objc func renderFrameVuforia()
    {
        guard ARController.shared.isARActive else { return }
        
        if (configurationChanged)
        {
            configurationChanged = false
            configureVuforia()
        }

        renderer.renderVuforiaFrame(vuforiaView: self, controller: ARController.shared, debugOptions: debugOptions)
    }   
}
