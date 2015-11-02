/** @file UIImageAdjust.m
 */
#import "UIImageAdjust.h"
#include <math.h>

static inline double radians (double degrees) {return degrees * M_PI/180;}

static void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth,
								 float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0) {
		CGContextAddRect(context, rect);
		return;
    }
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth(rect) / ovalWidth;
    fh = CGRectGetHeight(rect) / ovalHeight;
    
    CGContextMoveToPoint(context, fw, fh/2);  // Start at lower right corner
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);  // Top right corner
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // Top left corner
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // Lower left corner
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // Back to lower right
	CGContextClosePath(context);
    
    CGContextRestoreGState(context);
}

@implementation UIImageAdjust

+ (UIImage *)allocImageAndResize:(CGSize)size fromImage:(UIImage*)originImage
{
	if(originImage==nil)
		return nil;
    CGImageRef imageRef = originImage.CGImage;
	size.width = (int)size.width;
	size.height = (int)size.height;
	int bytesPerRow = 4*size.width;
	//void* buffer = malloc(bytesPerRow*size.height);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL,//buffer,
												 size.width,
												 size.height,
												 8,
												 bytesPerRow,
												 colorSpace,
												 kCGImageAlphaPremultipliedLast);
    
	CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), imageRef);
    
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *img = [[UIImage alloc] initWithCGImage:imgRef];
	//free(buffer);
    CGImageRelease(imgRef);
    
    return img;
}

+ (UIImage *)allocImageAndResizeAndRounded:(CGSize)size fromImage:(UIImage*)originImage
{
 	if(originImage==nil)
		return nil;
    int w = size.width;
    int h = size.height;
    
    UIImage *img = originImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGRect rect = CGRectMake(0, 0, w, h);
    
    CGContextBeginPath(context);
    addRoundedRectToPath(context, rect, 5, 5);
    CGContextClip(context);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), img.CGImage);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage* retImg	 = [[UIImage alloc] initWithCGImage:imageMasked];
	CGImageRelease(imageMasked);
	return retImg;
}

+ (UIImage *)allocImageWithNewSize:(CGSize)size withinPath:(CGPathRef)path fromImage:(UIImage*)originImage
{
 	if(originImage==nil)
		return nil;
    int w = size.width;
    int h = size.height;
    
    UIImage *img = originImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    
	CGContextAddPath(context, path);
    CGContextClip(context);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), img.CGImage);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage* retImg	 = [[UIImage alloc] initWithCGImage:imageMasked];
	CGImageRelease(imageMasked);
	return retImg;
}

+(UIImage *)addImageReflection:(CGFloat)reflectionFraction fromImage:(UIImage*)originImage
{
 	if(originImage==nil)
		return nil;
	int reflectionHeight = originImage.size.height * reflectionFraction;
	
    // gradient is always black-white and the mask must be in the gray colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // create the bitmap context
    CGContextRef gradientBitmapContext = CGBitmapContextCreate(nil, 1, reflectionHeight,
                                                               8, 0, colorSpace, kCGImageAlphaNone);
    
    // define the start and end grayscale values (with the alpha, even though
    // our bitmap context doesn't support alpha the gradient requires it)
    CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
	
	CGFloat points[] = {0,1};
    // create the CGGradient and then release the gray color space 创建渐变信息［0，1］
    CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, points, 2);
    CGColorSpaceRelease(colorSpace);
    
    // create the start and end points for the gradient vector (straight down)
    CGPoint gradientStartPoint = CGPointMake(0, reflectionHeight/4);
    CGPoint gradientEndPoint = CGPointZero;
    
    // draw the gradient into the gray bitmap context 绘制BMP context
    CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
                                gradientEndPoint, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(grayScaleGradient);
	
	// add a black fill with 40% opacity
	CGContextSetGrayFillColor(gradientBitmapContext, 0.0, 0.4);//gray=0,alpha=0.4
	CGContextFillRect(gradientBitmapContext, CGRectMake(0, 0, 1, reflectionHeight));
    
    // create a 2 bit CGImage containing a gradient that will be used for masking the 
    // main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
    // function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
	CGImageRef gradientMaskImage = NULL;
    // convert the context into a CGImageRef and release the context（创建Mask图像）
    gradientMaskImage = CGBitmapContextCreateImage(gradientBitmapContext);
    CGContextRelease(gradientBitmapContext);
	
    // create an image by masking the bitmap of the mainView content with the gradient view
    // then release the  pre-masked content bitmap and the gradient bitmap
    CGImageRef reflectionImage = CGImageCreateWithMask(originImage.CGImage, gradientMaskImage);
    CGImageRelease(gradientMaskImage);
	
	CGSize size = CGSizeMake(originImage.size.width, originImage.size.height + reflectionHeight);
	
    CGColorSpaceRef targetColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef targetBitmapContext = CGBitmapContextCreate(nil, size.width, size.height,
															 8, 0, targetColorSpace, kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(targetColorSpace);
	CGContextDrawImage(targetBitmapContext, CGRectMake(0, originImage.size.height, originImage.size.width, originImage.size.height), originImage.CGImage);
	CGAffineTransform trans = CGAffineTransformMake(1, 0, 0, -1, 0, reflectionHeight);
	CGContextConcatCTM(targetBitmapContext, trans);
	CGContextDrawImage(targetBitmapContext, CGRectMake(0, 0, originImage.size.width, reflectionHeight), reflectionImage);
    CGImageRelease(reflectionImage);
	CGImageRef targetImgRef = CGBitmapContextCreateImage(targetBitmapContext);
	CGContextRelease(targetBitmapContext);
	UIImage* result = [UIImage imageWithCGImage:targetImgRef];
	CGImageRelease(targetImgRef);
	/*UIGraphicsBeginImageContext(size);
	 
	 [self drawAtPoint:CGPointZero];
	 CGContextRef context = UIGraphicsGetCurrentContext();
	 CGContextDrawImage(context, CGRectMake(0, self.size.height, self.size.width, reflectionHeight), reflectionImage);
	 
	 UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
	 UIGraphicsEndImageContext();*/
	
	return result;
}

+(UIImage*) copyImageWithNewSize:(CGSize)newSize withRefletionHeightRatio:(CGFloat)ratio fromImage:(UIImage*)originImage
{
 	if(originImage==nil)
		return nil;
	if(newSize.width<=1 || newSize.height<=1 || ratio<0 || ratio>1)
		return nil;
	int width = newSize.width;
	int height = newSize.height;
	int reflectionHeight = (int)(height*ratio);
	int heightWithReflection= height+ reflectionHeight;
	int bytesPerRow = width*4;
	
	unsigned char* pData = malloc(bytesPerRow*heightWithReflection);//创建图像的内存
	if(pData==0)
		return nil;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pData,
													width,
													heightWithReflection,
													8,
													bytesPerRow,
													colorSpace,
													kCGImageAlphaPremultipliedLast);//创建context，其中包含最终的图像
	CGColorSpaceRelease(colorSpace);
	if(context==0)
	{
		free(pData);
		return nil;
	}
	
	//复制（缩放）原图
	CGRect rect = CGRectMake(0, reflectionHeight, width, height);
	CGContextDrawImage(context, rect, originImage.CGImage);
	
	//绘制倒影
	//pData存储的象素数据是从上到下，往左往右依次存储各象素颜色
	int ySrc = height-1;
	int yDest = height;
	for(;yDest<heightWithReflection;yDest++,ySrc--)
	{
		unsigned char* pDest = pData+bytesPerRow*yDest;
		//unsigned char* pSrc = pData+bytesPerRow*ySrc;
		memcpy(pDest, pData+bytesPerRow*ySrc, bytesPerRow);//复制倒影
		float alphaRatio = 0.4*((float)(heightWithReflection-yDest))/((float)reflectionHeight);
		unsigned char alpha = (unsigned char)(255*alphaRatio);
		
		for(int off=0;off<bytesPerRow;)
		{//设置倒影的Alpha
			pDest[off++]	*=alphaRatio;//= (unsigned char)(pSrc[off]*alphaRatio);//R
			pDest[off++]	*=alphaRatio;//= (unsigned char)(pSrc[off]*alphaRatio);//G
			pDest[off++]	*=alphaRatio;//= (unsigned char)(pSrc[off]*alphaRatio);//B
			pDest[off++] = alpha;//A
		}
	}
	
	CGImageRef imgRef = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(pData);
	if(imgRef==nil)
		return nil;
	UIImage* img = [[UIImage alloc] initWithCGImage:imgRef];
	CGImageRelease(imgRef);
	return img;
}

+ (UIImage*)allocMemoryImageFromImage:(UIImage*)imgFromFile	//imgFromFile是从文件中得到的图像，它可以并没有把数据全部加入内存。
{
 	if(imgFromFile==nil)
		return nil;

	CGSize size = imgFromFile.size;
	int width = size.width;
	int height = size.height;
	int bytesPerRow = width*4;
	
	unsigned char* pData = malloc(bytesPerRow*height);//创建图像的内存
	if(pData==0)
		return nil;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pData,
													width,
													height,
													8,
													bytesPerRow,
													colorSpace,
													kCGImageAlphaPremultipliedLast);//创建context，其中包含最终的图像
	CGColorSpaceRelease(colorSpace);
	if(context==0)
	{
		free(pData);
		return nil;
	}
	
	//复制（缩放）原图
	CGRect rect = CGRectMake(0, 0, width, height);
	CGContextDrawImage(context, rect, imgFromFile.CGImage);
	
	CGImageRef imgRef = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(pData);
	if(imgRef==nil)
		return nil;
	UIImage* img = [[UIImage alloc] initWithCGImage:imgRef];
	CGImageRelease(imgRef);
	return img;
}

+(void) drawImage:(CGImageRef)imgRef imgSize:(CGSize)imgSize withRotateAngle:(float)angle onContext:(CGContextRef)context inRect:(CGRect)inRect//angle正负180度之间，逆时针为正
{
	if(imgRef==nil || context==NULL || angle>180 || angle <-180 || imgSize.width<=0 || imgSize.height<=0)
		return;
	CGContextSaveGState(context);
	
	float widthframe = inRect.size.width;
	float heightframe = inRect.size.height;
	
	float unitWidth = imgSize.width;
	float unitHeight= imgSize.height;
	
	float angle2 = atanf( ((float)unitHeight) / ((float)unitWidth) )+radians(angle);
	float l	 = sqrtf(unitWidth*unitWidth+unitHeight*unitHeight)/2;
	float x1 = l*cosf(angle2);
	float y1 = l*sinf(angle2);
	float deltaX = inRect.origin.x+ widthframe/2-x1;
	float deltaY = inRect.origin.y+ heightframe/2-y1;
	CGContextTranslateCTM(context, deltaX, deltaY);
	CGContextRotateCTM(context, radians(angle));
	
	CGRect rect = CGRectMake(0, 0, unitWidth, unitHeight);
	//CGContextAddRect(context, rect);
	//CGContextSetLineWidth(context, 1);
	//CGContextSetRGBFillColor(context, 1, 1, 1, 1);
	//CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
	//CGContextFillPath(context);
	//CGContextStrokePath(context);
	CGContextDrawImage(context, rect, imgRef);
	
	CGContextRestoreGState(context);
}

+(void) drawRectWithSize:(CGSize)rectSize withRotateAngle:(float)angle onContext:(CGContextRef)context inRect:(CGRect)inRect drawMode:(CGPathDrawingMode)drawMode//angle正负180度之间，逆时针为正
{
	if(context==NULL || angle>180 || angle <-180)
		return;
	CGContextSaveGState(context);
	
	float widthframe = inRect.size.width;
	float heightframe = inRect.size.height;
	
	float unitWidth = rectSize.width;
	float unitHeight= rectSize.height;
	
	float angle2 = atanf( ((float)unitHeight) / ((float)unitWidth) )+radians(angle);
	float l	 = sqrtf(unitWidth*unitWidth+unitHeight*unitHeight)/2;
	float x1 = l*cosf(angle2);
	float y1 = l*sinf(angle2);
	float deltaX = inRect.origin.x+ widthframe/2-x1;
	float deltaY = inRect.origin.y+ heightframe/2-y1;
	CGContextTranslateCTM(context, deltaX, deltaY);
	CGContextRotateCTM(context, radians(angle));
	
	CGRect rect = CGRectMake(0, 0, unitWidth, unitHeight);
	CGContextAddRect(context, rect);
	CGContextDrawPath(context, drawMode);
	
	CGContextRestoreGState(context);
}

+(void) drawRectShadow:(CGRect)shadowRect	//屏幕坐标系
		  imageRGBData:(void*)pData	//颜色模型kCGImageAlphaPremultipliedLast(RGBA)
			 imageSize:(CGSize)imgSize
		  shadowRadius:(float)shadowRadius	//单位象素
		  shadowRation:(float)shadowRation	//阴影系数(0,1]
		shadowColorRed:(unsigned char)red
	  shadowColorGreen:(unsigned char)green
	   shadowColorBlue:(unsigned char)blue
{
	if(pData==0 || shadowRadius<0 || shadowRect.size.width<0 || shadowRect.size.height<0
	   || imgSize.width<0 || imgSize.height<0 || shadowRation<=0 || shadowRation>1)
		return;
	
	//屏幕坐标系转为bmp坐标系
	shadowRect.origin.y = imgSize.height-(shadowRect.origin.y+shadowRect.size.height);
	
	unsigned char*	p = (unsigned char*)pData;
	int bytesPerRow = imgSize.width*4;
	int shdwWidth = (int)(shadowRadius+0.9);
	int xStart = shadowRect.origin.x;
	int yStart = shadowRect.origin.y;
	int xEnd = xStart + shadowRect.size.width;
	int yEnd = yStart + shadowRect.size.height;
	for(int dy = 1,y = yStart;dy<=shdwWidth;dy++)	//上边框
	{
		int pixelY = y-dy;
		if(pixelY<0 || pixelY>=imgSize.height)
			continue;
		float alphaY = ((shadowRadius+1.0-dy)/(shadowRadius+1.0))*shadowRation;
		unsigned char blueValue = blue*alphaY;
		unsigned char greenValue= green*alphaY;
		unsigned char redValue = red*alphaY;
		unsigned char alphaValue = alphaY*255;
		int offset = pixelY*bytesPerRow+(xStart-shdwWidth)*4;
		for(int x = xStart-shdwWidth;x<xEnd+shdwWidth;x++,offset+=4)
		{
			if(x<0 || x>=imgSize.width)
				continue;
			if(x<xStart || x>=xEnd)//相对于矩形的角
			{
				float delta;
				if(x<xStart)
					delta = sqrtf((float)(dy*dy+(xStart-x)*(xStart-x)));
				else
					delta = sqrtf((float)(dy*dy+(xEnd-1-x)*(xEnd-1-x)));
				if(delta>=shadowRadius+1)
					continue;
				float alpha = ((shadowRadius+1.0-delta)/(shadowRadius+1.0))*shadowRation;
				p[offset] = red*alpha;
				p[offset+1] = green*alpha;
				p[offset+2] = blue*alpha;
				p[offset+3] = alpha*255;
			}
			else
			{
				p[offset] = redValue;
				p[offset+1] = greenValue;
				p[offset+2] = blueValue;
				p[offset+3] = alphaValue;
			}
		}
	}
	for(int dy = 1,y = yEnd-1;dy<=shdwWidth;dy++)	//下边框
	{
		int pixelY = y+dy;
		if(pixelY<0 || pixelY>=imgSize.height)
			continue;
		float alphaY = ((shadowRadius+1.0-dy)/(shadowRadius+1.0))*shadowRation;
		unsigned char blueValue = blue*alphaY;
		unsigned char greenValue= green*alphaY;
		unsigned char redValue = red*alphaY;
		unsigned char alphaValue = alphaY*255;
		int offset = pixelY*bytesPerRow+(xStart-shdwWidth)*4;
		for(int x = xStart-shdwWidth;x<xEnd+shdwWidth;x++,offset+=4)
		{
			if(x<0 || x>=imgSize.width)
				continue;
			if(x<xStart || x>=xEnd)//相对于矩形的角
			{
				float delta;
				if(x<xStart)
					delta = sqrtf((float)(dy*dy+(xStart-x)*(xStart-x)));
				else
					delta = sqrtf((float)(dy*dy+(xEnd-1-x)*(xEnd-1-x)));
				if(delta>=shadowRadius+1)
					continue;
				float alpha = ((shadowRadius+1.0-delta)/(shadowRadius+1.0))*shadowRation;
				p[offset] = red*alpha;
				p[offset+1] = green*alpha;
				p[offset+2] = blue*alpha;
				p[offset+3] = alpha*255;
			}
			else
			{
				p[offset] = redValue;
				p[offset+1] = greenValue;
				p[offset+2] = blueValue;
				p[offset+3] = alphaValue;
			}
		}//end for x
	}//end for y
	for(int dx = 1,x = xStart;dx<=shdwWidth;dx++)	//下边框
	{
		int pixelX= x-dx;
		if(pixelX<0 || pixelX>=imgSize.width)
			continue;
		float alphaX = ((shadowRadius+1.0-dx)/(shadowRadius+1.0))*shadowRation;
		unsigned char blueValue = blue*alphaX;
		unsigned char greenValue= green*alphaX;
		unsigned char redValue = red*alphaX;
		unsigned char alphaValue = alphaX*255;
		int offset = yStart*bytesPerRow+pixelX*4;
		for(int y = yStart;y<yEnd;y++,offset+=bytesPerRow)
		{
			if(y<0 || y>=imgSize.height)
				continue;
			p[offset] = redValue;
			p[offset+1] = greenValue;
			p[offset+2] = blueValue;
			p[offset+3] = alphaValue;
		}//end for y
	}//end for x
	for(int dx = 1,x = xEnd-1;dx<=shdwWidth;dx++)	//下边框
	{
		int pixelX= x+dx;
		if(pixelX<0 || pixelX>=imgSize.width)
			continue;
		float alphaX = ((shadowRadius+1.0-dx)/(shadowRadius+1.0))*shadowRation;
		unsigned char blueValue = blue*alphaX;
		unsigned char greenValue= green*alphaX;
		unsigned char redValue = red*alphaX;
		unsigned char alphaValue = alphaX*255;
		int offset = yStart*bytesPerRow+pixelX*4;
		for(int y = yStart;y<yEnd;y++,offset+=bytesPerRow)
		{
			if(y<0 || y>=imgSize.height)
				continue;
			p[offset] = redValue;
			p[offset+1] = greenValue;
			p[offset+2] = blueValue;
			p[offset+3] = alphaValue;
		}//end for y
	}//end for x
}

+ (UIImage*)allocStackImageFromImage:(UIImage*)image shadowRadius:(float)shadowRadius
{
	if(image==nil)
		return nil;
	if(shadowRadius<=0)
		return nil;
	CGSize unitSize = image.size;
	int unitWidth = unitSize.width;
	int unitHeight = unitSize.height;
	
	int width = unitSize.width*1.414+shadowRadius*2;
	int height = unitSize.height*1.414+shadowRadius*2;
	width = (width+1)&0xfffffffe;
	height = (height+1)&0xfffffffe;
	if(width>height)
		height = width;
	else
		width = height;
	CGSize size = CGSizeMake(width, height);
	int bytesPerRow = width*4;
	unsigned char* pData = malloc(bytesPerRow*height);//创建图像的内存
	if(pData==0)
		return nil;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pData,
													width,
													height,
													8,
													bytesPerRow,
													colorSpace,
													kCGImageAlphaPremultipliedLast);//创建context，其中包含最终的图像
	CGColorSpaceRelease(colorSpace);
	if(context==0)
	{
		free(pData);
		return nil;
	}
	
	bzero(pData, bytesPerRow*height);
	CGRect unitRect = CGRectMake((int)((width-unitWidth)/2),(int)((height-unitHeight)/2), unitWidth, unitHeight);
	[UIImageAdjust drawRectShadow:unitRect
			imageRGBData:pData
			   imageSize:size
			shadowRadius:shadowRadius
			shadowRation:0.5
		  shadowColorRed:0
		shadowColorGreen:0
		 shadowColorBlue:0];
	CGImageRef shadowImgRef = CGBitmapContextCreateImage(context);
	
	CGContextSetRGBFillColor(context, 1, 1, 1, 1);
	CGContextFillRect(context, unitRect);
	CGImageRef backImgRef = CGBitmapContextCreateImage(context);
	
	bzero(pData, bytesPerRow*height);
	[UIImageAdjust drawImage:backImgRef
			imgSize:CGSizeMake(width, height)
	withRotateAngle:45
		  onContext:context
			 inRect:CGRectMake(0, 0, width, height)];
	[UIImageAdjust drawImage:backImgRef
			imgSize:CGSizeMake(width, height)
	withRotateAngle:-25
		  onContext:context
			 inRect:CGRectMake(0, 0, width, height)];
	CGImageRelease(backImgRef);
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), shadowImgRef);
	CGImageRelease(shadowImgRef);
	CGContextDrawImage(context, unitRect, image.CGImage);
	//memset(pData,255,bytesPerRow*height);
	
	//CGContextSetLineWidth(context, 1);
	//CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
	//CGContextStrokeRect(context, CGRectMake(0, 0, width, height));
	
	/*[self drawRectWithSize:CGSizeMake(width/1.414, height/1.414)
	 withRotateAngle:45
	 onContext:context
	 inRect:CGRectMake(0, 0, width, height)
	 drawMode:kCGPathFillStroke];*/
	
	CGImageRef imgRef = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(pData);
	if(imgRef==nil)
		return nil;
	UIImage* img = [[UIImage alloc] initWithCGImage:imgRef];
	CGImageRelease(imgRef);
	return img;
	
}

+ (UIImage*)allocRoundedButtonImageWithSize:(CGSize)size
								   redColor:(CGFloat)redColor
								 greenColor:(CGFloat)greenColor
								  blueColor:(CGFloat)blueColor
									  alpha:(CGFloat)alpha
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	CGFloat colors[] =
	{
		//1.0, 1.0, 1.0, 0.9,
		1.0, 1.0, 1.0, 0.5,
		1.0, 1.0, 1.0, 0.1,
		0.0, 0.0, 0.0, 0.1,
		0.0, 0.0, 0.0, 0.5,
		//0.0, 0.0, 0.0, 0.8,
	};
	CGFloat locations[] = {0.0, 0.49, 0.51, 1.0};
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, colors, locations, sizeof(colors)/(sizeof(colors[0])*4));
	
	int bytesPerRow = 4*size.width;
	void* pBuffer = malloc(bytesPerRow*size.height);
	bzero(pBuffer, bytesPerRow*size.height);
	CGContextRef context = CGBitmapContextCreate(pBuffer,
												 size.width,
												 size.height,
												 8,
												 bytesPerRow,
												 colorSpace,
												 kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(colorSpace);
	
	//背景色
	addRoundedRectToPath(context, CGRectMake(0, 0, size.width, size.height), 8, 8);
	//CGContextSetFillColor(context, CGColorGetComponents(color.CGColor));
	CGContextSetRGBFillColor(context, redColor, greenColor, blueColor, alpha);
	CGContextFillPath(context);
	
	//渐变色
	addRoundedRectToPath(context, CGRectMake(0, 0, size.width, size.height), 8, 8);
	CGContextClip(context);
	CGPoint gradientStart = CGPointMake(size.width/2, 0);
	CGPoint gradientEnd	 = CGPointMake(size.width/2, size.height);
	CGContextDrawLinearGradient(context, gradient,gradientEnd , gradientStart, 0);
	CGGradientRelease(gradient);
	
	CGImageRef imgRef = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	free(pBuffer);
	if(imgRef==nil)
		return nil;
	UIImage* img = [[UIImage alloc] initWithCGImage:imgRef];
	CGImageRelease(imgRef);
	return img;
}

@end