#import "TouchesAssist.h"

@implementation TouchesAssist
{
	BOOL isPureSingleTouch;//纯的单指操作
	NSInteger curTouchesCount;
	CGPoint prevSinglePoint;
}
@synthesize delegate;
@synthesize isPureSingleTouch;
@synthesize curTouchesCount;
@synthesize prevSinglePoint;

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView* view = [[touches anyObject] view];
	NSSet* allTouches = [event touchesForView:view];
	NSInteger touchesCount = [allTouches count];
	if(touchesCount==1)//单指操作
	{
		isPureSingleTouch = TRUE;
		
		UITouch* touch = [touches anyObject];
		CGPoint location = [touch locationInView: view];
		
		//*****************单指操作开始******************
		curTouchesCount = 1;
		[delegate touchesAssistSingleTouchBegan:location];
		prevSinglePoint = location;
	}
	else if(touchesCount==2)//双指操作
	{
		isPureSingleTouch = FALSE;
		
		NSArray* aTouches = [allTouches allObjects];
		UITouch *touch1 = [aTouches objectAtIndex:0];
		UITouch *touch2 = [aTouches objectAtIndex:1];
		CGPoint location1 = [touch1 locationInView: view];
		CGPoint location2 = [touch2 locationInView: view];
		
		//***********************************
		if(curTouchesCount==1)
		{
			curTouchesCount = 2;
			[delegate touchesAssistSingleTouchEnded:prevSinglePoint];
		}
		curTouchesCount = 2;
		[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
	}
	else
	{
		isPureSingleTouch = FALSE;
		NSInteger prevCount = curTouchesCount;
		curTouchesCount = touchesCount;
		if(prevCount==1)
			[delegate touchesAssistSingleTouchEnded:prevSinglePoint];
		else if(prevCount==2)
			[delegate touchesAssistDoubleTouchEnded];
	}
}
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView* view = [[touches anyObject] view];
	NSSet* allTouches = [event touchesForView:view];
	NSInteger touchesCount = [allTouches count];
	if(touchesCount==1)
	{
		UITouch* touch = [touches anyObject];
		CGPoint location = [touch locationInView: view];
		[delegate touchesAssistSingleTouchMoved:location];
		prevSinglePoint = location;
	}
	else if(touchesCount==2)
	{
		NSArray* aTouches = [allTouches allObjects];
		UITouch *touch1 = [aTouches objectAtIndex:0];
		UITouch *touch2 = [aTouches objectAtIndex:1];
		CGPoint location1 = [touch1 locationInView: view];
		CGPoint location2 = [touch2 locationInView: view];
		[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView* view = [[touches anyObject] view];
	NSSet* allTouches = [event touchesForView:view];
	NSInteger touchesCount = [allTouches count];
	NSInteger reducedCount = [touches count];
	NSInteger leftCount = touchesCount - reducedCount;//屏幕上还剩的手指个数
	
	if(leftCount==0)//没有Touch了
	{
		if(touchesCount==1)//单指操作结束
		{
			NSAssert(touchesCount==curTouchesCount,@"touchesCount!=curTouchesCount");
			UITouch* touch = [touches anyObject];
			CGPoint location = [touch locationInView: view];
			curTouchesCount = 0;
			[delegate touchesAssistSingleTouchEnded:location];
			prevSinglePoint = location;
		}
		else if(touchesCount==2)//双指操作结束
		{
			NSAssert(touchesCount==curTouchesCount,@"touchesCount!=curTouchesCount");
			NSArray* aTouches = [allTouches allObjects];
			UITouch *touch1 = [aTouches objectAtIndex:0];
			UITouch *touch2 = [aTouches objectAtIndex:1];
			CGPoint location1 = [touch1 locationInView: view];
			CGPoint location2 = [touch2 locationInView: view];
			[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
			curTouchesCount = 0;
			[delegate touchesAssistDoubleTouchEnded];
		}
		else
			curTouchesCount = 0;
	}
	else if(leftCount==1)//屏幕上的还有1个手指
	{
		NSArray* aTouches = [allTouches allObjects];
		if(curTouchesCount==2)
		{
			UITouch *touch1 = [aTouches objectAtIndex:0];
			UITouch *touch2 = [aTouches objectAtIndex:1];
			CGPoint location1 = [touch1 locationInView: view];
			CGPoint location2 = [touch2 locationInView: view];
			[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
			curTouchesCount = 1;
			[delegate touchesAssistDoubleTouchEnded];
		}
		else
			curTouchesCount = 1;
		for(UITouch* touch in aTouches)
		{
			if([touches containsObject:touch]==FALSE)
			{
				CGPoint location = [touch locationInView:view];
				[delegate touchesAssistSingleTouchBegan:location];
				prevSinglePoint = location;
				break;
			}
		}
	}
	else if(leftCount==2)//屏幕上的还有2个手指
	{
		int finded = 0;
		UITouch *touch1 = nil;
		UITouch *touch2 = nil;
		//查找还留在屏幕上的两个手指对应的touch
		for(UITouch* touch in allTouches)
		{
			if([touches containsObject:touch]==FALSE)
			{
				finded++;
				if(finded==1)
					touch1 = touch;
				else if(finded==2)
				{
					touch2 = touch;
					break;
				}
			}
		}
		UIView* view = [touch1 view];
		CGPoint location1 = [touch1 locationInView: view];
		CGPoint location2 = [touch2 locationInView: view];
		
		curTouchesCount = 2;
		[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
	}
	else// if(leftCount>2)
	{
		NSAssert(curTouchesCount>2,@"curTouchesCount<=2");
		curTouchesCount = leftCount;
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView* view = [[touches anyObject] view];
	NSSet* allTouches = [event touchesForView:view];
	NSInteger touchesCount = [allTouches count];
	NSInteger reducedCount = [touches count];
	NSAssert(touchesCount==reducedCount,@"Cancelled count isn't equal touches count!");
	if(touchesCount==1)//单指操作结束
	{
		NSAssert(touchesCount==curTouchesCount,@"touchesCount!=curTouchesCount");
		UITouch* touch = [touches anyObject];
		CGPoint location = [touch locationInView: view];
		curTouchesCount = 0;
		[delegate touchesAssistSingleTouchCancelled:location];
		prevSinglePoint = location;
	}
	else if(touchesCount==2)//双指操作结束
	{
		NSAssert(touchesCount==curTouchesCount,@"touchesCount!=curTouchesCount");
		NSArray* aTouches = [allTouches allObjects];
		UITouch *touch1 = [aTouches objectAtIndex:0];
		UITouch *touch2 = [aTouches objectAtIndex:1];
		CGPoint location1 = [touch1 locationInView: view];
		CGPoint location2 = [touch2 locationInView: view];
		[delegate touchesAssistDoubleTouchPointA:location1 touchPointB:location2];
		curTouchesCount = 0;
		[delegate touchesAssistDoubleTouchEnded];
	}
	else
		curTouchesCount = 0;
}

@end

