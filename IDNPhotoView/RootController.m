//
//  RootController.m
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import "RootController.h"
#import "BreviaryController.h"

@interface RootController ()

@end

@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.tabBar.hidden = YES;

	BreviaryController* breviary = [[BreviaryController alloc] init];
	UINavigationController* nav1 = [[UINavigationController alloc] initWithRootViewController:breviary];
	
	self.viewControllers = @[nav1];
}

@end
