/** @file TouchAssistant.m
 */

#import "TouchAssistant.h"

#define TouchAssistantMinMoveDistance	8.0f
#define TouchAssistantTwoTapsDistance2	400.0f	//
#define TouchAssistantMaxSwipeDuration	0.2
#define TouchAssistantMinSwipeSpeed2	1048576.0//速度1024像素/秒
#define TouchAssistantMinSwipeLength	32.0f
#define TouchAssistantMaxTapDuration	0.29f
@implementation TouchAssistant
@synthesize isTouching;
@synthesize tapsCount;
@synthesize touchBeganPoint;
@synthesize touchPoint;
@synthesize offset;
@synthesize totalOffset;
@synthesize touchBeganTime;
@synthesize touchTime;
@synthesize deltaTime;
@synthesize touchDuration;

-(void) addSamplePoint:(CGPoint)point
{
	NSAssert(samplesCount>0,@"[TouchAssistant addSamplePoint:] you should not see this");
	CGPoint curOff;
	curOff.x = samplePoints[samplesCount-1].point.x - point.x;
	curOff.y = samplePoints[samplesCount-1].point.y - point.y;
	if(deltaTime>0.1)//touch有停顿
		samplesCount = 0;
	else
	{
		float dotProduct = samplePoints[samplesCount-1].offset.x*curOff.x
		+samplePoints[samplesCount-1].offset.y*curOff.y;//点积
		if(dotProduct<0)//方向相反
		{
			samplesCount = 0;
			//NSLog(@"opposit");
		}
	}
		
	if(samplesCount==4)
	{
		for (int i=0; i<3; i++)
			samplePoints[i] = samplePoints[i+1];
		samplesCount = 3;
	}
	samplePoints[samplesCount].point = point;
	samplePoints[samplesCount].offset = curOff;
	samplePoints[samplesCount].time = touchTime;
	samplesCount++;
}

-(void) touchBeganAtPoint:(CGPoint)point
{
	isTouching = TRUE;
	isTouchMoved = FALSE;
	touchType = ETouchAssistantType_None;
	touchBeganPoint = point;
	touchPoint = point;
	offset.x = 0;
	offset.y = 0;
	totalOffset.x = 0;
	totalOffset.y = 0;
	touchBeganTime = [NSDate timeIntervalSinceReferenceDate];
	moveStartTime = 0;
	touchTime = touchBeganTime;
	deltaTime = 0;
	touchDuration = 0;
	samplePoints[0].point = point;
	samplePoints[0].offset = CGPointZero;
	samplePoints[0].time = touchTime;
	samplesCount = 1;
}
-(ETouchAssistantType) touchMovedToPoint:(CGPoint)point
{
	if(isTouching==FALSE)
		return ETouchAssistantType_Error;
	totalOffset.x = point.x-touchBeganPoint.x;
	totalOffset.y = point.y-touchBeganPoint.y;
	offset.x = point.x - touchPoint.x;
	offset.y = point.y - touchPoint.y;
	touchPoint = point;
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	deltaTime = time-touchTime;
	touchTime = time;
	touchDuration = time-touchBeganTime;
	
	[self addSamplePoint:point];
	
	if(isTouchMoved==FALSE)
	{
		float dxAbs = totalOffset.x<0? -totalOffset.x: totalOffset.x;
		float dyAbs = totalOffset.y<0? -totalOffset.y: totalOffset.y;
		if(dxAbs>TouchAssistantMinMoveDistance || dyAbs>TouchAssistantMinMoveDistance)//8像素以内一律不算移动
		{
			isTouchMoved = TRUE;
			moveStartTime = time;	//
			//	if(touchDuration>=TouchAssistantMaxSwipeDuration)//只有确认不是Swipe才算移动
			touchType = ETouchAssistantType_Moving;
		}
	}
	return touchType;
}

-(ETouchAssistantType) touchEndedAtPoint:(CGPoint)point
{
	if(isTouching==FALSE)
		return ETouchAssistantType_Error;
	
	isTouching = FALSE;
	totalOffset.x = point.x-touchBeganPoint.x;
	totalOffset.y = point.y-touchBeganPoint.y;
	offset.x = point.x - touchPoint.x;
	offset.y = point.y - touchPoint.y;
	touchPoint = point;
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	deltaTime = time-touchTime;
	touchTime = time;
	touchDuration = time-touchBeganTime;
	
	[self addSamplePoint:point];
	
	float dxAbs = totalOffset.x<0? -totalOffset.x: totalOffset.x;
	float dyAbs = totalOffset.y<0? -totalOffset.y: totalOffset.y;
	//检测是不是Tap
	if(isTouchMoved==FALSE
	   ||(dxAbs<=TouchAssistantMinMoveDistance && dyAbs<=TouchAssistantMinMoveDistance))
	{
		int tapInc = 0;
		if(tapsCount>0)
		{
			if(time-tapTime<=TouchAssistantMaxTapDuration)
			{
				float dx = point.x-tapPoint.x;
				float dy = point.y-tapPoint.y;
				//NSLog(@"tapDuration=%2.2f,delta=%2.1f",(float)(time-prevTapTime),sqrtf(dx*dx+dy*dy));
				if(dx*dx+dy*dy<=TouchAssistantTwoTapsDistance2)
					tapInc = 1;
			}
		}
		if(tapInc)
			tapsCount++;
		else
			tapsCount=1;
		tapTime	 = time;
		tapPoint = point;
		touchType = ETouchAssistantType_Tap;
		return touchType;
	}
	tapsCount = 0;
	
	CGPoint v = self.touchVelocity;
	float vxe2 = v.x*v.x;
	float vye2 = v.y*v.y;
	//NSLog(@"speed =%4.0f",sqrtf(vxe2+vye2));
	float moveTime;
	if(isTouchMoved && touchDuration>TouchAssistantMaxSwipeDuration)
		moveTime = touchTime-moveStartTime;
	else
		moveTime = touchDuration;
	if(moveTime<TouchAssistantMaxSwipeDuration)
	{
		if(vxe2+vye2>TouchAssistantMinSwipeSpeed2)
		{
			if(vye2>vxe2)
				touchType = ETouchAssistantType_SwipeV;
			else
				touchType = ETouchAssistantType_SwipeH;
			return touchType;
		}
	}
	else
	{
		if(vxe2+vye2>TouchAssistantMinSwipeSpeed2*2)
		{
			if(vye2>vxe2)
				touchType = ETouchAssistantType_SwipeV;
			else
				touchType = ETouchAssistantType_SwipeH;
			return touchType;
		}
	}
//	if(dxAbs>TouchAssistantMinSwipeLength || dyAbs>TouchAssistantMinSwipeLength)//轻扫长度
//	{
//		if(isTouchMoved==FALSE)//
//		{//必是轻扫
//			if(dyAbs>dxAbs)
//				touchType = ETouchAssistantType_SwipeV;
//			else
//				touchType = ETouchAssistantType_SwipeH;
//			return touchType;
//		}
//		NSTimeInterval movingTime;
//		if(moveStartTime && moveStartTime-touchBeganTime<0.1)
//			movingTime = time-touchBeganTime;
//		else//按下以后过了很长时间才开始Move，所以swipe检测时间从Move时刻开始计时
//			movingTime = time-moveStartTime;
//		if(movingTime<TouchAssistantMaxSwipeDuration)
//		{
//			double speedX = dxAbs/movingTime;
//			double speedY = dyAbs/movingTime;
//			double speed2 = speedX*speedX + speedY*speedY;
//			//NSLog(@"maxDelta=%4.0f movingTime=%1.2lf speed=%5.0lf",maxDeltaX>maxDeltaY?maxDeltaX:maxDeltaY,movingTime,sqrt(speed2));
//			if(speed2>TouchAssistantMinSwipeSpeed2)
//			{//速度够快，是轻扫
//				if(dyAbs>dxAbs)
//					touchType = ETouchAssistantType_SwipeV;
//				else
//					touchType = ETouchAssistantType_SwipeH;
//				return touchType;
//			}
//		}
//	}
	touchType = ETouchAssistantType_Moved;
	return touchType;
}

-(CGPoint) touchVelocity
{
	if(samplesCount<2)
		return CGPointZero;
	float dx = samplePoints[samplesCount-1].point.x-samplePoints[0].point.x;
	float dy = samplePoints[samplesCount-1].point.y-samplePoints[0].point.y;
	float dt = samplePoints[samplesCount-1].time-samplePoints[0].time;
	return CGPointMake(dx/dt, dy/dt);
}
@end
