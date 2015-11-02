#import <UIKit/UIKit.h>
#import "XLoader.h"
#import "TouchAssistant.h"
#import "TouchesAssist.h"

@protocol PhotoBrowserViewDelegate<NSObject>
@optional
-(void) photoBrowseViewSelectedByIndex:(int)index;	//当前正在显示第index张图片
-(void) photoBrowseViewClicked;
@end

@protocol PhotoBrowserViewSource<NSObject>
-(int) getPhotosCount;
-(NSString*) getPhotoPathByIndex:(int)index;	//获取第index张图片的路径
@end

@interface PhotoBrowserView : UIView
<UIScrollViewDelegate,XLoaderDelegate,
TouchesAssistDelegate>

@property (retain,nonatomic) IBOutlet id<PhotoBrowserViewDelegate> delegate;
@property (retain,nonatomic) id<PhotoBrowserViewSource>	source;
///线程安全
-(void) setSource:(id<PhotoBrowserViewSource>)aSource;
///线程安全
-(void) setCurrentPhotoByIndex:(int)index;
@end
