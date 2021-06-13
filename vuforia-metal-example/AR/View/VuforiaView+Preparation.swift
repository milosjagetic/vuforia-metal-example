//
//  VuforiaView+Preparation.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 23/03/2021.
//

import Foundation

// Vuforia startup is a whole song and dance routine. This extension wraps it up.
extension VuforiaView
{
    static weak var preparedVuforiaView: VuforiaView?
    private static var preparationQueue: DispatchQueue = DispatchQueue(label: "vuforia-preparation-queue", qos: .default)
    
    /// Staring vuforia requires a VuforiaView to be in the view hierarchy. So only sensible place in
    ///  VC for doing it would be on viewDidAppear, but that looks butt-ugly because of the screen
    ///   lag. So only other sensible option is to preload the view and then move it where needed.
    static func prepareView(dataSet: ARDataSet, callingVC: UIViewController, completionHandler: ((VuforiaView?, Error?) -> Void)?)
    {
        ARController.shared.initializeVuforia
        { (error) in
            guard error == nil else
            {
                completionHandler?(nil, error)
                return
            }
            
            vuforiaInitialized(dataSet: dataSet, callingVC: callingVC, completionHandler: completionHandler)
        }
    }
    
    private static func vuforiaInitialized(dataSet: ARDataSet, callingVC: UIViewController, completionHandler: ((VuforiaView?, Error?) -> Void)?)
    {
        // Intialize metal renderer, it takes a while so it's done on background thread
        MetalRenderer.defaultRenderer(initQueue: preparationQueue)
        { (renderer, error) in
            guard let renderer = renderer else
            {
                completionHandler?(nil, error ?? VuforiaViewError.prepareError(message: "Unknown"))
                return
            }
            
            // Window where the VuforiaView will be placed during preparation
            guard let window = callingVC.view.window else
            {
                completionHandler?(nil, VuforiaViewError.prepareError(message: "No window to attach to"))
                return
            }
            // Init the view and add it to the window
            let vuforiaView: VuforiaView = VuforiaView(renderer: renderer, frame: UIScreen.main.bounds)
            vuforiaView.translatesAutoresizingMaskIntoConstraints = false;
            vuforiaView.debugOptions = [.showTargetBounds, .showWorldOrigin]
            
            window.insertSubview(vuforiaView, at: 0)
            vuforiaView.pinToSuperview()

            //Vuforia view needs to be in the view hierarchy by now

            //Start AR
            ARController.shared.startAR(with: dataSet)
            { (error) in
                guard error == nil else
                {
                    vuforiaView.removeFromSuperview()
                    completionHandler?(nil, error)
                    return
                }
                
                self.preparedVuforiaView = vuforiaView
                completionHandler?(vuforiaView, error)
            }
        }
    }

    /// Call on viewDidDisappear. Set pause to true if VuforiaView will remain in the view stack, in other words if the user can navigate back to the screen. You are responsible for calling .resumeAR() on viewWillAppear though.
    static func vuforiaViewEnded(pause: Bool)
    {
        if (pause)
        {
            ARController.shared.pauseAR()
        }
        else
        {
            ARController.shared.stopAR()
            preparedVuforiaView?.removeFromSuperview()
            preparedVuforiaView = nil
        }
    }
}
