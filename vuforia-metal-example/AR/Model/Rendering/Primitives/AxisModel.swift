//
//  AxisModel.swift
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 21/03/2021.
//

import Foundation

private extension simd_float4
{
    var asArray: [Float] { [x, y, z, w] }
}

final class RenderedAxes: RenderedObject<AxesModel>
{
    private var axesColors: MTLBuffer!
    
    override init(color: UIColor, instances: [float4x4], device: MTLDevice)
    {
        super.init(color: color, instances: instances, device: device)
        //create an array to be loaded into a color buffer
        //each color is repeated for each of the strokes in the draw process
        var colorArray: [Float] =
            _color.asArray + _color.asArray +
            AxesModel.yAxisColor.asArray + AxesModel.yAxisColor.asArray +
            AxesModel.zAxisColor.asArray + AxesModel.zAxisColor.asArray
        
        axesColors = device.makeBuffer(bytes: &colorArray, length: MemoryLayout<Float>.stride * colorArray.count, options: [])
    }
    
    override func render(encoder: MTLRenderCommandEncoder, pipeline: MTLRenderPipelineState)
    {
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBuffer(axesColors, offset: 0, index: 1)

        for current in instanceBuffers
        {
            encoder.setVertexBuffer(current.1, offset: 0, index: 2)
            encoder.drawIndexedPrimitives(type: .line, indexCount: AxesModel.indices.count, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
        }
    }
}

/*
 Just a hardcoded model of axes (x, y, z) that is rendered using Metal when a target is detected. (as the origin in DebugOptions.showWorldOrigin)
 */
struct AxesModel: RenderedObjectModel
{
    static let vertices: [Float] =
        [ 0.00, 0.00, 0.00, // origin
          1.00, 0.00, 0.00, // x axis
          0.00, 0.00, 0.00, // origin
          0.00, 1.00, 0.00,// y axis
          0.00, 0.00, 0.00, // origin
          0.00, 0.00, 1.00] // z axis
    
    static let indices: [UInt16] = [0, 1, 2, 3, 4, 5]
    
    static let wireframeIndices: [UInt16] = indices
    //x axis is defined in the init of RenderedAxes
    static let yAxisColor: simd_float4 = simd_float4(color: .green)
    static let zAxisColor: simd_float4 = simd_float4(color: .blue)
    
}
