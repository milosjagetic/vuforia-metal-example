//
//  ARViewController.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 16/03/2021.
//

import UIKit
import AVKit
import SceneKit

class ARViewController: UIViewController
{
    weak var vuforiaView: VuforiaView!

    lazy var mainScene: SCNScene =
    {
        let scene = SCNScene()
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLightNode)
        
        scene.rootNode.addChildNode(plane)

        return scene
    }()
    
    private var plane: SCNNode =
    {
        var planeNode = SCNNode()
        planeNode.name = "plane"
        planeNode.geometry = SCNPlane(width: 0.5332, height: 0.3)
        planeNode.position = SCNVector3Make(0, 0, -1)

    
        var planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor.green
        planeMaterial.isDoubleSided = true
        planeMaterial.transparency = 0.6
        planeNode.geometry?.firstMaterial = planeMaterial
        
        return planeNode
    }()
    
    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: GUI -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        guard let vuforiaView = VuforiaView.preparedVuforiaView else { return }
        
        vuforiaView.addAndPinToSuperview(superview: view)
        vuforiaView.sceneDataSource = self
        ARController.shared.delegate  = self
        
        self.vuforiaView = vuforiaView
    }
        
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        VuforiaView.vuforiaViewEnded(pause: !isMovingFromParent)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        vuforiaView.setNeedsChangeScene(userInfo: [:])
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        guard !isMovingToParent && !isMovingFromParent else { return }
        
        vuforiaView.configureVuforia()
        ARController.shared.resumeAR()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        vuforiaView.configurationChanged = true
    }
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: VuforiaViewSceneSource protocol implementation -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
extension ARViewController: VuforiaSceneViewDataSource
{
    func scene(for view: VuforiaView, userInfo: [String : Any]) -> SCNScene
    {
        return mainScene
    }
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: ARViewControllerDelegate protocol implementation -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
extension ARViewController: ARControllerDelegate
{
    func arController(_ controller: ARController, didStartTracking target: ARResult)
    {
        (plane.geometry as? SCNPlane)?.width = CGFloat(target.targetSize.x)
        (plane.geometry as? SCNPlane)?.height = CGFloat(target.targetSize.y)
        vuforiaView.renderer.trackedNodes[target] = plane
    }
    
    func arController(_ controller: ARController, didStopTracking target: ARResult)
    {
        vuforiaView.renderer.trackedNodes[target] = nil
    }
}
