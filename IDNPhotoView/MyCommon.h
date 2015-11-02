//
//  MyCommon.h
//  ImagePreviewer
//
//  Created by mahongjian on 14-7-11.
//
//

#import <Foundation/Foundation.h>
#import "ImageCollector.h"

@interface MyCommon : NSObject
{
	
}
+(ImageCollector*) imageCollector;
+(ImageCollector*) refreshedImageCollector;
@end
