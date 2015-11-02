#import <UIKit/UIKit.h>

@protocol IDNBreviaryViewSource;
@protocol IDNBreviaryViewDelegate;

///缩略图控件
@interface IDNBreviaryView : UIView

@property(nonatomic,weak) id<IDNBreviaryViewDelegate> delegate;
- (void)setSource:(id<IDNBreviaryViewSource>)aSource;

@end

@protocol IDNBreviaryViewSource<NSObject>

@required
- (int)breviaryViewGetCount;
- (NSString*)breviaryViewGetImagePathByIndex:(NSInteger)index name:(NSString**)name subsCount:(int*)subsCount;	//subsCount返回－1表示这是张图片，大于等于0表示这是个目录

@end

@protocol IDNBreviaryViewDelegate<NSObject>

@optional
- (void)breviaryViewImageClicked:(NSInteger)index;

@end
