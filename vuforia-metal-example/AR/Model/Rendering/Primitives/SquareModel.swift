//
//  SquareModel.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 16/03/2021.
//

import Foundation

final class RenderedSquare: RenderedObject<SquareModel>
{
    override func render(encoder: MTLRenderCommandEncoder, pipeline: MTLRenderPipelineState)
    {
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)

        for current in instanceBuffers
        {
            encoder.setVertexBuffer(current.1, offset: 0, index: 1)

            var color = _color
            // Draw translucent square
            color[3] = 0.2
            encoder.setFragmentBytes(&color, length: MemoryLayout.size(ofValue: color), index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: SquareModel.indices.count, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
            // Draw solid wireframe
            color[3] = 1.0
            encoder.setFragmentBytes(&color, length: MemoryLayout.size(ofValue: color), index: 0)
            encoder.drawIndexedPrimitives(type: .line, indexCount: SquareModel.wireframeIndices.count, indexType: .uint16, indexBuffer: wireframeIndices, indexBufferOffset: 0)
        }
    }
}

/*
 Just a hardcoded model of a square that is rendered using Metal when a target is detected.
 */
struct SquareModel: RenderedObjectModel
{
    static let vertices: [Float] =
        [-0.50, -0.50, 0.00,
          0.50, -0.50, 0.00,
          0.50,  0.50, 0.00,
         -0.50,  0.50, 0.00]
    
    static let textureCoordinates: [Float] =
        [1.0, 1.0,
         1.0, 0.0,
         0.0, 0.0,
         0.0, 1.0]
    
    static let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
    static let wireframeIndices : [UInt16] = [0, 1, 1, 2, 2, 3, 3, 0]
}

extension vector_float4
{
    init(color: UIColor)
    {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.init(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
