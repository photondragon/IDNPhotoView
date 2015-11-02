/** @file TouchAssistant.h
 */
#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// TouchAssistant触摸类型
typedef NS_ENUM(int)
{
	ETouchAssistantType_None=0,	///< 未移动，这是初始状态，在touchEnded或touchCancelled时不会有此状态
	ETouchAssistantType_Moving,	///< 移动中
	ETouchAssistantType_Tap,	///< 点击
	ETouchAssistantType_Moved,	///< 移动了
	ETouchAssistantType_SwipeH,	///< 轻扫（水平方向）
	ETouchAssistantType_SwipeV,	///< 轻扫（垂直方向）
	ETouchAssistantType_Error,	///< 只有在错误调用时才会返回此值，比如没有调用touchBeganAtPoint就调用touchMovedAtPoint或touchEndedAtPoint。
}ETouchAssistantType;

/// Touch助手
/** 判断当前Touch操作的类型（点击、移动或是轻扫），只适用于单指操作 */
@interface TouchAssistant : NSObject
{
	BOOL	isTouching;
	BOOL	isTouchMoved;	//在MovingStart后是否收到touchMoved触摸事件
	ETouchAssistantType	touchType;
	//position
	CGPoint	touchBeganPoint;
	CGPoint	touchPoint;	// 最新一次Touch的位置
	CGPoint	offset;	//最近一次Touch的产生的偏移量
	CGPoint	totalOffset;
	//time
	NSTimeInterval	touchBeganTime;
	NSTimeInterval	moveStartTime;
	NSTimeInterval	touchTime;	//最近一次Touch时间点
	NSTimeInterval	deltaTime;	//最近两次Touch的时间间隔。
	NSTimeInterval	touchDuration;
	
//	float	maxDeltaX;	//当前Touch的最大移动量X
//	float	maxDeltaY;	//当前Touch的最大移动量Y
	
	NSTimeInterval	tapTime;	//最近一次Tap的时间点
	CGPoint	tapPoint;	//最近一次Tap的位置
	int		tapsCount;	//连续点击次数（2表示双击）
	
	struct SamplePoint
	{
		CGPoint point;
		CGPoint offset;	//相对于上个点的偏移量
		NSTimeInterval	time;
	}samplePoints[4];	//采样用于计算速度。一次轻扫大概是3-5个touch点，所以这里速度采样点设为4个
	int		samplesCount;	//采样个数
}
@property (nonatomic,readonly) BOOL isTouching;
///当前Touch的移动速度
@property (nonatomic,readonly) CGPoint touchVelocity;
/// 连续点击次数（2表示双击）
/**
 当操作为ETouchAssistantType_Tap时，tapsCount可能是任意正整数，
 */
@property (nonatomic,readonly) int	tapsCount;
/// Touch起始位置
@property (nonatomic,readonly) CGPoint touchBeganPoint;
/// 最近一次Touch的位置
@property (nonatomic,readonly) CGPoint touchPoint;
/// 最近一次Touch的产生的偏移量
@property (nonatomic,readonly) CGPoint	offset;
/// Touch的总偏移量（相对于TouchBegan）
@property (nonatomic,readonly) CGPoint	totalOffset;
///touch开始时间。
@property (nonatomic,readonly) NSTimeInterval	touchBeganTime;
///最近一个Touch(Began/Moved/Ended)时间。
@property (nonatomic,readonly) NSTimeInterval	touchTime;
///最近两次Touch的时间间隔。
@property (nonatomic,readonly) NSTimeInterval	deltaTime;
///touch持续时间。
@property (nonatomic,readonly) NSTimeInterval	touchDuration;

/// 当TouchBegan时调用，告知Touch助手触摸开始了
/** @param point 触摸开始的点 */
-(void) touchBeganAtPoint:(CGPoint)point;
/// 当TouchMoved时调用，告知Touch助手最新的触摸点
/** @param point 新的触摸点
 @return 返回触摸类型，ETouchAssistantType_None或ETouchAssistantType_Moving */
-(ETouchAssistantType) touchMovedToPoint:(CGPoint)point;
/// 当TouchMoved时调用，告知Touch助手触摸结束
/** @param point 触摸结束点
 @return 返回触摸类型，ETouchAssistantType_Tap或ETouchAssistantType_Moved或ETouchAssistantType_Swipe */
-(ETouchAssistantType) touchEndedAtPoint:(CGPoint)point;
@end
