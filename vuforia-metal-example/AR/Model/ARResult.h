//
//  ARResult.h
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 19/03/2021.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

#ifdef __cplusplus
#include <Vuforia/TrackableResult.h>
#endif

@interface ARResult: NSObject
#ifdef __cplusplus
- (instancetype)initWithVuforiaResult:(const Vuforia::TrackableResult *)result;

@property (atomic, assign, unsafe_unretained, readonly) const  Vuforia::TrackableResult *result;
#endif

@property (nonatomic, readonly) simd_float3 targetSize;
@property (nonatomic, assign) simd_float4x4 modelView;
@property (nonatomic, readonly) NSString *targetName;
@end
