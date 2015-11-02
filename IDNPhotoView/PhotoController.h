//
//  PhotoController.h
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import <UIKit/UIKit.h>
#import "PhotoBrowserView.h"

@interface PhotoController : UIViewController
<PhotoBrowserViewDelegate>
{
	int currentIndex;
}
-(void)setCurrentPhotoByIndex:(int)index;
@end
