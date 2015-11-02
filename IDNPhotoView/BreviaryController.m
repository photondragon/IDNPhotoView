//
//  BreviaryController.m
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import "BreviaryController.h"
#import "MyCommon.h"
#import "PhotoController.h"

@interface BreviaryController ()
@property (nonatomic,strong) IDNBreviaryView* breviaryView;
@end

@implementation BreviaryController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];

	self.title = @"图片";

	_breviaryView = [[IDNBreviaryView alloc] initWithFrame:self.view.bounds];
	_breviaryView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_breviaryView];
	
	[_breviaryView setSource:[MyCommon imageCollector]];
	[_breviaryView setDelegate:self];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(onBtnRefreshClicked:)];
}

-(void)onBtnRefreshClicked:(id)sender
{
	[self.breviaryView setSource:[MyCommon refreshedImageCollector]];
}

- (BOOL)shouldAutorotate
{
	return TRUE;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark IDNBreviaryViewDelegate

-(void) breviaryViewImageClicked:(NSInteger)index
{
	NSLog(@"index=%ld",(long)index);
	PhotoController* c = [[PhotoController alloc] init];
	[c setCurrentPhotoByIndex:index];
	[self.navigationController pushViewController:c animated:YES];
}

@end
