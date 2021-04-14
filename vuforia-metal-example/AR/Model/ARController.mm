//
//  ARController.m
//  vuforia-metal-example
//
//  Created by Milos Jagetic on 01/04/2021.
//


#import "ARController.h"
#import <QuartzCore/QuartzCore.h>
#import <Metal/MTLTexture.h>
#import <Metal/Metal.h>
#import <Metal/MTLRenderCommandEncoder.h>
#import <Metal/MTLDevice.h>
#import "BridgingHeader.h"
#import "vuforia_metal_example-Swift.h"
#import "ARResult.h"

#if !TARGET_IPHONE_SIMULATOR
#include <Vuforia/CameraDevice.h>
#include <Vuforia/DataSet.h>
#include <Vuforia/Device.h>
#include <Vuforia/DeviceTrackableResult.h>
#include <Vuforia/ImageTarget.h>
#include <Vuforia/ImageTargetResult.h>
#include <Vuforia/ObjectTracker.h>
#include <Vuforia/PositionalDeviceTracker.h>
#include <Vuforia/Renderer.h>
#include <Vuforia/RenderingPrimitives.h>
#include <Vuforia/State.h>
#include <Vuforia/StateUpdater.h>
#include <Vuforia/Tool.h>
#include <Vuforia/TrackerManager.h>
#include <Vuforia/Vuforia.h>
#include <Vuforia/UpdateCallback.h>
#include <Vuforia/VideoBackgroundConfig.h>

#include <Vuforia/iOS/MetalRenderer.h>
#include <Vuforia/iOS/Vuforia_iOS.h>
#endif

#include <string>

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Constants -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
int const kCameraDeniedErrorCode = Vuforia::INIT_NO_CAMERA_ACCESS;
int const kDeviceNotSupportedErrorCode = Vuforia::INIT_DEVICE_NOT_SUPPORTED;

static const float kNearPlane = 0.01;
static const float kFarPlane = 5.;

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: C++ class that holds the onUpdate handler -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
#if !TARGET_IPHONE_SIMULATOR
namespace
{
    class VuforiaCallbackWrapper : public Vuforia::UpdateCallback
    {
    public:
        virtual void Vuforia_onUpdate(Vuforia::State& state);
    } _callbackWrapper;
}
#endif

//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Math helper interface -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
/**
 Interface of this category is not public and in a header file so as not to expose C++ types
 */
#if !TARGET_IPHONE_SIMULATOR
@interface ARController (VuforiaMath)
+ (Vuforia::Matrix44F)matrix44FRotate:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m;
+ (void)rotateMatrix:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m;
+ (void)makeRotationMatrix:(float)angle axis:(const Vuforia::Vec3F&)axis matrix:(Vuforia::Matrix44F&)m;
+ (Vuforia::Matrix44F)matrix44FIdentity;
+ (Vuforia::Matrix44F)matrix44FScale:(const Vuforia::Vec3F&)scale matrix:(const Vuforia::Matrix44F&)m;
+ (Vuforia::Matrix44F)copyMatrix:(const Vuforia::Matrix44F&)m;
+ (void)scaleMatrix:(Vuforia::Matrix44F &)m scale:(const Vuforia::Vec3F&) scale;
+ (void)multiplyMatrix:(const Vuforia::Matrix44F&)matrixA withMatrix:(Vuforia::Matrix44F&)matrixB result:(Vuforia::Matrix44F&)matrixC;
+ (Vuforia::Matrix44F)matrix44FTranspose:(const Vuforia::Matrix44F&)m;
+ (float)matrix44FDeterminate:(const Vuforia::Matrix44F&)m;
+ (Vuforia::Matrix44F)matrix44FInverse:(const Vuforia::Matrix44F&)m;
@end
#endif


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Static vars -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
static ARController *_sharedController = nil;


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: ARController implementation -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
@interface ARController ()
@property (nonatomic, assign) CGFloat aspectRatio;
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, assign) BOOL isARActive;
@property (nonatomic, assign) BOOL isCameraActive;

@property (nonatomic, assign) BOOL isVuforiaPaused;
@property (nonatomic, assign) BOOL isVuforiaInited;

@property (nonatomic, strong) dispatch_queue_t initializationQueue;
@property (nonatomic, strong) ARDataSet *arDataSet;
@property (nonatomic, strong) NSArray<ARResult *> *lastResults;
@end

@implementation ARController
{
#if !TARGET_IPHONE_SIMULATOR
    /// The Vuforia camera mode to use, either DEFAULT, SPEED or QUALITY.
    Vuforia::CameraDevice::MODE _cameraMode;
    /// Local copy of current RenderingPrimitives
    std::unique_ptr<Vuforia::RenderingPrimitives> _currentRenderingPrimitives;
    /// After the first call to prepareToRender this holds a copy of the Vuforia state.
    Vuforia::State _vuforiaState;
    
    Vuforia::MetalRenderData _renderData;
    Vuforia::MetalTextureUnit _textureUnit;
    
    /// The currently activated Vuforia DataSet.
    Vuforia::DataSet*  _currentDataSet;
#endif
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Class -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
+ (ARController *)sharedController
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        _sharedController = [ARController new];
    });
    
    return _sharedController;
}

+ (void)setVuforiaLicenseKey:(NSString *)licenseKey
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::setInitParameters(Vuforia::INIT_FLAGS::METAL, licenseKey.UTF8String);
#endif
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Instance -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Lifecycle -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
- (instancetype)init
{
    if (self = [super init])
    {
        self.aspectRatio = 1;
        self.interfaceOrientation = UIInterfaceOrientationPortrait;
        self.initializationQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
   
#if !TARGET_IPHONE_SIMULATOR
        _currentDataSet = nullptr;
        _showOnlyOnScreenResults = YES;
        _cameraMode = Vuforia::CameraDevice::MODE_OPTIMIZE_SPEED;
#endif
    }
    
    return self;
}

- (void)initializeVuforiaWithCompletionHandler:(void (^)(NSError *))completionHandler
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::setAllowedFusionProviders(Vuforia::FUSION_PROVIDER_TYPE::FUSION_PROVIDER_PLATFORM_SENSOR_FUSION);

    if (_isVuforiaInited && completionHandler)
    {
        completionHandler(nil);
        return;
    }
    
    __weak typeof(self) weakself = self;
    [self internalInitializeVuforiaWithCompletionHandler:
     ^(int progress)
    {
        if (progress != 100)
        {
            // Failed to initialise Vuforia Engine:
            std::string cameraAccessErrorMessage = "";

            switch(progress)
            {
                case Vuforia::INIT_NO_CAMERA_ACCESS:
                    // On most platforms the user must explicitly grant camera access
                    // If the access request is denied this code is returned
                    cameraAccessErrorMessage = "Vuforia cannot initialize because access to the camera was denied.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_TRANSIENT:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license check encountered a temporary network error.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_NO_NETWORK_PERMANENT:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license check encountered a permanent network error.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_INVALID_KEY:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license key is invalid.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_CANCELED_KEY:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license key was cancelled.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_MISSING_KEY:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license key was missing.";
                    break;

                case Vuforia::INIT_LICENSE_ERROR_PRODUCT_TYPE_MISMATCH:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the license key is for the wrong product type.";
                    break;

                case Vuforia::INIT_DEVICE_NOT_SUPPORTED:
                    cameraAccessErrorMessage = "Vuforia failed to initialize because the device is not supported.";
                    break;

                default:
                    cameraAccessErrorMessage = "Vuforia initialization failed.";
                    break;
            }

            NSError *error = [NSError errorWithDomain:[NSString.alloc initWithCString:cameraAccessErrorMessage.c_str() encoding:NSUTF8StringEncoding] code:progress userInfo:nil];
            weakself.isVuforiaInited = NO;
            
            if (completionHandler)
                completionHandler(error);
            
            return;
        }

        weakself.isVuforiaInited = YES;
        
        
        Vuforia::registerCallback(&_callbackWrapper);

        [NSNotificationCenter.defaultCenter addObserver:weakself selector:@selector(pauseVuforia) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:weakself selector:@selector(resumeVuforia) name:UIApplicationDidBecomeActiveNotification object:nil];

        if (completionHandler)
            completionHandler(nil);
    }];
#else
    if (completionHandler)
        completionHandler([NSError errorWithDomain:@"Cannot initialize on simulator" code:100819 userInfo:nil]);
#endif
}

#if !TARGET_IPHONE_SIMULATOR
- (void)internalInitializeVuforiaWithCompletionHandler:(void (^)(int result))completionHandler
{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        _initializationQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    });
    
    __weak typeof(self) weakself = self;
    dispatch_async(_initializationQueue,
    ^{
        // Vuforia::init() will return positive numbers up to 100 as it progresses
        // towards success.  Negative numbers indicate error conditions
        int progress = progress = Vuforia::init();
        
        // Documentation sugggests putting it (::init) in a while loop on a background thread with the same conditions
        // as the if condition below. This results in high cpu usage regardless of it being a bg
        //thread. So this is a more sane solution, altho uglier
        if (progress >= 0 && progress < 100)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), weakself.initializationQueue,
            ^{
                [self internalInitializeVuforiaWithCompletionHandler:completionHandler];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(),
            ^{
                if (completionHandler)
                    completionHandler(progress);
            });
        }
    });
}
#endif

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Public -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
- (void)startARWithDataSet:(ARDataSet *)dataSet completionHandler:(void (^)(NSError * _Nullable))completionHandler;

{
#if !TARGET_IPHONE_SIMULATOR
    if (self.isARActive)
    {
        NSLog(@"Application logic error, attempt to startAR when already started");
        if (completionHandler) completionHandler(nil);
    }
    
    [self initalizeTrackers];

    // initialize the camera
    if (! Vuforia::CameraDevice::getInstance().init())
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:@"Failed to initialize the camera"
                                                  code:57427
                                              userInfo:nil]);
        return;
    }
    
    // select the default video mode
    if(! Vuforia::CameraDevice::getInstance().selectVideoMode(_cameraMode))
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:@"Failed to set the camera mode"
                                                  code:57427
                                              userInfo:nil]);
        return;
    }


    // set the FPS to its recommended value
    int recommendedFps = Vuforia::Renderer::getInstance().getRecommendedFps();
    Vuforia::Renderer::getInstance().setTargetFps(recommendedFps);

    if (![self startTrackers])
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:@"Failed to start trackers"
                                                  code:57427
                                              userInfo:nil]);
        return;
    }

    if (!Vuforia::CameraDevice::getInstance().start())
    {
        if (completionHandler)
            completionHandler([NSError errorWithDomain:@"Failed to start the camera"
                                                  code:57427
                                              userInfo:nil]);
        return;
    }

    // Set camera to autofocus
    if (!Vuforia::CameraDevice::getInstance()
        .setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO))
    {
        NSLog(@"Failed to set camera to continuous autofocus, camera may not support this");
    }
    
    __weak typeof(self) weakself = self;
    dispatch_async(self.initializationQueue,
    ^{
        [weakself _loadDataSet:dataSet completionHandler:
         ^(NSError *error)
         {
            if (error)
            {
                weakself.isARActive  = NO;
                
                if (completionHandler) completionHandler(error);
                return;
            }
            weakself.isARActive = YES;
            if (completionHandler) completionHandler(nil);
        }];
    });

#else
    if (completionHandler)
        completionHandler([NSError errorWithDomain:@"Cannot start AR on simulator" code:100819 userInfo:nil]);
#endif
}

- (void)stopAR
{
#if !TARGET_IPHONE_SIMULATOR
    if (self.isCameraActive)
    {
        Vuforia::CameraDevice::getInstance().stop();
        Vuforia::CameraDevice::getInstance().deinit();
        self.isCameraActive = NO;
    }
    
    
    [self stopTrackers];
    
    Vuforia::onPause();

    if(![self unloadTrackerData])
    {
        NSLog(@"Error unloading tracker data.");
    }
    
    [self deinitTrackers];
    
    Vuforia::deinit();
    self.isVuforiaInited = NO;
    self.isARActive = NO;

#endif
}

- (void)resumeAR
{
#if !TARGET_IPHONE_SIMULATOR
    NSString *cameraErrorMessage;
    bool successfullyResumed = YES;
    // if the camera was previously started, but not currently active, then
    // we restart it

    if (self.isARActive && (!self.isCameraActive))
    {
        // initialize the camera
        if ( !Vuforia::CameraDevice::getInstance().init() )
        {
            cameraErrorMessage = @"Failed to initialize the camera.";
            successfullyResumed = NO;
        }
        
        if( !Vuforia::CameraDevice::getInstance().selectVideoMode(_cameraMode) )
        {
            cameraErrorMessage = @"Failed to select camera video mode.";
            successfullyResumed = NO;
        }

        // need to start trackers after camera... why? dont know. otherwise resumeAR only works after second time
        [self startTrackers];

        if ( !Vuforia::CameraDevice::getInstance().start() )
        {
            cameraErrorMessage = @"Failed to start the camera.";
            successfullyResumed = NO;
        }
        self.isCameraActive = successfullyResumed;
    }
    
    if(!successfullyResumed)
    {
        NSLog(@"Error resuming AR: %@", cameraErrorMessage);
    }

    if (self.isARActive)
    {
        [self updateRenderingPrimitives];
    }
    
    [self resumeVuforia];
#endif
}

- (void)pauseAR
{
#if !TARGET_IPHONE_SIMULATOR
    BOOL successfullyPaused = YES;
    NSString *cameraErrorMessage;
    
    if (self.isCameraActive)
    {
        // Stop and deinit the camera
        if(! Vuforia::CameraDevice::getInstance().stop())
        {
            cameraErrorMessage = @"Error stopping the camera";
            successfullyPaused = NO;
        }
        if(! Vuforia::CameraDevice::getInstance().deinit())
        {
            cameraErrorMessage = @"Error de-initializing the camera";
            successfullyPaused = NO;
        }
        self.isCameraActive = NO;
    }

    [self stopTrackers];

    [self pauseVuforia];
    
    if(!successfullyPaused)
    {
        NSLog(@"Error pausing AR: %@", cameraErrorMessage);
    }
#endif
}

- (BOOL)prepareToRenderWithData:(MTLViewport *)viewportData texture:(id<MTLTexture>)texture encoder:(id<MTLRenderCommandEncoder>)encoder
{
#if !TARGET_IPHONE_SIMULATOR
    _renderData.mData.drawableTexture = texture;
    _renderData.mData.commandEncoder = encoder;
    
    return [self prepareToRenderWithViewportData:viewportData renderData:&_renderData backgroundTextureUnit:&_textureUnit backgroundTexture:nullptr];
#else
    return NO;
#endif
}

- (void)finishRenderWithTexture:(id<MTLTexture>)texture encoder:(id<MTLRenderCommandEncoder>)encoder
{
#if !TARGET_IPHONE_SIMULATOR
    _renderData.mData.drawableTexture = texture;
    _renderData.mData.commandEncoder = encoder;

    Vuforia::Renderer::getInstance().end(&_renderData);
#endif
}

- (void)focusCamera
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
#endif
}


- (void)resetCameraFocusState
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
#endif
}

- (VuforiaMesh)getVideoBackgroundMesh
{
#if !TARGET_IPHONE_SIMULATOR
    auto rp = _currentRenderingPrimitives.get();
    if (rp == nullptr) return {};
    
    const Vuforia::Mesh& vbMesh = rp->getVideoBackgroundMesh(Vuforia::VIEW_SINGULAR);
    
    VuforiaMesh result =
    {
        vbMesh.getNumVertices(),
        vbMesh.getPositionCoordinates(),
        vbMesh.getUVCoordinates(),
        vbMesh.getNumTriangles() * 3,
        vbMesh.getTriangles(),
    };
    
    return result;
#else
    return {};
#endif
}

- (void)getVideoBackgroundProjection:(void *)projection
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::RenderingPrimitives *rp = _currentRenderingPrimitives.get();
    if (rp == nullptr) return;
    
    Vuforia::Matrix34F vbProjection = rp->getVideoBackgroundProjectionMatrix(Vuforia::VIEW_SINGULAR);
    Vuforia::Matrix44F nja = Vuforia::Tool::convert2GLMatrix(vbProjection);
    nja.data[15] = 1;

    memcpy(projection, nja.data, sizeof(nja.data));
#endif
}

-(BOOL)getOriginModelMatrix:(void *)modelColumns
{
#if !TARGET_IPHONE_SIMULATOR
    auto origin = _vuforiaState.getDeviceTrackableResult();
    if (origin != nullptr)
    {
        if (origin->getStatus() == Vuforia::TrackableResult::STATUS::TRACKED &&
            origin->getStatusInfo() == Vuforia::TrackableResult::STATUS_INFO::NORMAL)
        {
            Vuforia::Matrix44F viewMatrix = Vuforia::Tool::convertPose2GLMatrix(origin->getPose());

            Vuforia::Matrix44F viewMat44 = [ARController matrix44FTranspose:[ARController matrix44FInverse:viewMatrix]];
            memcpy(modelColumns, &viewMat44.data, sizeof(viewMat44.data));

            return YES;
        }
    }
#endif
    return NO;
}

- (BOOL)getImageTargetResultModelViewMatrix:(void *)modelViewMatrixData
{
#if !TARGET_IPHONE_SIMULATOR
    const auto& trackableResultList = _vuforiaState.getTrackableResults();
    for (const auto* result : trackableResultList)
    {
        if (result->isOfType(Vuforia::ImageTargetResult::getClassType()))
        {
            return [self getResult:[ARResult.alloc initWithVuforiaResult:result] modelViewMatrix:modelViewMatrixData];
        }
    }
#endif
    return NO;
}

- (BOOL)getDeviceTargetResultModelViewMatrix:(void *)modelViewMatrixData
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::Matrix44F viewMatrix = [ARController matrix44FIdentity];
    
    if (_vuforiaState.getDeviceTrackableResult() != nullptr && _vuforiaState.getDeviceTrackableResult()->getStatus() != Vuforia::TrackableResult::NO_POSE)
    {
        Vuforia::Matrix34F tempViewMatrix = _vuforiaState.getDeviceTrackableResult()->getPose();
        viewMatrix = Vuforia::Tool::convertPose2GLMatrix(tempViewMatrix);
        viewMatrix = [ARController matrix44FTranspose:[ARController matrix44FInverse:viewMatrix]];
        
        memcpy(modelViewMatrixData, &viewMatrix.data, sizeof(viewMatrix.data));

        return YES;
    }
#endif
    return NO;
}

- (BOOL)getARProjectionMatrix:(void *)projectionMatrixData
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::Matrix34F vuforiaStyleProjMatrix= _currentRenderingPrimitives->getProjectionMatrix(Vuforia::VIEW_SINGULAR, _vuforiaState.getCameraCalibration());
    Vuforia::Matrix44F projectionMatrix = Vuforia::Tool::convertPerspectiveProjection2GLMatrix(vuforiaStyleProjMatrix, kNearPlane, kFarPlane);
    memcpy(projectionMatrixData, &projectionMatrix.data, sizeof(projectionMatrix.data));
    return YES;
#endif
    return NO;
}

- (BOOL)getResult:(ARResult *)result modelViewMatrix:(void *)modelViewMatrixData
{
#if !TARGET_IPHONE_SIMULATOR
    Vuforia::Matrix44F modelViewMatrix;
    
    if (result.result->isOfType(Vuforia::ImageTargetResult::getClassType()))
    {
        Vuforia::Matrix44F viewMatrix = [ARController matrix44FIdentity];
        
        //Get the view matrix. If there is no device tracking the view matrix is an identity matrix
        if (_vuforiaState.getDeviceTrackableResult() != nullptr && _vuforiaState.getDeviceTrackableResult()->getStatus() != Vuforia::TrackableResult::NO_POSE)
        {
            Vuforia::Matrix34F tempViewMatrix = _vuforiaState.getDeviceTrackableResult()->getPose();
            viewMatrix = Vuforia::Tool::convertPose2GLMatrix(tempViewMatrix);
            viewMatrix = [ARController matrix44FTranspose:[ARController matrix44FInverse:viewMatrix]];
        }

        // Get object pose and generate modelViewMatrix
        modelViewMatrix = Vuforia::Tool::convertPose2GLMatrix(result.result->getPose());
        [ARController multiplyMatrix:viewMatrix withMatrix:modelViewMatrix result:modelViewMatrix];

        memcpy(modelViewMatrixData, &modelViewMatrix.data, sizeof(modelViewMatrix.data));

        return YES;
    }
#endif
    return NO;
}

- (NSArray<ARResult *> *)results
{
    NSMutableArray *results = [NSMutableArray.alloc init];
#if !TARGET_IPHONE_SIMULATOR
    for(int i = 0; i < _vuforiaState.getTrackableResults().size(); i++)
    {
        if (!(_vuforiaState.getTrackableResults().at(i)->isOfType(Vuforia::ImageTargetResult::getClassType())))
            continue;
        
        if (_vuforiaState.getTrackableResults().at(i)->getStatus() != Vuforia::TrackableResult::STATUS::TRACKED &&
            self.showOnlyOnScreenResults)
            continue;

        matrix_float4x4 modelView;
        ARResult *result = [ARResult.alloc initWithVuforiaResult:_vuforiaState.getTrackableResults().at(i)];
        [self getResult:result modelViewMatrix:&modelView.columns[0]];
        result.modelView = modelView;

        [results addObject: result];
    }
#endif
    return  results.copy;
}

- (BOOL)configureRenderingWithWidth:(CGFloat)width height:(CGFloat)height orientation:(UIInterfaceOrientation)orientation
{
#if !TARGET_IPHONE_SIMULATOR
    if (!self.isARActive)
        return NO;
    
    _interfaceOrientation = orientation;
    _aspectRatio = width / height;
    
    if (!self.isRenderingConfigured)
    {
        self.isRenderingConfigured = true;
        Vuforia::onSurfaceCreated();
    }

    int smallerSize = MIN(width, height);
    int largerSize = MAX(width, height);
    
    // Frames from the camera are always landscape, no matter what the
    // orientation of the device.  Tell Vuforia to rotate the video background (and
    // the projection matrix it provides to us for rendering our augmentation)
    // by the proper angle in order to match the EAGLView orientation
    switch (orientation)
    {
        case UIInterfaceOrientationPortrait:
            Vuforia::setRotation(Vuforia::ROTATE_IOS_90);
            Vuforia::onSurfaceChanged(smallerSize, largerSize);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            Vuforia::setRotation(Vuforia::ROTATE_IOS_270);
            Vuforia::onSurfaceChanged(smallerSize, largerSize);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            Vuforia::setRotation(Vuforia::ROTATE_IOS_180);
            Vuforia::onSurfaceChanged(largerSize, smallerSize);
        default:
            Vuforia::setRotation(Vuforia::ROTATE_IOS_0);
            Vuforia::onSurfaceChanged(largerSize, smallerSize);
            break;
    }
    
    [self configureVideoBackgroundWithViewWidth:width viewHeight:height];

    return YES;
#else
    return NO;
#endif
}


//  //= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\
//  MARK: Private -
//  \\= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =//
#if !TARGET_IPHONE_SIMULATOR
- (BOOL)unloadTrackerData
{
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    if (objectTracker == nullptr)
    {
        return NO;
    }
    
    if (!objectTracker->deactivateDataSet(_currentDataSet))
    {
        NSLog(@"Warning: Failed to deactivate the data set.");
    }
    
    if (!objectTracker->destroyDataSet(_currentDataSet))
    {
        NSLog(@"Warning: Failed to destory the data set.");
    }
    
    _currentDataSet = nullptr;

    return YES;
}

- (void)_loadDataSet:(ARDataSet *)dataSet completionHandler:(void (^)(NSError * _Nullable))completionHandler;
{
    if (_currentDataSet != nullptr)
    {
       if (![self unloadTrackerData])
       {
           dispatch_async(dispatch_get_main_queue(),
            ^{
               NSLog(@"Error loading tracker data. Data set already loaded");
               if (completionHandler)
                   completionHandler([NSError errorWithDomain:@"Failed unloading existing data" code:185419 userInfo:nil]);
           });
           return;
        }
    }
    
    _currentDataSet = [self loadAndActivateDataSet:dataSet.fileName];
    _arDataSet = dataSet;
    BOOL success = _currentDataSet != nullptr;
    dispatch_async(dispatch_get_main_queue(),
     ^{
        if (completionHandler)
            completionHandler(success ? nil : [NSError errorWithDomain:@"Failed loading data" code:185519 userInfo:nil]);
    });
}

- (Vuforia::DataSet *)loadAndActivateDataSet:(NSString *)path
{
    NSLog(@"Loading data set from %@", path);
    Vuforia::DataSet * dataSet = nullptr;
    
    // Get the Vuforia tracker manager image tracker
    Vuforia::TrackerManager &trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker *objectTracker = static_cast<Vuforia::ObjectTracker *>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == nullptr)
    {
        NSLog(@"Error: Failed to get the ObjectTracker from the TrackerManager");
    }
    else
    {
        dataSet = objectTracker->createDataSet();
        if (dataSet == nullptr)
        {
            NSLog(@"Error: Failed to create data set");
        }
        else
        {
            // Load the data set from the app's resources
            if (!dataSet->load(path.UTF8String, Vuforia::STORAGE_APPRESOURCE))
            {
                NSLog(@"Error: Failed to load data set");
                objectTracker->destroyDataSet(dataSet);
                dataSet = nullptr;
            }
            else
            {
                if (!objectTracker->activateDataSet(dataSet))
                {
                    NSLog(@"Error: Failed to activate data set");
                    objectTracker->destroyDataSet(dataSet);
                    dataSet = nullptr;
                }
            }
        }
    }
    
    return dataSet;
}

- (BOOL)startTrackers
{
    NSLog(@"Starting trackers");
    
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* deviceTracker = trackerManager.getTracker(Vuforia::PositionalDeviceTracker::getClassType());
    BOOL result;
    if(deviceTracker != 0)
    {
        NSLog(@"Starting device tracker");
        result = deviceTracker->start();
        NSLog(@"Starting device tracker result: %i", result);
    }
    
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    if(tracker == 0)
    {
        return NO;
    }
    NSLog(@"Starting object tracker");
    result = tracker->start();
    NSLog(@"Starting object tracker result: %i", result);
    return YES;
}

- (void)stopTrackers
{
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    
    Vuforia::Tracker* objectTracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    
    if (objectTracker != nullptr)
    {
        objectTracker->stop();
        NSLog(@"Successfully stopped the ObjectTracker");
    }
    else
    {
        NSLog(@"Error: Failed to get the ObjectTracker from the tracker manager");
    }
    
    Vuforia::Tracker* deviceTracker = trackerManager.getTracker(Vuforia::PositionalDeviceTracker::getClassType());

    if (deviceTracker != nullptr)
    {
        deviceTracker->stop();
        NSLog(@"Successfully stopped the PositionalDeviceTracker");
    }
    else
    {
        NSLog(@"Error: Failed to get the PositionalDeviceTracker from the tracker manager");
    }
}

- (NSError *)initalizeTrackers
{
    Vuforia::TrackerManager &trackerManager = Vuforia::TrackerManager::getInstance();
    
    //Initialize device tracker
    Vuforia::Tracker *tracker = trackerManager.initTracker(Vuforia::PositionalDeviceTracker::getClassType());
    if (tracker == nullptr)
    {
        NSLog(@"Error: Failed to initialise the Device tracker (it may have been initialised already)");
        return [NSError errorWithDomain:@"Error initializing the device tracker"
                                   code:724832
                               userInfo:nil];
    }
    
    // Initialize the object tracker
    Vuforia::Tracker *trackerBase = trackerManager.initTracker(Vuforia::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Error: Failed to initialize ObjectTracker.");
        return [NSError errorWithDomain:@"Error initializing the object tracker" code:724832 userInfo:nil];
    }
    
    return nil;
}

- (void)deinitTrackers
{
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    NSLog(@"%i %i", trackerManager.deinitTracker(Vuforia::ObjectTracker::getClassType()),
          trackerManager.deinitTracker(Vuforia::PositionalDeviceTracker::getClassType()));
}

- (void)updateRenderingPrimitives
{
    _currentRenderingPrimitives.reset(new Vuforia::RenderingPrimitives(Vuforia::Device::getInstance().getRenderingPrimitives()));
}

- (void)configureVideoBackgroundWithViewWidth:(CGFloat)viewWidth viewHeight:(CGFloat)viewHeight
{
    // Get the default video mode
    Vuforia::CameraDevice& cameraDevice = Vuforia::CameraDevice::getInstance();
    Vuforia::VideoMode videoMode = cameraDevice.getCurrentVideoMode();
    
    // Configure the video background
    Vuforia::VideoBackgroundConfig config;
    config.mPosition.data[0] = 0;
    config.mPosition.data[1] = 0;
    
    NSLog(@"video mode w: %i, h: %i", videoMode.mWidth, videoMode.mHeight);

    // Determine the orientation of the view.  Note, this simple test assumes
    // that a view is portrait if its height is greater than its width.  This is
    // not always true: it is perfectly reasonable for a view with portrait
    // orientation to be wider than it is high.  The test is suitable for the
    // dimensions used in this sample
    if (UIInterfaceOrientationIsPortrait(_interfaceOrientation))
    {
        // --- View is portrait ---
        
        // Compare aspect ratios of video and screen.  If they are different we
        // use the full screen size while maintaining the video's aspect ratio,
        // which naturally entails some cropping of the video
        float aspectRatioVideo = (float)videoMode.mWidth / (float)videoMode.mHeight;
        float aspectRatioView = viewHeight / viewWidth;
        
        if (aspectRatioVideo < aspectRatioView)
        {
            // Video (when rotated) is wider than the view: crop left and right
            // (top and bottom of video)
            
            // --============--
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // - =          = _
            // --============--
            
            config.mSize.data[0] = int(videoMode.mHeight * (viewHeight / float(videoMode.mWidth)));
            config.mSize.data[1] = int(viewHeight);
        }
        else
        {
            // Video (when rotated) is narrower than the view: crop top and
            // bottom (left and right of video).  Also used when aspect ratios
            // match (no cropping)
            
            // ------------
            // -          -
            // -          -
            // ============
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // =          =
            // ============
            // -          -
            // -          -
            // ------------
            
            config.mSize.data[0] = int(viewWidth);
            config.mSize.data[1] = int(videoMode.mWidth * (viewWidth / float(videoMode.mHeight)));
        }
        
    }
    else
    {
        // --- View is landscape ---
        
        // Compare aspect ratios of video and screen.  If they are different we
        // use the full screen size while maintaining the video's aspect ratio,
        // which naturally entails some cropping of the video
        float aspectRatioVideo = (float)videoMode.mWidth / (float)videoMode.mHeight;
        float aspectRatioView = viewWidth / viewHeight;
        
        if (aspectRatioVideo < aspectRatioView)
        {
            // Video is taller than the view: crop top and bottom
            
            // --------------------
            // ====================
            // =                  =
            // =                  =
            // =                  =
            // =                  =
            // ====================
            // --------------------
            
            config.mSize.data[0] = int(viewWidth);
            config.mSize.data[1] = int(videoMode.mHeight * (viewWidth / float(videoMode.mWidth)));
        }
        else
        {
            // Video is wider than the view: crop left and right.  Also used
            // when aspect ratios match (no cropping)
            
            // ---====================---
            // -  =                  =  -
            // -  =                  =  -
            // -  =                  =  -
            // -  =                  =  -
            // ---====================---
            
            config.mSize.data[0] = int(videoMode.mWidth * (viewHeight / float(videoMode.mHeight)));
            config.mSize.data[1] = int(viewHeight);
        }
        
    }
    NSLog(@"cofigured w:%i, h:%i",config.mSize.data[0], config.mSize.data[1]);

    // Set the config
    Vuforia::Renderer::getInstance().setVideoBackgroundConfig(config);
    
    [self updateRenderingPrimitives];
}

- (BOOL)prepareToRenderWithViewportData:(MTLViewport *)viewportData
                             renderData:(Vuforia::RenderData *)renderData
                  backgroundTextureUnit:(Vuforia::TextureUnit *)videoBackgroundTextureUnit
                      backgroundTexture:(Vuforia::TextureData *)videoBackgroundTexture
{
    _vuforiaState = Vuforia::TrackerManager::getInstance().getStateUpdater().updateState();
    
    auto& renderer = Vuforia::Renderer::getInstance();
    renderer.begin(_vuforiaState, renderData);
    
    if (_currentRenderingPrimitives == nullptr)
    {
        [self updateRenderingPrimitives];
    }
    
    // Set up the viewport
    Vuforia::Vec4I viewportInfo;
    // We're writing directly to the screen, so the viewport is relative to the screen
    viewportInfo = _currentRenderingPrimitives->getViewport(Vuforia::VIEW_SINGULAR);
    viewportData->originX = viewportInfo.data[0];
    viewportData->originY = viewportInfo.data[1];
    viewportData->width = viewportInfo.data[2];
    viewportData->height = viewportInfo.data[3];
    viewportData->znear = 0.0f;
    viewportData->zfar = 1.0f;

    if (videoBackgroundTexture != nullptr)
    {
        renderer.setVideoBackgroundTexture(*videoBackgroundTexture);
    }

    return renderer.updateVideoBackgroundTexture(videoBackgroundTextureUnit);
}

- (void)vuforiaUpdate
{
    NSSet *oldResults = [NSSet setWithArray:_lastResults ?: @[]];
    NSSet *newResults = [NSSet setWithArray:self.results];

    NSMutableSet *temp = newResults.mutableCopy;
    [temp minusSet:oldResults];
    //newcommers
    for (ARResult *currentResult in temp)
    {
        if ([self.delegate respondsToSelector:@selector(arController:didStartTracking:)])
            [self.delegate arController:self didStartTracking:currentResult];
    }

    temp = oldResults.mutableCopy;
    [temp minusSet:newResults];
    //leavers
    for (ARResult *currentResult in temp)
    {
        if ([self.delegate respondsToSelector:@selector(arController:didStopTracking:)])
            [self.delegate arController:self didStopTracking:currentResult];
    }

    _lastResults = self.results;
}

void VuforiaCallbackWrapper::Vuforia_onUpdate(Vuforia::State& state)
{
    dispatch_async(dispatch_get_main_queue(),
    ^{
        [_sharedController vuforiaUpdate];
    });
}

- (void)pauseVuforia
{
    Vuforia::onPause();
    self.isVuforiaPaused = YES;
}

- (void)resumeVuforia
{
    Vuforia::onResume();
    self.isVuforiaPaused = NO;
}


#endif


@end
