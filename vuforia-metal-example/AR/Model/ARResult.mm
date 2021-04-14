//
//  ARResult.m
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 19/03/2021.
//

#import "ARResult.h"
#include <Vuforia/ImageTargetResult.h>

@class ARTarget;
@implementation ARResult
{
    const  Vuforia::TrackableResult *_result;
    NSString *_targetName;
    simd_float3 _targetSize;
}

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Lifecycle -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
- (instancetype)init
{
    if (self = [super init])
    {
        _result = nullptr;
    }
    
    return self;
}

- (instancetype)initWithVuforiaResult:(const Vuforia::TrackableResult *)result 
{
    if (self = [super init])
    {
#if !TARGET_IPHONE_SIMULATOR
        _result = result;
        
        if (!result->isOfType(Vuforia::ImageTargetResult::getClassType())) _targetSize = simd_make_float3(0);
        
        const Vuforia::ImageTargetResult* itResult = static_cast<const Vuforia::ImageTargetResult*>(_result);
        auto size = itResult->getTrackable().getSize();
        
        _targetSize = simd_make_float3(size.data[0], size.data[1], size.data[2]);
        
        if (!_result->isOfType(Vuforia::ImageTargetResult::getClassType())) _targetName = nil;
        
        const char *nameData =  _result->getTrackable().getName();
        if (nameData == NULL) _targetName = nil;
        _targetName = [NSString.alloc initWithCString:nameData encoding:NSUTF8StringEncoding];
#endif
    }
    
    return self;

}

- (const Vuforia::TrackableResult *)result
{
    return _result;
}

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Overriden -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:ARResult.class])
        return NO;
    
    return [self.targetName isEqualToString:((ARResult *)object).targetName];
}

- (NSUInteger)hash
{
    return  _targetName.hash;
}
@end
