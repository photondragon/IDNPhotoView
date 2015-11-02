//
//  PhotoController.m
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import "PhotoController.h"
#import "MyCommon.h"

@interface PhotoController ()
@property (nonatomic,strong) PhotoBrowserView* photoBrower;
@end

@implementation PhotoController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];
	self.view.clipsToBounds = YES;

	_photoBrower = [[PhotoBrowserView alloc] initWithFrame:self.view.bounds];
	_photoBrower.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_photoBrower];
	[self.photoBrower setSource:[MyCommon imageCollector]];
	if(currentIndex>0)
		[self.photoBrower setCurrentPhotoByIndex:currentIndex];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
	return TRUE;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

-(void)setCurrentPhotoByIndex:(int)index
{
	currentIndex = index;
	[self.photoBrower setCurrentPhotoByIndex:index];
}

#pragma mark PhotoBrowserViewDelegate

-(void) photoBrowseViewSelectedByIndex:(int)index	//当前正在显示第index张图片
{

}
-(void) photoBrowseViewClicked
{
	if(self.navigationController.navigationBarHidden)
		self.navigationController.navigationBarHidden = false;
	else
		self.navigationController.navigationBarHidden = TRUE;
}

@end
