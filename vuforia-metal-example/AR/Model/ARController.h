//
//  ARController.h
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 01/04/2021.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <Metal/MTLRenderCommandEncoder.h>
#import <simd/simd.h>

typedef struct
{
    const int numVertices;
    const float* _Null_unspecified vertices;
    const float* _Null_unspecified textureCoordinates;
    const int numIndices;
    const unsigned short* _Null_unspecified indices;
} VuforiaMesh;

FOUNDATION_EXPORT int const kCameraDeniedErrorCode;
FOUNDATION_EXPORT int const kDeviceNotSupportedErrorCode;


@protocol ARControllerDelegate;
@class ARDataSet, ARResult;

NS_ASSUME_NONNULL_BEGIN

@interface ARController : NSObject
@property (nonatomic, strong, class, readonly) ARController *sharedController;
@property (nonatomic, readonly) BOOL isARActive;
@property (nonatomic, assign) BOOL isRenderingConfigured;

/// All  IMAGE TARGET  results from vufroia state
@property (nonatomic, readonly) NSArray<ARResult *> *results;
/// Make's the ·results· property return only results that are tracked on camera.
/// (status == TRACKED). Default value is true;
@property (nonatomic, assign) BOOL showOnlyOnScreenResults;
@property (nonatomic, weak) id<ARControllerDelegate> delegate;

/// Returns an array of results. See showOnlyOnScreenResults
- (NSArray<ARResult *> *)results;

///Call this first, on app startup
+ (void)setVuforiaLicenseKey:(NSString *)licenseKey;

///Call this second, this is where Vuforia will ask for camera permissions. So either ask before
/// this or be prepared for the alert when you call this.
- (void)initializeVuforiaWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler;

/// Call this last, when you are about to present the AR View. The VuforiaView already needs to be
///  in the view hierarchy by now
- (void)startARWithDataSet:(ARDataSet *)dataSet completionHandler:(void (^)(NSError * _Nullable))completionHandler;

/// Call this to stop everything and deinit AR, you will need to call initializeVuforiaWithCompletionHandler: and startARWithDataSet:completionHandler: again
- (void)stopAR;

/// Resume the temporarly stopped camera and trackers
- (void)resumeAR;

/// Call this to temporarly stop the camera and trackers. Use resumeAR to resume.
- (void)pauseAR;

/// Call at start of every render pass. Populates viewportData with data from Vuforia::RenderingPrimitives.getViewport()
- (BOOL)prepareToRenderWithData:(MTLViewport *)viewportData texture:(id<MTLTexture>)texture encoder:(id<MTLRenderCommandEncoder>)encoder;

/// Calls the Vuforia::Renderer.end() method. Call at the end of every frame render pass.
- (void)finishRenderWithTexture:(id<MTLTexture>)texture encoder:(id<MTLRenderCommandEncoder>)encoder;

/// Does what is says. Call whenever there is a container view size change or orinetation change
- (BOOL)configureRenderingWithWidth:(CGFloat)width height:(CGFloat)height orientation:(UIInterfaceOrientation)orientation;

- (void)focusCamera;
- (void)resetCameraFocusState;
- (VuforiaMesh)getVideoBackgroundMesh;
- (void)getVideoBackgroundProjection:(void *)projection;
- (BOOL)getOriginModelMatrix:(void *)modelColumns;
- (BOOL)getImageTargetResultModelViewMatrix:(void *)modelViewMatrixData;
- (BOOL)getDeviceTargetResultModelViewMatrix:(void *)modelViewMatrixData;
- (BOOL)getARProjectionMatrix:(void *)projectionMatrixData;
- (BOOL)getResult:(ARResult *)result modelViewMatrix:(void *)modelViewMatrixData;
@end

NS_ASSUME_NONNULL_END
