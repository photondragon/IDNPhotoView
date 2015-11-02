#import "PhotoBrowserView.h"
#import "UIImage+IDNExtend.h"
#import "IDNTimekeeper.h"

//#define ZOOMVIEWTAG	100
#define ZOOM_STEP 1.5
#define MPhotosInterval	10
#define MPhotoBrowserSlideAcceleration	4096
#define MPhotoBrowserMaxSlideInitVelocity	1024

static NSLock*	PhotoBrowserImageResizeLocker=nil;	//过大图片调整大小的锁。防止调整图片时内存不足

@interface PhotoBrowserViewImageLoader : NSObject
<XUnitProtocol>
{
	NSString*	imgPath;
	UIImage*	image;
}
@property (strong,nonatomic) UIImage* image;
-(id) initWithPath:(NSString*)path;
@end
@implementation PhotoBrowserViewImageLoader
@synthesize image;

-(id) initWithPath:(NSString*)path
{
	if([super init])
	{
		imgPath = path;
	}
	return self;
}

-(BOOL) loadUnitForKey:(id)key
{
	UIImage* img;
	if([UIScreen mainScreen].scale>1.0 && (([imgPath rangeOfString:@"@2x."].length>0) || ([imgPath rangeOfString:@"@3x."].length>0)) )
	{
		img = [[UIImage alloc] initWithContentsOfFile:imgPath];
	}
	else
	{
		NSData* data = [[NSData alloc] initWithContentsOfFile:imgPath];
		img = [[UIImage alloc] initWithData:data];
	}
	CGSize size = img.size;
	int imgBytes = size.width*size.height*img.scale*img.scale*4;
	if(imgBytes > 20000000) //照片太大。6的最大照片3264×2448*4=31961088，
	{
		if(imgBytes>53526528) //6s拍照分辨率4224×3168*4=53526528
		{
			float r = sqrt(53526528.0/imgBytes);
			[PhotoBrowserImageResizeLocker lock];
			image = [img resizedImageWithSize:CGSizeMake(size.width*r, size.height*r)]; //减小分辨率
			[PhotoBrowserImageResizeLocker unlock];
		}
		else
		{
			[PhotoBrowserImageResizeLocker lock];
			image = [img imageWithoutOrientation]; //强制解码
			[PhotoBrowserImageResizeLocker unlock];
		}
	}
	else
	{
		image = [img imageWithoutOrientation]; //强制解码
	}
	image = img;
	if(image)
		return TRUE;
	return FALSE;
}

@end

@interface BrowedPhotoView : UIView
{
	UIImageView*	imageView;
	CGSize	frameSize;
	float	minScale;
	float	maxScale;
	float	curScale;
	CGRect	showRect;	//图像的显示框
	CGSize	imageSize;	//图像原始大小
	
	BOOL	isZooming;
	float	touchesDistanceInPhoto;
	CGPoint	zoomCenterInPhoto;
	
	BOOL	isDraging;
}
@property (strong,nonatomic) UIImage* image;
@property (assign,nonatomic) float	curScale;
@property (assign,nonatomic,readonly) CGRect showRect;
@property (assign,nonatomic,readonly) float	fitScale;	//图像与窗口等宽时的缩放比例
@property (assign,nonatomic) BOOL minimized;//curScale==minScale?
@property (assign,nonatomic) BOOL maximized;//curScale==maxScale?
@property (assign,nonatomic,readonly) BOOL isZooming;
@property (assign,nonatomic,readonly) BOOL isDraging;

-(void) setCurScale:(float)scale touchPoint:(CGPoint)touchPoint;
-(void) minimizedByTouch:(CGPoint)touchPoint;
-(void) maximizedByTouch:(CGPoint)touchPoint;
-(float) dragPhotoByOffset:(CGPoint)offset;//返回未完成的（剩余的）水平移动量
-(void) setTouchPointA:(CGPoint)posAInView pointB:(CGPoint)posBInView;
-(void) ignoreTouchPointA:(CGPoint)posAInView pointB:(CGPoint)posBInView;//忽略双指操作（会引起跳变）
-(void) setTouchEnd;
@end

@implementation BrowedPhotoView
@synthesize curScale;
@synthesize showRect;
@synthesize fitScale;
@synthesize isZooming;
@synthesize isDraging;

-(id) initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
//		self.backgroundColor = [UIColor blueColor];
		self.userInteractionEnabled = FALSE;
		self.clipsToBounds = TRUE;
		imageView = [[UIImageView alloc] init];
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		[self addSubview:imageView];
		
		frameSize = frame.size;
		if (frameSize.width<0||frameSize.height)
		{
			frameSize.width = 0;
			frameSize.height	=	0;
		}
	}
	return self;
}

//标准化图像的frame（当fame改变，或者Touch结束）
-(void) standardizeLayoutAnimated:(BOOL)animated focusPoint:(CGPoint)focusPointInPhoto
{
	if (curScale==0)
	{
		if(fitScale>1.0f)
			curScale = 1.0f;
		else
			curScale = fitScale;
	}
	else if (curScale<minScale)
		curScale = minScale;
	else if(curScale>maxScale)
		curScale = maxScale;
	showRect.size = CGSizeMake(imageSize.width*curScale,imageSize.height*curScale);
	if(showRect.size.width<=frameSize.width)
		showRect.origin.x = (frameSize.width-showRect.size.width)/2;
	else
	{
		showRect.origin.x = frameSize.width/2-focusPointInPhoto.x*curScale;
		if(showRect.origin.x>0)
			showRect.origin.x = 0;
		else if(showRect.origin.x+showRect.size.width<frameSize.width)
			showRect.origin.x = frameSize.width-showRect.size.width;
	}
	if(showRect.size.height<=frameSize.height)
		showRect.origin.y = (frameSize.height-showRect.size.height)/2;
	else
	{
		showRect.origin.y = frameSize.height/2-focusPointInPhoto.y*curScale;
		if(showRect.origin.y>0)
			showRect.origin.y = 0;
		else if(showRect.origin.y+showRect.size.height<frameSize.height)
			showRect.origin.y = frameSize.height-showRect.size.height;
	}
	
	if (animated)
	{
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	}
	imageView.frame = showRect;
	if (animated)
		[UIView commitAnimations];
}

-(void) setCurScale:(float)scale
{
	if(curScale==scale || scale<=0
//	   || isZooming || isDraging
	   || minScale==0)//minScale==0表示图片无效
		return;
	if(scale<minScale)
		curScale = minScale;
	else if(scale>maxScale)
		curScale = maxScale;
	else
		curScale = scale;
	showRect.size = CGSizeMake(imageSize.width*curScale,imageSize.height*curScale);
	showRect.origin.x = (frameSize.width-showRect.size.width)/2;
	showRect.origin.y = (frameSize.height-showRect.size.height)/2;
	
	imageView.frame = showRect;
}
-(void) setCurScale:(float)scale touchPoint:(CGPoint)touchPoint
{
	if(curScale==scale || scale<=0
	   || minScale==0)//minScale==0表示图片无效
		return;
	//由self坐标系转换为photo坐标系
	CGPoint focusInPhoto = [self pointFromView2Image:touchPoint];

	curScale = scale;
	[self standardizeLayoutAnimated:YES focusPoint:focusInPhoto];
}

//当self.frame改变或设置新图像时
-(void) frameChangedAnimated:(BOOL)animated focusPoint:(CGPoint)focusPointInPhoto
{
	if(frameSize.width<=0 || frameSize.height<=0
	   ||imageSize.width<=0 || imageSize.height<=0)
	{
		minScale = 0;
		maxScale = 0;
		curScale = 0;
		showRect = CGRectZero;
		imageView.frame = showRect;
	}
	else
	{
		float ratioWW = frameSize.width/imageSize.width;
		float ratioHH = frameSize.height/imageSize.height;
		fitScale = ratioWW < ratioHH ? ratioWW : ratioHH;
		float ratioWH = frameSize.width/imageSize.height;
		float ratioHW = frameSize.height/imageSize.width;
		float fitScale2 = ratioWH < ratioHW ? ratioWH : ratioHW;
		minScale = fitScale<fitScale2 ? fitScale : fitScale2;
		maxScale = fitScale>=fitScale2 ? fitScale : fitScale2;
		if(minScale>0.5f)
			minScale = 0.5f;
		if(maxScale<2.0f)
			maxScale = 2.0f;
		[self standardizeLayoutAnimated:animated focusPoint:focusPointInPhoto];
	}
}

-(BOOL) minimized
{
	return curScale==minScale;
}
-(void) setMinimized:(BOOL)minimized
{
	if(minimized && curScale!=minScale)
		self.curScale = minScale;
}
-(void) minimizedByTouch:(CGPoint)touchPoint
{
	if(curScale!=minScale)
		[self setCurScale:minScale touchPoint:touchPoint];
}
-(BOOL) maximized
{
	return curScale==maxScale;
}
-(void) setMaximized:(BOOL)maximized
{
	if(maximized && curScale!=maxScale)
		self.curScale = maxScale;
}
-(void) maximizedByTouch:(CGPoint)touchPoint
{
	if(curScale!=maxScale)
		[self setCurScale:maxScale touchPoint:touchPoint];
}

-(UIImage*) image
{
	return imageView.image;
}
-(void) setImage:(UIImage *)image scale:(float)scale showOrigin:(CGPoint)origin;
{
	imageView.image = image;
	
	imageSize = image.size;
	
	curScale = scale;
	showRect.origin = origin;
	CGPoint focusPoint = [self pointFromView2Image:CGPointMake(frameSize.width/2,frameSize.height/2)];
	[self frameChangedAnimated:NO focusPoint:focusPoint];
	
	if (isZooming)
		isZooming = FALSE;
	if (isDraging)
		isDraging = FALSE;
}
-(void) setImage:(UIImage *)image
{
	[self setImage:image scale:0 showOrigin:CGPointZero];
}

-(void) setFrame:(CGRect)frame
{
	CGSize originFrameSize = self.frame.size;
	[super setFrame:frame];
	frameSize = self.frame.size;
	if (frameSize.width<0||frameSize.height<0)
	{
		frameSize.width = 0;
		frameSize.height	=	0;
	}
	
	if(frameSize.width==originFrameSize.width && frameSize.height==originFrameSize.height)
		return;
	CGPoint focusPoint = [self pointFromView2Image:CGPointMake(originFrameSize.width/2,originFrameSize.height/2)];
	[self frameChangedAnimated:YES focusPoint:focusPoint];
	
	if (isZooming)
		isZooming = FALSE;
	if (isDraging)
		isDraging = FALSE;
}
-(void) setBounds:(CGRect)bounds
{
	CGSize originFrameSize = self.frame.size;
	[super setBounds:bounds];
	frameSize = self.frame.size;
	if (frameSize.width<0||frameSize.height<0)
	{
		frameSize.width = 0;
		frameSize.height	=	0;
	}
	
	if(frameSize.width==originFrameSize.width && frameSize.height==originFrameSize.height)
		return;
	CGPoint focusPoint = [self pointFromView2Image:CGPointMake(originFrameSize.width/2,originFrameSize.height/2)];
	[self frameChangedAnimated:YES focusPoint:focusPoint];
	
	if (isZooming)
		isZooming = FALSE;
	if (isDraging)
		isDraging = FALSE;
}

-(CGPoint) pointFromView2Image:(CGPoint)posInView
{
	return CGPointMake((posInView.x-showRect.origin.x)/curScale,(posInView.y-showRect.origin.y)/curScale);
}

-(CGPoint) moveOffsetByDragOffset:(CGPoint)offset
{
	//如果在双指操作时已经把图像的一部分拖出边框，转为单指操作时，如果简单的把图像移动到范围内，则会产生图像跳动
	//以下算法可避免产生这种跳动
	if(showRect.size.width>=frameSize.width)
	{
		if(showRect.origin.x>0)
		{
			if(offset.x>0)
				offset.x = 0;
		}
		else if(showRect.origin.x+showRect.size.width<frameSize.width)
		{
			if(offset.x<0)
				offset.x = 0;
		}
		else
		{
			if(offset.x>0 && showRect.origin.x+offset.x>0)
				offset.x = 0-showRect.origin.x;
			else if(offset.x<0 && showRect.origin.x+offset.x+showRect.size.width<frameSize.width)
				offset.x = frameSize.width-showRect.size.width-showRect.origin.x;
		}
//		if(offset.x)
//			offset.x = 0;
	}
	else
	{
		float d = frameSize.width/2-(showRect.origin.x+showRect.size.width/2);
		if(d==0)
			offset.x = 0;
		else if(d>0)
		{
			if(offset.x>d)
				offset.x = d;
			else if(offset.x<0)
				offset.x = 0;
		}
		else// if(d<0)
		{
			if(offset.x<d)
				offset.x = d;
			else if(offset.x>0)
				offset.x = 0;
		}
	}
	if((offset.y<0 && showRect.origin.y<=0 && showRect.origin.y+showRect.size.height<=frameSize.height)
	   ||(offset.y>0 && showRect.origin.y>=0 && showRect.origin.y+showRect.size.height>=frameSize.height) )
		offset.y/=3;
	return offset;
}

//返回未完成的（剩余的）水平移动量
-(float) dragPhotoByOffset:(CGPoint)offset
{
	if (minScale==0)
		return offset.x;
	float x;
	if (isDraging)
	{
		CGPoint moveoffset = [self moveOffsetByDragOffset:offset];
		x = offset.x-moveoffset.x;
		showRect.origin.x	+= moveoffset.x;
		showRect.origin.y	+= moveoffset.y;

		imageView.frame = showRect;
	}
	else
	{
		x = 0;
		isDraging = TRUE;
		if (isZooming)
			isZooming = FALSE;
	}
	return x;
}

-(void) setTouchPointA:(CGPoint)posAInView pointB:(CGPoint)posBInView
{
	if (minScale==0)
		return;
	if(isZooming)
	{
		float dx = posAInView.x-posBInView.x;
		float dy = posAInView.y-posBInView.y;
		float touchesDistanceInCamera = sqrtf(dx*dx+dy*dy);
		if (touchesDistanceInCamera<1)
			return;
		curScale = touchesDistanceInCamera/touchesDistanceInPhoto;
		
		CGPoint zoomCenterInPhotoScaled = CGPointMake(zoomCenterInPhoto.x*curScale, zoomCenterInPhoto.y*curScale);
		CGPoint zoomCenterInView = CGPointMake((posAInView.x+posBInView.x)/2, (posAInView.y+posBInView.y)/2);
		showRect.origin = CGPointMake(zoomCenterInView.x-zoomCenterInPhotoScaled.x,
								  zoomCenterInView.y-zoomCenterInPhotoScaled.y);
		showRect.size.width = imageSize.width*curScale;
		showRect.size.height= imageSize.height*curScale;
		imageView.frame = showRect;
	}
	else
	{
		isZooming = TRUE;
		if (isDraging)
			isDraging = FALSE;
	}
	CGPoint posAInPhoto = [self pointFromView2Image:posAInView];//图片坐标系，与缩放无关
	CGPoint posBInPhoto = [self pointFromView2Image:posBInView];//图片坐标系，与缩放无关
	float dx = posAInPhoto.x-posBInPhoto.x;
	float dy = posAInPhoto.y-posBInPhoto.y;
	touchesDistanceInPhoto = sqrtf(dx*dx+dy*dy);
	if(touchesDistanceInPhoto<1)
		touchesDistanceInPhoto = 1;
	zoomCenterInPhoto = CGPointMake((posAInPhoto.x+posBInPhoto.x)/2, (posAInPhoto.y+posBInPhoto.y)/2);
}
-(void) ignoreTouchPointA:(CGPoint)posAInView pointB:(CGPoint)posBInView
{
	CGPoint posAInPhoto = [self pointFromView2Image:posAInView];//图片坐标系，与缩放无关
	CGPoint posBInPhoto = [self pointFromView2Image:posBInView];//图片坐标系，与缩放无关
	float dx = posAInPhoto.x-posBInPhoto.x;
	float dy = posAInPhoto.y-posBInPhoto.y;
	touchesDistanceInPhoto = sqrtf(dx*dx+dy*dy);
	zoomCenterInPhoto = CGPointMake((posAInPhoto.x+posBInPhoto.x)/2, (posAInPhoto.y+posBInPhoto.y)/2);
}

-(void) setTouchEnd
{
	if (isDraging==FALSE && isZooming==FALSE)
		return;
	else if(isZooming)
		isZooming = FALSE;
	else if (isDraging)
		isDraging = FALSE;
	
	if (curScale<minScale)
	{
		[self setCurScale:minScale touchPoint:CGPointMake(frameSize.width/2, frameSize.height/2)];
		return;
	}
	else if(curScale>maxScale)
	{
		[self setCurScale:maxScale touchPoint:CGPointMake(frameSize.width/2, frameSize.height/2)];
		return;
	}

	BOOL bounce = FALSE;
	if(showRect.size.width<=frameSize.width)
	{
		showRect.origin.x = (frameSize.width-showRect.size.width)/2;
		bounce = TRUE;
	}
	else if(showRect.size.width+showRect.origin.x<frameSize.width)
	{
		showRect.origin.x = frameSize.width-showRect.size.width;
		bounce = TRUE;
	}
	else if(showRect.origin.x>0)
	{
		showRect.origin.x = 0;
		bounce = TRUE;
	}
	if(showRect.size.height<=frameSize.height)
	{
		showRect.origin.y = (frameSize.height-showRect.size.height)/2;
		bounce = TRUE;
	}
	else if(showRect.size.height+showRect.origin.y<frameSize.height)
	{
		showRect.origin.y = frameSize.height-showRect.size.height;
		bounce = TRUE;
	}
	else if(showRect.origin.y>0)
	{
		showRect.origin.y = 0;
		bounce = TRUE;
	}
	
	if(bounce)
	{
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		imageView.frame = showRect;
		[UIView commitAnimations];
	}
}
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
}

@end

@interface BrowedPhotoInfo : NSObject
{
	BrowedPhotoView*	view;
	float	curScale;
	CGPoint	showOrigin;
	int		index;
}
@property (strong,nonatomic) BrowedPhotoView*	view;
@property (assign,nonatomic) float	curScale;
@property (assign,nonatomic) CGPoint	showOrigin;
@property (assign,nonatomic) int	index;//图片序号
@end
@implementation BrowedPhotoInfo
@synthesize view;
@synthesize curScale;
@synthesize showOrigin;
@synthesize index;
@end

//UIScrollView的zoomScale影响subView的大小，contentSize，但不改变subView的origin
@interface PhotoBrowserView(hidden)
-(void) setSourceOnMainThread:(id<PhotoBrowserViewSource>)aSource;
-(void) setCurrentPhotoOnMainThreadByIndex:(int)index animated:(BOOL)animated;
-(void) switchToPrevPhotoOnMainThread;
-(void) switchToNextPhotoOnMainThread;
-(void) afterResizeOnMainThread;
-(void) setCurrentPhotoOnMainThreadByIndexNumber:(NSNumber*)iNumber;
@end

@implementation PhotoBrowserView
{
	id<PhotoBrowserViewDelegate>	delegate;
	id<PhotoBrowserViewSource>	source;
	UIView*	viewContainer;	//所有ImageView都放在这个View中
	XLoader*	photoLoader;
	NSMutableDictionary*	dicImageInfos;
	NSMutableArray*	arrPhotoViewTrash;
	int		currentIndex;
	int		photosCount;

	TouchAssistant*	touchAssist;
	TouchesAssist* touchesAssist;
	BOOL	isTouchMoved;
	BOOL	isSwipeDisabled;	//轻扫是否禁用。当照片放大至超出屏幕时，当在屏幕内拖动显示照片的中间部分，而不是将照片拖动到边缘时，就会禁用本次Touch的swipe功能。
	float	distance2;//两个touches之间的距离的平方
	float	slideLeftTime;	//滑动剩余时间
	CGPoint	slideVelocity;	//滑动速度after touch
	CGPoint slideAcceleration;	//滑动加（减）速度
	CGPoint slidePoint;
	NSTimer*slideTimer;	//assign

	IDNTimekeeper* timer;
}
@synthesize delegate;

-(void) initialize
{
	if(timer)
		return;

	timer = [[IDNTimekeeper alloc] init];
//	self.backgroundColor = [UIColor grayColor];
	self.multipleTouchEnabled = TRUE;
	viewContainer = [[UIView alloc] init];
	[self addSubview:viewContainer];
		
//	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
//	[self addGestureRecognizer:singleTap];
//	[singleTap release];
//	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
//	[doubleTap setNumberOfTapsRequired:2];
//	[self addGestureRecognizer:doubleTap];
//	[doubleTap release];
//	UISwipeGestureRecognizer* swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeLeft:)];
//	[swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
//	[self addGestureRecognizer:swipeLeft];
//	[swipeLeft release];
//	UISwipeGestureRecognizer* swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeRight:)];
//	[swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
//	[self addGestureRecognizer:swipeRight];
//	[swipeRight release];

	dicImageInfos = [[NSMutableDictionary alloc] init];
	arrPhotoViewTrash = [[NSMutableArray alloc] init];
	
	photoLoader = [[XLoader alloc] init];
	[photoLoader setDelegate:self];
	
	currentIndex = -1;
	photosCount = 0;
	
	touchAssist = [[TouchAssistant alloc] init];
	touchesAssist = [[TouchesAssist alloc] init];
	touchesAssist.delegate = self;
	
	if(PhotoBrowserImageResizeLocker==nil)
		PhotoBrowserImageResizeLocker = [[NSLock alloc] init];
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
	if((self=[super initWithCoder:aDecoder]))
	{
		[self initialize];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
	{
		[self initialize];
    }
    return self;
}

-(void) setFrame:(CGRect)rect
{
//	CGSize oldSize = self.frame.size;
	[super setFrame:rect];
//	CGSize showSize = rect.size;
//	if(oldSize.width==showSize.width && oldSize.height==showSize.height)
//		return;
	if(viewContainer==nil)//没有初始化
		return;
	[self performSelectorOnMainThread:@selector(afterResizeOnMainThread) withObject:nil waitUntilDone:NO];
}

-(void) setBounds:(CGRect)rect
{
//	CGSize oldSize = self.frame.size;
	[super setBounds:rect];
//	CGSize showSize = rect.size;
//	if(oldSize.width==showSize.width && oldSize.height==showSize.height)
//		return;
	if(viewContainer==nil)//没有初始化
		return;
	[self performSelectorOnMainThread:@selector(afterResizeOnMainThread) withObject:nil waitUntilDone:NO];
}

-(id<PhotoBrowserViewSource>)source
{
	return source;
}
-(void) setSource:(id<PhotoBrowserViewSource>)aSource
{
	[self performSelectorOnMainThread:@selector(setSourceOnMainThread:) withObject:aSource waitUntilDone:YES];
}

-(void) setCurrentPhotoByIndex:(int)index
{
	[self performSelectorOnMainThread:@selector(setCurrentPhotoOnMainThreadByIndexNumber:) withObject:[NSNumber numberWithInt:index] waitUntilDone:YES];
}

#pragma mark TapDetectingImageViewDelegate methods

-(void) notifyPhotoClicked
{
	if([delegate respondsToSelector:@selector(photoBrowseViewClicked)])
		[delegate photoBrowseViewClicked];
}

-(void) stepZoomByTouch:(CGPoint)touchPoint
{
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	BrowedPhotoView* view = info.view;
	if(view)
	{
		CGPoint point;
		point.x = touchPoint.x-viewContainer.frame.origin.x-view.frame.origin.x;
		point.y = touchPoint.y-viewContainer.frame.origin.y-view.frame.origin.y;
		if(view.curScale != view.fitScale)
			[view setCurScale:view.fitScale touchPoint:point];
		else
		{
			if(view.fitScale==1.0f)
				[view setCurScale:2.0f touchPoint:point];
			else
				[view setCurScale:1.0f touchPoint:point];
		}
//		if(view.minimized)
//			[view maximizedByTouch:point];
//		else if(view.maximized)
//			[view minimizedByTouch:point];
//		else
//			[view setCurScale:1 touchPoint:point];
	}
}

#pragma mark XLoaderDelegate
-(void) xLoader:(XLoader*)loader loadedObject:(id<XUnitProtocol>)object forKey:(id)keyObj;
{
	if(currentIndex==-1)
		return;
	int index = [(NSNumber*)keyObj intValue];
	if(index<0 || index>=photosCount)
		return;
	UIImage* image = [(PhotoBrowserViewImageLoader*)object image];
	BrowedPhotoInfo*info = [dicImageInfos objectForKey:keyObj];
	if(info.curScale>0)
		[info.view setImage:image scale:info.curScale showOrigin:info.showOrigin];
	else
		info.view.image = image;
}

-(void) scrollPhotos:(float)dx
{
	CGRect frame = viewContainer.frame;
	frame.origin.x	+= dx;
	viewContainer.frame = frame;
}
-(void) scrollPhotosEnd:(float)dx
{
	CGRect frame = viewContainer.frame;
	frame.origin.x	+= dx;
	float width = self.frame.size.width+MPhotosInterval;
	int index = (MPhotosInterval/2-frame.origin.x+width/2)/width;
	if(index<0)
		index = 0;
	else if(index>=photosCount)
		index = photosCount-1;
	[self setCurrentPhotoOnMainThreadByIndex:index animated:YES];
}

-(void) move:(CGPoint)offset
{
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	BrowedPhotoView* view = info.view;
	float scrolledx =viewContainer.frame.origin.x+currentIndex*(self.frame.size.width+MPhotosInterval);
	if(scrolledx<0 && offset.x>0)
	{
		if(scrolledx+offset.x>0)
		{
			[self scrollPhotos:-scrolledx];
			offset.x += scrolledx;
		}
		else
		{
			[self scrollPhotos:offset.x];
			offset.x = 0;
		}
	}
	else if(scrolledx>0 && offset.x<0)
	{
		if(scrolledx+offset.x<0)
		{
			[self scrollPhotos:-scrolledx];
			offset.x += scrolledx;
		}
		else
		{
			[self scrollPhotos:offset.x];
			offset.x = 0;
		}
	}
	float sx = [view dragPhotoByOffset:offset];
	if(offset.x!=0 && offset.x!=sx)
		isSwipeDisabled = TRUE;
	[self scrollPhotos:sx];
}

-(void) slideAfterTouch
{
	[timer end];
	float dt = [timer getElapsedTime];
	[timer restart];
	if(dt>slideLeftTime)
		dt = slideLeftTime;
	
	CGPoint offset;
	offset.x = slideVelocity.x*dt + 0.5*slideAcceleration.x*dt*dt;
	offset.y = slideVelocity.y*dt + 0.5*slideAcceleration.y*dt*dt;
	slidePoint.x += offset.x;
	slidePoint.y += offset.y;
	[self move:offset];

	slideVelocity.x	+= slideAcceleration.x*dt;
	slideVelocity.y	+= slideAcceleration.y*dt;
	slideLeftTime -= dt;
	if(slideLeftTime==0)
	{
		[slideTimer invalidate];
		slideTimer = nil;
		BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
		[info.view setTouchEnd];
		[self scrollPhotosEnd:0];
	}
}
-(void) slideCancel
{
	[slideTimer invalidate];
	slideTimer = nil;
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	[info.view setTouchEnd];
	[self scrollPhotosEnd:0];
}
#pragma mark Touches
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[touchesAssist touchesBegan:touches withEvent:event];
}
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[touchesAssist touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[touchesAssist touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[touchesAssist touchesCancelled:touches withEvent:event];
	NSLog(@"[PhotoBrowserView touchesCancelled:withEvent:]");
}

#pragma mark TouchesAssistDelegate
-(void) touchesAssistSingleTouchBegan:(CGPoint)point
{
	if(slideTimer)
		[self slideCancel];
	isTouchMoved = FALSE;
	isSwipeDisabled = FALSE;
	[touchAssist touchBeganAtPoint:point];
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	BrowedPhotoView* view = info.view;
	[view dragPhotoByOffset:CGPointZero];
}

-(void) touchesAssistSingleTouchMoved:(CGPoint)point
{
	float prevTime = touchAssist.touchTime;
	[touchAssist touchMovedToPoint:point];
	CGPoint offset = touchAssist.offset;
	//计算第一个move是否会引起跳动，以决定是否要忽略这个Move
	if(isTouchMoved==FALSE)
	{
		isTouchMoved =TRUE;
		float dt = touchAssist.touchTime-prevTime;
		if(offset.x*offset.x+offset.y*offset.y>25 && dt>0.1)//忽略引起跳变的Move
			return;
	}

	[self move:offset];
}
-(void) touchesAssistSingleTouchEnded:(CGPoint)point
{
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];

	ETouchAssistantType touchType = [touchAssist touchEndedAtPoint:point];
	if(touchesAssist.isPureSingleTouch)
	{
		if(touchType==ETouchAssistantType_Tap)
		{
			[info.view setTouchEnd];
			[self scrollPhotosEnd:0];
			if(touchAssist.tapsCount==1)
			{
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(notifyPhotoClicked) object:nil];
				[self performSelector:@selector(notifyPhotoClicked) withObject:nil afterDelay:0.3];
			}
			else if(touchAssist.tapsCount==2)
			{
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(notifyPhotoClicked) object:nil];
				[self stepZoomByTouch:touchAssist.touchPoint];
			}
			return;
		}
		else if(touchType==ETouchAssistantType_SwipeH && isSwipeDisabled==FALSE)
		{
			if(touchAssist.offset.x>0 && currentIndex>0)
			{
				[self switchToPrevPhotoOnMainThread];
				[info.view setTouchEnd];
				return;
			}
			else if(touchAssist.offset.x<0 && currentIndex<photosCount-1)
			{
				[self switchToNextPhotoOnMainThread];
				[info.view setTouchEnd];
				return;
			}
			//如果不能往前翻页，则不return，执行后面的slide代码
		}
	}
	CGPoint offset = touchAssist.offset;
	if(touchesAssist.curTouchesCount==0)
	{
		BrowedPhotoView* view = info.view;

		slideVelocity = touchAssist.touchVelocity;
		float v = sqrtf(slideVelocity.x*slideVelocity.x+slideVelocity.y*slideVelocity.y);
		if(v>MPhotoBrowserMaxSlideInitVelocity)
		{
			float r = MPhotoBrowserMaxSlideInitVelocity/v;
			slideVelocity.x *= r;
			slideVelocity.y *= r;
			v = MPhotoBrowserMaxSlideInitVelocity;
		}
		slideLeftTime = v/MPhotoBrowserSlideAcceleration;
		if (slideLeftTime<0.01)
		{
			[view setTouchEnd];
			[self scrollPhotosEnd:0];
		}
		else
		{
			[self move:offset];

			[timer start];
			slideAcceleration.x = -slideVelocity.x/slideLeftTime;
			slideAcceleration.y = -slideVelocity.y/slideLeftTime;
			slidePoint = point;
			slideTimer = [NSTimer scheduledTimerWithTimeInterval:0.005 target:self selector:@selector(slideAfterTouch) userInfo:0 repeats:YES];
		}
	}
	else if(touchesAssist.curTouchesCount!=2)
	{
		[info.view setTouchEnd];
		[self scrollPhotosEnd:0];
	}
	else
		[self scrollPhotosEnd:0];
}
-(void) touchesAssistSingleTouchCancelled:(CGPoint)point
{
	[touchAssist touchEndedAtPoint:point];
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	[self scrollPhotosEnd:0];
	[info.view setTouchEnd];
}

-(void) touchesAssistDoubleTouchPointA:(CGPoint)pointA touchPointB:(CGPoint)pointB
{
	if(slideTimer)
		[self slideCancel];
	BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
	if(distance2==0)//双指操作开始
	{
		float dx = pointA.x-pointB.x;
		float dy = pointA.y-pointB.y;
		distance2 = dx*dx+dy*dy;
		isTouchMoved = FALSE;
		[timer start];
	}
	else
	{
		if(isTouchMoved==FALSE)
		{
			float dx = pointA.x-pointB.x;
			float dy = pointA.y-pointB.y;
			float d2 = dx*dx+dy*dy;
			float d = d2-distance2;
			if(d<0) d = -d;
			if(d>0)
			{
				isTouchMoved =TRUE;
				[timer end];
				float dt = [timer getElapsedTime];
				if(d>25 && dt>0.1)//忽略这个操作（会引起界面跳变）
				{
					[info.view ignoreTouchPointA:pointA pointB:pointB];
					return;
				}
			}
		}
	}
	[info.view setTouchPointA:pointA pointB:pointB];
}
-(void) touchesAssistDoubleTouchEnded
{
	distance2 = 0;
	if(touchesAssist.curTouchesCount!=1)
	{
		BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:currentIndex]];
		[info.view setTouchEnd];
	}
}
@end

@implementation PhotoBrowserView(hidden)

-(void) clearSource
{
	[photoLoader cancelLoadingAllObjects];
	if(currentIndex>=0)
	{
		for (int i=currentIndex-1; i<=currentIndex+1; i++)
		{
			BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:i]];
			if(info)
			{
				BrowedPhotoView* view = info.view;
				if(view)
				{
					[arrPhotoViewTrash addObject:view];
					view.image = nil;
					[view removeFromSuperview];
				}
			}
		}
	}
	[dicImageInfos removeAllObjects];
	currentIndex = -1;
	photosCount = 0;
	source = nil;
	viewContainer.frame = CGRectMake(0, 0, 0, 0);
}

-(void) setSourceOnMainThread:(id<PhotoBrowserViewSource>)aSource
{
	[self clearSource];
	source = aSource;
	photosCount = [source getPhotosCount];
	for (int i=0; i<photosCount; i++)
	{
		BrowedPhotoInfo* info = [[BrowedPhotoInfo alloc] init];
		info.index = i;
		[dicImageInfos setObject:info forKey:[NSNumber numberWithInt:i]];
	}
	if(photosCount)
	{
		[self setCurrentPhotoOnMainThreadByIndex:0 animated:NO];
	}
	else
	{
		if([delegate respondsToSelector:@selector(photoBrowseViewSelectedByIndex:)])
			[delegate photoBrowseViewSelectedByIndex:-1];
	}
}

-(void) setCurrentPhotoOnMainThreadByIndexNumber:(NSNumber*)iNumber
{
	if (iNumber) {
		[self setCurrentPhotoOnMainThreadByIndex:[iNumber intValue] animated:NO];
	}
}
-(void) setCurrentPhotoOnMainThreadByIndex:(int)index animated:(BOOL)animated
{
	if(index<0 || index>=photosCount)
		return;
	CGRect frame = self.frame;
	if(index==currentIndex)
	{
		float x = -index*(frame.size.width+MPhotosInterval);
		if(viewContainer.frame.origin.x!=x)
		{
			if(animated)
			{
				[UIView beginAnimations:nil context:nil];
				[UIView setAnimationDuration:0.3];
				[UIView setAnimationDelegate:self];
				[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
			}
			viewContainer.frame = CGRectMake(x, 0, 0, 0);
			if(animated)
				[UIView commitAnimations];
		}
		return;
	}

	int newstart = index-1;
	int newend = index+1+1;
	if(newstart<0)
		newstart = 0;
	if(newend>photosCount)
		newend = photosCount;
	int oldstart;
	int oldend;
	int start,end;
	if(currentIndex==-1)
	{
		oldstart = oldend = -1;
		start = 0;
		end = 2;
	}
	else
	{
		oldstart = currentIndex-1;
		oldend = currentIndex+2;
		if(oldstart<0)
			oldstart = 0;
		if(oldend>photosCount)
			oldend = photosCount;
		start = oldstart<newstart ? oldstart : newstart;
		end = oldend>newend ? oldend : newend;
	}

	for(int i=start;i<end;i++)
	{
		if(i>=oldstart && i< oldend && i>=newstart && i<newend)
			continue;
		if(i>=oldstart && i< oldend)//原有的
		{
			NSNumber* indexNum = [NSNumber numberWithInt:i];
			BrowedPhotoInfo* info = [dicImageInfos objectForKey:indexNum];
			[photoLoader cancelLoadingObjectByKey:indexNum];
			BrowedPhotoView* view = info.view;
			info.curScale = view.curScale;
			info.showOrigin = view.showRect.origin;
			view.image = nil;
			[arrPhotoViewTrash addObject:view];
			info.view = nil;
		}
		else if(i>=newstart && i<newend)//新增的
		{
			NSNumber* iNumber = [NSNumber numberWithInt:i];
			BrowedPhotoInfo*info = [dicImageInfos objectForKey:iNumber];

			BrowedPhotoView*view = [arrPhotoViewTrash lastObject];
			if(view==nil)
			{
				view = [[BrowedPhotoView alloc] init];
				info.view = view;
			}
			else
			{
				info.view = view;
				[arrPhotoViewTrash removeLastObject];
			}
			view.frame = CGRectMake(i*(frame.size.width+MPhotosInterval), 0, frame.size.width, frame.size.height);
			[viewContainer addSubview:view];

			NSString* path = [source getPhotoPathByIndex:i];
			PhotoBrowserViewImageLoader* loaderUnit = [[PhotoBrowserViewImageLoader alloc] initWithPath:path];
			[photoLoader loadObject:loaderUnit forKey:iNumber];
		}
	}

	if(animated)
	{
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	}
	viewContainer.frame = CGRectMake(-index*(frame.size.width+MPhotosInterval), 0, 0, 0);
	if(animated)
		[UIView commitAnimations];

	currentIndex = index;
	if([delegate respondsToSelector:@selector(photoBrowseViewSelectedByIndex:)])
		[delegate photoBrowseViewSelectedByIndex:index];
}

-(void) animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
}

-(void) switchToNextPhotoOnMainThread
{
	if(currentIndex== -1 || currentIndex>=photosCount)
		return;
	int index;
	if(currentIndex==photosCount-1)
		index = photosCount-1;
	else
		index = currentIndex+1;
	[self setCurrentPhotoOnMainThreadByIndex:index animated:YES];
}

-(void) switchToPrevPhotoOnMainThread
{
	if(currentIndex== -1 || currentIndex<0)
		return;
	int index;
	if(currentIndex==0)
		index = 0;
	else
		index = currentIndex-1;
	[self setCurrentPhotoOnMainThreadByIndex:index animated:YES];
}

-(void) afterResizeOnMainThread
{
	if(currentIndex>=0)
	{
		CGRect frame = self.frame;
		for (int i=currentIndex-1; i<=currentIndex+1; i++)
		{
			BrowedPhotoInfo* info = [dicImageInfos objectForKey:[NSNumber numberWithInt:i]];
			if(info)
			{
				BrowedPhotoView* view = info.view;
				view.frame = CGRectMake(i*(frame.size.width+MPhotosInterval), 0, frame.size.width, frame.size.height);
			}
		}
		viewContainer.frame = CGRectMake(-currentIndex*(frame.size.width+MPhotosInterval), 0, 0, 0);
	}
}
@end

