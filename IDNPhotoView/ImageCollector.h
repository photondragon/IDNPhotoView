//
//  ImageCollector.h
//  ImagePreviewer
//
//  Created by mahj on 5/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IDNBreviaryView.h"
#import "PhotoBrowserView.h"

@interface ImageCollector : NSObject
<IDNBreviaryViewSource,
PhotoBrowserViewSource>
{
	NSMutableArray* arrayImageNames;
}

@end
