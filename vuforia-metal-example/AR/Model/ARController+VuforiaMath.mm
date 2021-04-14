//
//  ARController+VuforiaMath.m
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 19/03/2021.
//

#import <Foundation/Foundation.h>
#import "ARController.h"

#include <Vuforia/Tool.h>

/**
 This category doesn't have a public interface in a header file so as not to expose C++ types
 */
@implementation ARController (VuforiaMath)
#if !TARGET_IOS_SIMULATOR
+ (Vuforia::Matrix44F)matrix44FRotate:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m
{
    Vuforia::Matrix44F r;

    r = [self copyMatrix:m];
    [self rotateMatrix:angle axis:axis matrix:r];

    return r;
}

+ (void)rotateMatrix:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m
{
    Vuforia::Matrix44F rotationMatrix;

    // create a rotation matrix
    [self makeRotationMatrix:angle axis:axis matrix:rotationMatrix];

    // m = m * scale_matrix
    [self multiplyMatrix:m withMatrix:rotationMatrix result:m];
}

+ (void)makeRotationMatrix:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m
{
    double radians, c, s, c1, u[3], length;
    int i, j;

    m = [self matrix44FIdentity];

    radians = (angle * M_PI) / 180.0;

    c = cos(radians);
    s = sin(radians);

    c1 = 1.0 - cos(radians);

    length = sqrt(axis.data[0] * axis.data[0] + axis.data[1] * axis.data[1] + axis.data[2] * axis.data[2]);

    u[0] = axis.data[0] / length;
    u[1] = axis.data[1] / length;
    u[2] = axis.data[2] / length;

    for (i = 0; i < 16; i++)
        m.data[i] = 0.0;

    m.data[15] = 1.0;

    for (i = 0; i < 3; i++)
    {
        m.data[i * 4 + (i + 1) % 3] = (float)(u[(i + 2) % 3] * s);
        m.data[i * 4 + (i + 2) % 3] = (float)(-u[(i + 1) % 3] * s);
    }

    for (i = 0; i < 3; i++)
    {
        for (j = 0; j < 3; j++)
            m.data[i * 4 + j] += (float)(c1 * u[i] * u[j] + (i == j ? c : 0.0));
    }
}

+ (Vuforia::Matrix44F)matrix44FIdentity
{
    Vuforia::Matrix44F r;

    for (int i = 0; i < 16; i++)
        r.data[i] = 0.0f;

    r.data[0] = 1.0f;
    r.data[5] = 1.0f;
    r.data[10] = 1.0f;
    r.data[15] = 1.0f;

    return r;
}

+ (Vuforia::Matrix44F)matrix44FScale:(const Vuforia::Vec3F&)scale matrix:(const Vuforia::Matrix44F&)m
{
    Vuforia::Matrix44F r;

    r = [self copyMatrix:m];
    [self scaleMatrix:r scale:scale];

    return r;
}

+ (Vuforia::Matrix44F)copyMatrix:(const Vuforia::Matrix44F&)m
{
    return m;
}

+ (void)scaleMatrix:(Vuforia::Matrix44F &)m scale:(const Vuforia::Vec3F&) scale
{
    //m =  m * scale_m
    m.data[0] *= scale.data[0];
    m.data[1] *= scale.data[0];
    m.data[2] *= scale.data[0];
    m.data[3] *= scale.data[0];

    m.data[4] *= scale.data[1];
    m.data[5] *= scale.data[1];
    m.data[6] *= scale.data[1];
    m.data[7] *= scale.data[1];

    m.data[8] *= scale.data[2];
    m.data[9] *= scale.data[2];
    m.data[10] *= scale.data[2];
    m.data[11] *= scale.data[2];
}

+ (void)multiplyMatrix:(const Vuforia::Matrix44F&)matrixA withMatrix:(Vuforia::Matrix44F&)matrixB result:(Vuforia::Matrix44F&)matrixC
{
    int i, j, k;
    Vuforia::Matrix44F aTmp;

    // matrixC= matrixA * matrixB
    for (i = 0; i < 4; i++)
    {
        for (j = 0; j < 4; j++)
        {
            aTmp.data[j * 4 + i] = 0.0;

            for (k = 0; k < 4; k++)
                aTmp.data[j * 4 + i] += matrixA.data[k * 4 + i] * matrixB.data[j * 4 + k];
        }
    }

    for (i = 0; i < 16; i++)
        matrixC.data[i] = aTmp.data[i];
}

+ (Vuforia::Matrix44F)matrix44FTranspose:(const Vuforia::Matrix44F&)m
{
    Vuforia::Matrix44F r;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            r.data[i * 4 + j] = m.data[i + 4 * j];
    return r;
}

+ (float)matrix44FDeterminate:(const Vuforia::Matrix44F&)m
{
    return  m.data[12] * m.data[9] * m.data[6] * m.data[3] - m.data[8] * m.data[13] * m.data[6] * m.data[3] -
        m.data[12] * m.data[5] * m.data[10] * m.data[3] + m.data[4] * m.data[13] * m.data[10] * m.data[3] +
        m.data[8] * m.data[5] * m.data[14] * m.data[3] - m.data[4] * m.data[9] * m.data[14] * m.data[3] -
        m.data[12] * m.data[9] * m.data[2] * m.data[7] + m.data[8] * m.data[13] * m.data[2] * m.data[7] +
        m.data[12] * m.data[1] * m.data[10] * m.data[7] - m.data[0] * m.data[13] * m.data[10] * m.data[7] -
        m.data[8] * m.data[1] * m.data[14] * m.data[7] + m.data[0] * m.data[9] * m.data[14] * m.data[7] +
        m.data[12] * m.data[5] * m.data[2] * m.data[11] - m.data[4] * m.data[13] * m.data[2] * m.data[11] -
        m.data[12] * m.data[1] * m.data[6] * m.data[11] + m.data[0] * m.data[13] * m.data[6] * m.data[11] +
        m.data[4] * m.data[1] * m.data[14] * m.data[11] - m.data[0] * m.data[5] * m.data[14] * m.data[11] -
        m.data[8] * m.data[5] * m.data[2] * m.data[15] + m.data[4] * m.data[9] * m.data[2] * m.data[15] +
        m.data[8] * m.data[1] * m.data[6] * m.data[15] - m.data[0] * m.data[9] * m.data[6] * m.data[15] -
        m.data[4] * m.data[1] * m.data[10] * m.data[15] + m.data[0] * m.data[5] * m.data[10] * m.data[15];
}

+ (Vuforia::Matrix44F)matrix44FInverse:(const Vuforia::Matrix44F&)m
{
    Vuforia::Matrix44F r;

    float det = 1.0f / [self matrix44FDeterminate:m];

    r.data[0] = m.data[6] * m.data[11] * m.data[13] - m.data[7] * m.data[10] * m.data[13]
        + m.data[7] * m.data[9] * m.data[14] - m.data[5] * m.data[11] * m.data[14]
        - m.data[6] * m.data[9] * m.data[15] + m.data[5] * m.data[10] * m.data[15];

    r.data[4] = m.data[3] * m.data[10] * m.data[13] - m.data[2] * m.data[11] * m.data[13]
        - m.data[3] * m.data[9] * m.data[14] + m.data[1] * m.data[11] * m.data[14]
        + m.data[2] * m.data[9] * m.data[15] - m.data[1] * m.data[10] * m.data[15];

    r.data[8] = m.data[2] * m.data[7] * m.data[13] - m.data[3] * m.data[6] * m.data[13]
        + m.data[3] * m.data[5] * m.data[14] - m.data[1] * m.data[7] * m.data[14]
        - m.data[2] * m.data[5] * m.data[15] + m.data[1] * m.data[6] * m.data[15];

    r.data[12] = m.data[3] * m.data[6] * m.data[9] - m.data[2] * m.data[7] * m.data[9]
        - m.data[3] * m.data[5] * m.data[10] + m.data[1] * m.data[7] * m.data[10]
        + m.data[2] * m.data[5] * m.data[11] - m.data[1] * m.data[6] * m.data[11];

    r.data[1] = m.data[7] * m.data[10] * m.data[12] - m.data[6] * m.data[11] * m.data[12]
        - m.data[7] * m.data[8] * m.data[14] + m.data[4] * m.data[11] * m.data[14]
        + m.data[6] * m.data[8] * m.data[15] - m.data[4] * m.data[10] * m.data[15];

    r.data[5] = m.data[2] * m.data[11] * m.data[12] - m.data[3] * m.data[10] * m.data[12]
        + m.data[3] * m.data[8] * m.data[14] - m.data[0] * m.data[11] * m.data[14]
        - m.data[2] * m.data[8] * m.data[15] + m.data[0] * m.data[10] * m.data[15];

    r.data[9] = m.data[3] * m.data[6] * m.data[12] - m.data[2] * m.data[7] * m.data[12]
        - m.data[3] * m.data[4] * m.data[14] + m.data[0] * m.data[7] * m.data[14]
        + m.data[2] * m.data[4] * m.data[15] - m.data[0] * m.data[6] * m.data[15];

    r.data[13] = m.data[2] * m.data[7] * m.data[8] - m.data[3] * m.data[6] * m.data[8]
        + m.data[3] * m.data[4] * m.data[10] - m.data[0] * m.data[7] * m.data[10]
        - m.data[2] * m.data[4] * m.data[11] + m.data[0] * m.data[6] * m.data[11];

    r.data[2] = m.data[5] * m.data[11] * m.data[12] - m.data[7] * m.data[9] * m.data[12]
        + m.data[7] * m.data[8] * m.data[13] - m.data[4] * m.data[11] * m.data[13]
        - m.data[5] * m.data[8] * m.data[15] + m.data[4] * m.data[9] * m.data[15];

    r.data[6] = m.data[3] * m.data[9] * m.data[12] - m.data[1] * m.data[11] * m.data[12]
        - m.data[3] * m.data[8] * m.data[13] + m.data[0] * m.data[11] * m.data[13]
        + m.data[1] * m.data[8] * m.data[15] - m.data[0] * m.data[9] * m.data[15];

    r.data[10] = m.data[1] * m.data[7] * m.data[12] - m.data[3] * m.data[5] * m.data[12]
        + m.data[3] * m.data[4] * m.data[13] - m.data[0] * m.data[7] * m.data[13]
        - m.data[1] * m.data[4] * m.data[15] + m.data[0] * m.data[5] * m.data[15];

    r.data[14] = m.data[3] * m.data[5] * m.data[8] - m.data[1] * m.data[7] * m.data[8]
        - m.data[3] * m.data[4] * m.data[9] + m.data[0] * m.data[7] * m.data[9]
        + m.data[1] * m.data[4] * m.data[11] - m.data[0] * m.data[5] * m.data[11];

    r.data[3] = m.data[6] * m.data[9] * m.data[12] - m.data[5] * m.data[10] * m.data[12]
        - m.data[6] * m.data[8] * m.data[13] + m.data[4] * m.data[10] * m.data[13]
        + m.data[5] * m.data[8] * m.data[14] - m.data[4] * m.data[9] * m.data[14];

    r.data[7] = m.data[1] * m.data[10] * m.data[12] - m.data[2] * m.data[9] * m.data[12]
        + m.data[2] * m.data[8] * m.data[13] - m.data[0] * m.data[10] * m.data[13]
        - m.data[1] * m.data[8] * m.data[14] + m.data[0] * m.data[9] * m.data[14];

    r.data[11] = m.data[2] * m.data[5] * m.data[12] - m.data[1] * m.data[6] * m.data[12]
        - m.data[2] * m.data[4] * m.data[13] + m.data[0] * m.data[6] * m.data[13]
        + m.data[1] * m.data[4] * m.data[14] - m.data[0] * m.data[5] * m.data[14];

    r.data[15] = m.data[1] * m.data[6] * m.data[8] - m.data[2] * m.data[5] * m.data[8]
        + m.data[2] * m.data[4] * m.data[9] - m.data[0] * m.data[6] * m.data[9]
        - m.data[1] * m.data[4] * m.data[10] + m.data[0] * m.data[5] * m.data[10];

    for (int i = 0; i < 16; i++)
        r.data[i] *= det;

    return r;
}
#endif
@end

