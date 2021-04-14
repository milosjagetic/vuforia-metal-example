//
//  RenderedObject.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 21/03/2021.
//

import UIKit

class RenderedObject<T: RenderedObjectModel>
{
    //an array of MVP matrices
    let instances: [float4x4]

    var color: UIColor
    {
        didSet
        {
            _color = vector_float4(color: color)
        }
    }
    
    private(set) var _color: vector_float4
    private(set) var instanceBuffers: [(float4x4, MTLBuffer)]!
    
    private(set) var vertices: MTLBuffer!
    private(set) var indices: MTLBuffer!
    private(set) var wireframeIndices: MTLBuffer!
    
    init(color: UIColor, instances: [float4x4], device: MTLDevice)
    {
        self.instances = instances
        self.color = color
        
        _color = vector_float4(color: color)

        vertices = device.makeBuffer(bytes: T.vertices, length: MemoryLayout<Float>.size * T.vertices.count, options: [])
        indices = device.makeBuffer(bytes: T.indices, length: MemoryLayout<UInt16>.size * T.indices.count, options: [])
        wireframeIndices = device.makeBuffer(bytes: T.wireframeIndices, length: MemoryLayout<UInt16>.size * T.wireframeIndices.count, options: [])
        
        instanceBuffers = instances.compactMap(
            {
                var temp = $0
                guard let buffer = device.makeBuffer(bytes: &temp.columns, length: MemoryLayout<Float>.size * 16, options: []) else { return nil }
                
                return ($0, buffer)
            })
    }

    func render(encoder: MTLRenderCommandEncoder, pipeline: MTLRenderPipelineState) {}
    
    deinit {
        [vertices, indices, wireframeIndices].forEach({$0?.setPurgeableState(.empty)})
    }
}

protocol RenderedObjectModel
{
    static var vertices: [Float] {get}
    static var indices: [UInt16] {get}
    static var wireframeIndices: [UInt16] {get}
}
