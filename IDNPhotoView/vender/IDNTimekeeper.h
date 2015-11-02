//
//  IDNTimekeeper.h
//  IDNPhotoView
//
//  Created by photondragon on 15/10/27.
//  Copyright © 2015年 iosdev.net. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 计时器
@interface IDNTimekeeper : NSObject

- (void)start;
- (void)end;
- (void)restart;
- (double)getElapsedTime;

#pragma mark 代码计时

- (void)codeStart;
- (void)codeEnd;
- (void)codeRestart;
- (double)getCodeElapsedTime;

@end
