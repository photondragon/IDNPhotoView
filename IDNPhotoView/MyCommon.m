//
//  MyCommon.m
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import "MyCommon.h"

static ImageCollector* g_oImageCollector = nil;
@implementation MyCommon
+(void) initialize
{
	if(g_oImageCollector==nil)
	{
		@synchronized(g_oImageCollector)
		{
			if(g_oImageCollector==nil)
			{
				g_oImageCollector = [[ImageCollector alloc] init];
			}
		}
	}
}

+(ImageCollector*) imageCollector
{
	if(g_oImageCollector==nil)
		[self initialize];
	return g_oImageCollector;
}

+(ImageCollector*) refreshedImageCollector
{
	if(g_oImageCollector==nil)
		[self initialize];
	g_oImageCollector = [[ImageCollector alloc] init];
	return g_oImageCollector;
}

@end
