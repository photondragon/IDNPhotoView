#import <UIKit/UIKit.h>

@protocol TouchesAssistDelegate;

/// 不可与UIGestureRecognizer混用，否则后果自负（UIGestureRecognizer可能会改变Touches的行为）
@interface TouchesAssist : NSObject

@property (nonatomic,weak) id<TouchesAssistDelegate> delegate;
@property (nonatomic) BOOL	isPureSingleTouch;
@property (nonatomic,readonly) NSInteger curTouchesCount;
@property (nonatomic,readonly) CGPoint	prevSinglePoint;

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@protocol TouchesAssistDelegate <NSObject>
-(void) touchesAssistSingleTouchBegan:(CGPoint)point;
-(void) touchesAssistSingleTouchMoved:(CGPoint)point;
-(void) touchesAssistSingleTouchEnded:(CGPoint)point;
-(void) touchesAssistSingleTouchCancelled:(CGPoint)point;
-(void) touchesAssistDoubleTouchPointA:(CGPoint)pointA touchPointB:(CGPoint)pointB;
-(void) touchesAssistDoubleTouchEnded;
@end

