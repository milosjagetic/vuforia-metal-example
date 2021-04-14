//
//  CubeModel.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 21/03/2021.
//

import Foundation

final class RenderedCube: RenderedObject<CubeModel>
{
    override func render(encoder: MTLRenderCommandEncoder, pipeline: MTLRenderPipelineState)
    {
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        for current in instanceBuffers
        {
            encoder.setVertexBuffer(current.1, offset: 0, index: 1)
            
            var color = _color
            // Draw translucent cube
            encoder.setFragmentBytes(&color, length: MemoryLayout.size(ofValue: color), index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: CubeModel.indices.count, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
            // Draw wireframe
            color[0] = 1 - color[0]
            color[1] = 1 - color[1]
            color[2] = 1 - color[2]
            
            encoder.setFragmentBytes(&color, length: MemoryLayout.size(ofValue: color), index: 0)
            encoder.drawIndexedPrimitives(type: .line, indexCount: CubeModel.wireframeIndices.count, indexType: .uint16, indexBuffer: wireframeIndices, indexBufferOffset: 0)
        }
    }
}

/*
 Just a hardcoded model of a cube that is rendered using Metal when a target is detected. (as the origin in DebugOptions.showWorldOrigin)
 */
struct CubeModel: RenderedObjectModel
{
    static let vertices: [Float] =
        [-0.50, -0.50,  0.50, // front
         0.50, -0.50,  0.50,
         0.50,  0.50,  0.50,
         -0.50,  0.50,  0.50,
         
         -0.50, -0.50, -0.50, // back
         0.50, -0.50, -0.50,
         0.50,  0.50, -0.50,
         -0.50,  0.50, -0.50,
         
         -0.50, -0.50, -0.50, // left
         -0.50, -0.50,  0.50,
         -0.50,  0.50,  0.50,
         -0.50,  0.50, -0.50,
         
         0.50, -0.50, -0.50, // right
         0.50, -0.50,  0.50,
         0.50,  0.50,  0.50,
         0.50,  0.50, -0.50,
         
         -0.50,  0.50,  0.50, // top
         0.50,  0.50,  0.50,
         0.50,  0.50, -0.50,
         -0.50,  0.50, -0.50,
         
         -0.50, -0.50,  0.50, // bottom
         0.50, -0.50,  0.50,
         0.50, -0.50, -0.50,
         -0.50, -0.50, -0.50]
    
    static let textureCoordinate: [UInt16] =
        [0, 0,
         1, 0,
         1, 1,
         0, 1,
         
         1, 0,
         0, 0,
         0, 1,
         1, 1,
         
         0, 0,
         1, 0,
         1, 1,
         0, 1,
         
         1, 0,
         0, 0,
         0, 1,
         1, 1,
         
         0, 0,
         1, 0,
         1, 1,
         0, 1,
         
         1, 0,
         0, 0,
         0, 1,
         1, 1]
        
    static let indices: [UInt16] =
        [0, 1, 2, 0, 2, 3, // front
         4, 6, 5, 4, 7, 6, // back
         8, 9, 10, 8, 10, 11, // left
         12, 14, 13, 12, 15, 14, // right
         16, 17, 18, 16, 18, 19, // top
         20, 22, 21, 20, 23, 22]  // bottom
    
    static let wireframeIndices: [UInt16] =
        [0, 1, 1, 2, 2, 3, 3, 0, // front
         4, 5, 5, 6, 6, 7, 7, 4, // back
         0, 4, 1, 5, 2, 6, 3, 7] // side
}
