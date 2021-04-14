//
//  ARRenderer.swift
//  VuforiaSample
//
//  Created by Milos Jagetic on 11/03/2021.
//

import UIKit
import MetalKit
import SceneKit

private extension Array
{
    func withUnsafeBasePointer(_ handler: (UnsafeRawPointer) -> Void)
    {
        withUnsafeBytes
        {
            guard let base = $0.baseAddress else { return }
            handler(base)
        }
    }
}

/// Class to encapsulate Metal and Scene kit rendering
final class MetalRenderer
{
    enum MetalRendererError: Error
    {
        case initalization(reason: String)
    }
    
    let metalDevice: MTLDevice
    
    let pixelFormat: MTLPixelFormat
    let contentScale: CGFloat
    
    /// Set nodes here if you want them to have the same transform as tracked AR results
    var trackedNodes: [ARResult : SCNNode] = [:]

    private let videoBackgroundPipelineState: MTLRenderPipelineState
    private let coloredShaderPipelineState: MTLRenderPipelineState
    private let uniformColorShaderPipelineState: MTLRenderPipelineState
    private let texturedVertexShaderPipelineState: MTLRenderPipelineState

    private let defaultSamplerState: MTLSamplerState

    private let videoBackgroundVertices: MTLBuffer
    private let videoBackgroundIndices: MTLBuffer
    private let videoBackgroundTextureCoordinates: MTLBuffer

    private let metalCommandQueue:MTLCommandQueue

    private let depthStencilState:MTLDepthStencilState
    private let depthTexture:MTLTexture

    private let videoBackgroundProjectionBuffer:MTLBuffer

    private let sceneRenderer: SCNRenderer
    private var cameraNode: SCNNode
    private var absoluteTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    

    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Static -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    static func defaultRenderer(scale: CGFloat) throws -> MetalRenderer
    {
        return try MetalRenderer(contentScale: UIScreen.main.nativeScale, pixelFormat: .bgra8Unorm)
    }
    
    /// Inits the renderer on the given queue, calls the completion on main
    static func defaultRenderer(initQueue: DispatchQueue, completionHandler: ((MetalRenderer?, Error?) -> Void)?)
    {
        let scale: CGFloat = UIScreen.main.nativeScale
        
        initQueue.async
        {
            let renderer: MetalRenderer
            do { renderer = try defaultRenderer(scale: scale) }
            catch (let error)
            {
                DispatchQueue.main.async { completionHandler?(nil, error) }
                return
            }
            
            DispatchQueue.main.async { completionHandler?(renderer, nil) }
        }
    }
    
    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Lifecycle -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    init(contentScale: CGFloat, pixelFormat: MTLPixelFormat) throws
    {
        self.contentScale = contentScale
        self.pixelFormat = pixelFormat
        
        ///////////////////////////
        // INIT RENDERING STACK
        ///////////////////////////
        
        // Init the device
        guard let metalDevice = MTLCreateSystemDefaultDevice()
            else { throw MetalRendererError.initalization(reason: "Failed to create Metal device") }
        
        self.metalDevice = metalDevice
        
        // Get the default library from the bundle (Metal shaders)
        guard let library = metalDevice.makeDefaultLibrary()
            else { throw MetalRendererError.initalization(reason: "Failed to create Metal library") }
        
        // Create a depth texture that is needed when rendering the augmentation.
        let screenSize = UIScreen.main.bounds.size
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.depth32Float, width: Int(screenSize.width * contentScale), height: Int(screenSize.height * contentScale), mipmapped: false)
        
        depthTextureDescriptor.usage = MTLTextureUsage.renderTarget
        guard let depthTexture = metalDevice.makeTexture(descriptor: depthTextureDescriptor)
            else { throw MetalRendererError.initalization(reason: "Failed to create depth texture") }
        self.depthTexture = depthTexture

        // Video background pipeline
        let videoBGDescriptor: MTLRenderPipelineDescriptor = .defaultPipelineDescriptor(vertexShader: "texturedVertex", fragmentShader: "texturedFragment", library: library, depthTexture: depthTexture, pixelFormat: pixelFormat)
        
        try videoBackgroundPipelineState = metalDevice.makeRenderPipelineState(descriptor: videoBGDescriptor)

        // Uniform color pipeline (for object overlays, origin cube...)
        let uniformColorDescriptor: MTLRenderPipelineDescriptor = .defaultPipelineDescriptor(vertexShader: "uniformColorVertex", fragmentShader: "uniformColorFragment", library: library, depthTexture: depthTexture, pixelFormat: pixelFormat)
        uniformColorDescriptor.colorAttachments[0].isBlendingEnabled = true
        uniformColorDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add
        uniformColorDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add
        uniformColorDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha
        uniformColorDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha
        uniformColorDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        uniformColorDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        
        try uniformColorShaderPipelineState = metalDevice.makeRenderPipelineState(descriptor: uniformColorDescriptor)

        // colored descriptor (axis)
        let coloredDescriptor: MTLRenderPipelineDescriptor = .defaultPipelineDescriptor(vertexShader: "vertexColorVertex", fragmentShader: "vertexColorFragment", library: library, depthTexture: depthTexture, pixelFormat: pixelFormat)

        try coloredShaderPipelineState = metalDevice.makeRenderPipelineState(descriptor: coloredDescriptor)

        // Textured pipeline descriptor (not really used). But you can switch uniformColorPipeleine for this one when rendering target to see some cool portalesque efects
        let texturedDescriptor: MTLRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        texturedDescriptor.vertexFunction = library.makeFunction(name: "texturedVertex")
        texturedDescriptor.fragmentFunction = library.makeFunction(name: "texturedFragment")

        try texturedVertexShaderPipelineState = metalDevice.makeRenderPipelineState(descriptor: texturedDescriptor)

        //Sampler
        guard let sampler = MetalRenderer.defaultSampler(device: metalDevice)
            else { throw MetalRendererError.initalization(reason: "Could not initialize default sampler state") }
        defaultSamplerState = sampler
        
        // Fragment depth stencil
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = metalDevice.makeDepthStencilState(descriptor: depthStencilDescriptor)
            else { throw MetalRendererError.initalization(reason: "Could not make depth stencil state") }
        self.depthStencilState = depthStencilState
        
        // Metal command queue
        guard let queue = metalDevice.makeCommandQueue()
            else { throw MetalRendererError.initalization(reason: "Could not make Command queue") }
        metalCommandQueue = queue

        ///////////////////////////
        // VIDEO BG BUFFERS
        ///////////////////////////
        
        // Allocate space for rendering data for Video background
        guard let videoBackgroundVertices = metalDevice.makeBuffer(length: MemoryLayout<Float>.size * 3 * 4, options: []),
            let videoBackgroundTextureCoordinates = metalDevice.makeBuffer(length: MemoryLayout<Float>.size * 2 * 4, options: []),
            let videoBackgroundIndices = metalDevice.makeBuffer(length: MemoryLayout<UInt16>.size * 6, options: []),
            let videoBackgroundProjectionBuffer = metalDevice.makeBuffer(length: MemoryLayout<Float>.size * 16, options: [])
        else { throw MetalRendererError.initalization(reason: "Could not allocate space for video background rendering") }
        
        self.videoBackgroundVertices = videoBackgroundVertices
        self.videoBackgroundTextureCoordinates = videoBackgroundTextureCoordinates
        self.videoBackgroundIndices = videoBackgroundIndices
        self.videoBackgroundProjectionBuffer = videoBackgroundProjectionBuffer
        
        ///////////////////////////
        // SCENE KIT
        ///////////////////////////
        absoluteTime = CFAbsoluteTimeGetCurrent()
        sceneRenderer = SCNRenderer(device: metalDevice, options: nil)
        sceneRenderer.isPlaying = true

        let camera: SCNCamera = SCNCamera()
        cameraNode = SCNNode()
        cameraNode.camera = camera
    }
    
    
    deinit {
        [videoBackgroundIndices, videoBackgroundVertices, videoBackgroundProjectionBuffer, videoBackgroundTextureCoordinates].forEach({$0.setPurgeableState(.empty)})
    }
    
    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Rendering -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    func renderVuforiaFrame(vuforiaView: VuforiaView, controller: ARController, debugOptions: VuforiaView.DebugOptions)
    {
        // Get the next drawable from the CAMetalLayer
        // It's possible for nextDrawable to return nil, which means a call to
        // renderCommandEncoderWithDescriptor will fail
        guard let layer: CAMetalLayer = vuforiaView.layer as? CAMetalLayer,
            let drawable = layer.nextDrawable() else { return }
        
        // ========== Set up ==========
        var viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(layer.drawableSize.width), height: Double(layer.drawableSize.height), znear: 0.0, zfar: 1.0)

        // -- Render pass descriptor ---
        // Set up a render pass decriptor
        let renderPassDescriptor: MTLRenderPassDescriptor = MTLRenderPassDescriptor()

        // Draw to the drawable's texture
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        // Clear the colour attachment in case there is no video frame
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        // Store the data in the texture when rendering is complete
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        // Use textureDepth for depth operations.
        renderPassDescriptor.depthAttachment.texture = depthTexture;

        // --- Command buffer ---
        // Get the command buffer from the command queue
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        // Get a command encoder to encode into the command buffer
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        if (controller.prepareToRender(withData: &viewport, texture: drawable.texture, encoder: encoder))
        {
            encoder.setViewport(viewport)

            // Once the camera is initialized we can get the video background rendering values
            controller.getVideoBackgroundProjection(videoBackgroundProjectionBuffer.contents())
            // Call the renderer to draw the video background
            renderVideoBackground(encoder: encoder, projectionMatrix: videoBackgroundProjectionBuffer, mesh: controller.getVideoBackgroundMesh())

            encoder.setDepthStencilState(depthStencilState)
            
            var projectionMatrix: matrix_float4x4 = matrix_float4x4()
            
            if (controller.getARProjectionMatrix(&projectionMatrix.columns))
            {
                cameraNode.camera?.projectionTransform = SCNMatrix4(projectionMatrix)

                let results: [ARResult] = controller.results
                
                for (result, node) in trackedNodes
                {
                    guard let modelView = results.first(where: {$0 == result})?.modelView else { continue }
                    node.transform = SCNMatrix4(modelView)
                }
                
                let instances: [float4x4] = results.map
                {
                    let modelView: matrix_float4x4 = $0.modelView

                    var sizeTransformVector: SIMD3 = $0.targetSize
                    sizeTransformVector.z = max(sizeTransformVector.x, sizeTransformVector.y)
                    
                    let unitModelView: matrix_float4x4 = modelView * matrix_float4x4(diagonal: SIMD4(sizeTransformVector, 1)) //unit in respect to target size

                    return  projectionMatrix * unitModelView;
                }


                //render debug stuff
                if debugOptions.contains(.showTargetBounds)
                {
                    renderTargetBounds(instances: instances, encoder: encoder, projection: projectionMatrix)
                }
                
                if debugOptions.contains(.showWorldOrigin)
                {
                    renderWorldOrigin(controller: controller, encoder: encoder, projection: projectionMatrix)
                }
            }
        }

        // Pass Metal context data to Vuforia Engine (we may have changed the encoder since
        // calling Vuforia::Renderer::begin)
        controller.finishRender(with: drawable.texture, encoder: encoder)

        // Pass Metal context data to Vuforia Engine (we may have changed the encoder since
        // calling Vuforia::Renderer::begin)
        controller.finishRender(with: drawable.texture, encoder: encoder)
        // ========== Finish Metal rendering ==========
        encoder.endEncoding()


        //render the scenekit stuff
        let sceneKitPassDescriptor = MTLRenderPassDescriptor()

        //use the previous pass output as bg
        sceneKitPassDescriptor.colorAttachments[0].texture = renderPassDescriptor.colorAttachments[0].texture
        //preserve the last pass
        sceneKitPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        sceneKitPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        sceneKitPassDescriptor.depthAttachment.texture = depthTexture;

        let currentTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent() - absoluteTime
        sceneRenderer.render(atTime: currentTime, viewport: CGRect(x: viewport.originX, y: viewport.originY, width: viewport.width, height: viewport.height), commandBuffer: commandBuffer, passDescriptor: sceneKitPassDescriptor)
        
        // Present the drawable when the command buffer has been executed (Metal
        // calls to CoreAnimation to tell it to put the texture on the display when
        // the rendering is complete)
        commandBuffer.present(drawable)

        // Commit the command buffer for execution as soon as possible
        commandBuffer.commit()
    }
    
    func replaceSceneKitScene(_ scene: SCNScene)
    {
        let camera: SCNCamera = SCNCamera()
        camera.projectionTransform = cameraNode.camera?.projectionTransform ?? SCNMatrix4()
        
        cameraNode = SCNNode()
        cameraNode.camera = camera

        scene.rootNode.addChildNode(cameraNode)
        scene.background.contents = UIColor.clear
        
        sceneRenderer.scene = scene
        sceneRenderer.pointOfView = cameraNode
    }
    
    /// Render the video background
    private func renderVideoBackground(encoder: MTLRenderCommandEncoder, projectionMatrix: MTLBuffer, mesh: VuforiaMesh)
    {
        // Copy mesh data into metal buffers
        videoBackgroundVertices.contents().copyMemory(from: mesh.vertices, byteCount: MemoryLayout<Float>.size * Int(mesh.numVertices) * 3)
        videoBackgroundTextureCoordinates.contents().copyMemory(from: mesh.textureCoordinates, byteCount: MemoryLayout<Float>.size * Int(mesh.numVertices) * 2)
        videoBackgroundIndices.contents().copyMemory(from: mesh.indices, byteCount: MemoryLayout<CShort>.size * Int(mesh.numIndices))
        
        // Set the render pipeline state
        encoder.setRenderPipelineState(videoBackgroundPipelineState)
        
        // Set the texture coordinate buffer
        encoder.setVertexBuffer(videoBackgroundTextureCoordinates, offset: 0, index: 2)
        
        // Set the vertex buffer
        encoder.setVertexBuffer(videoBackgroundVertices, offset: 0, index: 0)
        
        // Set the projection matrix
        encoder.setVertexBuffer(projectionMatrix, offset: 0, index: 1)
       
        encoder.setFragmentSamplerState(defaultSamplerState, index: 0)

        // Draw the geometry
        encoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle,indexCount: 6, indexType: .uint16, indexBuffer: videoBackgroundIndices, indexBufferOffset: 0)
    }
    
    private func renderTargetBounds(instances: [matrix_float4x4], encoder: MTLRenderCommandEncoder, projection: matrix_float4x4)
    {
        RenderedSquare(color: .orange, instances: instances, device: metalDevice).render(encoder: encoder, pipeline: uniformColorShaderPipelineState)
    }
    
    private func renderWorldOrigin(controller: ARController, encoder: MTLRenderCommandEncoder, projection: matrix_float4x4)
    {
        var model: matrix_float4x4 = matrix_float4x4()
        if controller.getOriginModelMatrix(&model.columns)
        {
            let axesScale: Float = 0.25
            let axes: RenderedAxes = RenderedAxes(color: .red, instances: [projection * (model * matrix_float4x4(diagonal: SIMD4(axesScale, axesScale, axesScale, 1)))], device: metalDevice)
            axes.render(encoder: encoder, pipeline: coloredShaderPipelineState)
            
            let originScale: Float = 0.03
            let originCube: RenderedCube = RenderedCube(color: .darkGray, instances: [projection * (model * matrix_float4x4(diagonal: SIMD4(originScale, originScale, originScale, 1)))], device: metalDevice)
            originCube.render(encoder: encoder, pipeline: uniformColorShaderPipelineState)
        }
    }

    //  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
    //  MARK: Helpers -
    //  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
    private static func defaultSampler(device: MTLDevice) -> MTLSamplerState?
    {
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter             = MTLSamplerMinMagFilter.linear
        sampler.magFilter             = MTLSamplerMinMagFilter.linear
        sampler.mipFilter             = MTLSamplerMipFilter.linear
        sampler.maxAnisotropy         = 1
        sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp           = 0
        sampler.lodMaxClamp           = .greatestFiniteMagnitude
        
        return device.makeSamplerState(descriptor: sampler)
    }
}

private extension MTLRenderPipelineDescriptor
{
    final class func defaultPipelineDescriptor(vertexShader: String, fragmentShader: String, library: MTLLibrary, depthTexture: MTLTexture, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineDescriptor
    {
        let stateDescriptor = MTLRenderPipelineDescriptor()
        stateDescriptor.vertexFunction = library.makeFunction(name: vertexShader)
        stateDescriptor.fragmentFunction = library.makeFunction(name: fragmentShader)
        stateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        stateDescriptor.depthAttachmentPixelFormat = depthTexture.pixelFormat
        
        return stateDescriptor;
    }
}
