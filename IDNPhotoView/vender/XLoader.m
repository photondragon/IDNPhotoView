/** @file XLoader.m
 内部使用NSOperationQueue来实现多线程操作
 */

#import "XLoader.h"

/// 仅供内部使用
@interface XLoaderUnitHidden:NSObject
{
	id	key;
	id<XUnitProtocol>	unit;
	BOOL	isRemoved;
}
@property (nonatomic,strong) id	key;
@property (nonatomic,strong) id<XUnitProtocol>	unit;
@property (nonatomic) BOOL isRemoved;	//如果此值为TRUE，则表示已经卸载了这个对象。相当于已经针对这个对象调用了unloadObject:
@end
@implementation XLoaderUnitHidden
@synthesize key;
@synthesize unit;
@synthesize isRemoved;

@end

@interface XLoader(hidden)
+(NSOperationQueue*) xLoaderTaskQueue;
-(void) taskLoadObject:(XLoaderUnitHidden*)loaderUnitHidden;
-(void) objectLoaded:(XLoaderUnitHidden*)loaderUnitHidden;
-(void) loadFailed:(XLoaderUnitHidden*)loaderUnitHidden;
@end

static NSOperationQueue* g_xLoaderTaskQueue = nil;
@implementation XLoader(hidden)

+(NSOperationQueue*) xLoaderTaskQueue
{
	if(g_xLoaderTaskQueue==nil)
		g_xLoaderTaskQueue = [[NSOperationQueue alloc] init];
	return g_xLoaderTaskQueue;
}
-(void) taskLoadObject:(XLoaderUnitHidden *)loaderUnitHidden
{
	id key;
	[locker lock];
	if(loaderUnitHidden.isRemoved)
	{
		[locker unlock];
		return;
	}
	key = loaderUnitHidden.key;
	[locker unlock];
	BOOL success = [loaderUnitHidden.unit loadUnitForKey:key];
	[locker lock];
	if(loaderUnitHidden.isRemoved)
	{
		[locker unlock];
		return;
	}
	if(success==TRUE)
		[self performSelectorOnMainThread:@selector(objectLoaded:) withObject:loaderUnitHidden waitUntilDone:NO];
	else
		[self performSelectorOnMainThread:@selector(loadFailed:) withObject:loaderUnitHidden waitUntilDone:NO];
	[locker unlock];
}
-(void) objectLoaded:(XLoaderUnitHidden*)loaderUnitHidden
{
	[locker lock];
	if(loaderUnitHidden.isRemoved)
	{
		[locker unlock];
		return;
	}
	[dicObjects removeObjectForKey:loaderUnitHidden.key];
	[locker unlock];
	if([delegate respondsToSelector:@selector(xLoader:loadedObject:forKey:)])
		[delegate xLoader:self loadedObject:loaderUnitHidden.unit forKey:loaderUnitHidden.key];
}
-(void) loadFailed:(XLoaderUnitHidden*)loaderUnitHidden;
{
	[locker lock];
	if(loaderUnitHidden.isRemoved)
	{
		[locker unlock];
		return;
	}
	[dicObjects removeObjectForKey:loaderUnitHidden.key];
	[locker unlock];
	if([delegate respondsToSelector:@selector(xLoader:loadObjectFailedForKey:)])
		[delegate xLoader:self loadObjectFailedForKey:loaderUnitHidden.key];
}

@end

@implementation XLoader
@synthesize delegate;

-(id) init
{
	if((self = [super init]))
	{
		locker = [[NSLock alloc] init];
		dicObjects = [[NSMutableDictionary alloc] init];
	}
	return self;
}

-(void) loadObject:(id<XUnitProtocol>)loaderUnit forKey:(id)key
{
	if(key==nil || loaderUnit==nil)
		return;
	XLoaderUnitHidden* loaderUnitHidden = [[XLoaderUnitHidden alloc] init];
	loaderUnitHidden.key = key;
	loaderUnitHidden.unit = loaderUnit;
	NSInvocationOperation* op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(taskLoadObject:) object:loaderUnitHidden];
	[locker lock];
	XLoaderUnitHidden* loaderUnitHiddenOld = [dicObjects objectForKey:key];
	if(loaderUnitHiddenOld)
		loaderUnitHiddenOld.isRemoved = TRUE;
	[dicObjects setObject:loaderUnitHidden forKey:key];
	[[XLoader xLoaderTaskQueue] addOperation:op];
	[locker unlock];
}

-(void) cancelLoadingObjectByKey:(id)keyOfObject
{
	[locker lock];
	XLoaderUnitHidden* loaderUnitHidden = [dicObjects objectForKey:keyOfObject];
	if(loaderUnitHidden)
	{
		loaderUnitHidden.isRemoved = TRUE;
		[dicObjects removeObjectForKey:keyOfObject];
	}
	[locker unlock];
}

-(void) cancelLoadingAllObjects
{
	[locker lock];
	NSEnumerator *enumerator = [dicObjects objectEnumerator];
	XLoaderUnitHidden* loaderUnitHidden;
	while ((loaderUnitHidden = [enumerator nextObject]))
	{
		loaderUnitHidden.isRemoved = TRUE;
	}
	[dicObjects removeAllObjects];
	[locker unlock];
}

@end
