/** @file XLoader.h
 */

#import <Foundation/Foundation.h>

@protocol XUnitProtocol <NSObject>
-(BOOL) loadUnitForKey:(id)key;
@end

@protocol XLoaderDelegate;

/// 异步对象加载器
/** 加载过程都是在非主线程中进行的，通知方法都是在主线程中执行的 */
@interface XLoader : NSObject
{
	NSLock*	locker;
	NSMutableDictionary* dicObjects;
	NSObject<XLoaderDelegate>* delegate;
}
/// XLoader委托对象
@property (nonatomic,retain) NSObject<XLoaderDelegate>* delegate;
/// 加载一个对象
/** 对象的加载工作会在后台线程中进行，当加载完成后，XLoader会通知委托对象
 @param loaderUnit 加载单元，一个XLoaderUnit子类的实例，其loadAndRetain方法实现了对象的加载 */
-(void) loadObject:(id<XUnitProtocol>)loaderUnit forKey:(id)key;
/// 取消加载一个对象
/** 取消加载一个尚未加载完的对象。被取消的对象是不会触发委托方法的。
 @param keyOfObject 对象的Key
 */
-(void) cancelLoadingObjectByKey:(id)keyOfObject;
/// 取消加载所有尚未加载完的对象。被取消的对象是不会触发委托方法的。
-(void) cancelLoadingAllObjects;
@end

/// XLoader委托协议
/** 因为多线程的原因，委托方法不使用“推”，而应由被通知者使用“拉”的方式获取加载的对象，
 即调用[loader objectForKey:keyObj]来获取实际加载的对象 */
@protocol XLoaderDelegate<NSObject>
/// 通知委托对象对象已加载
/** 此方法总是在主线程中被调用
 @param keyObj 已加载对象的key */
@optional
-(void) xLoader:(XLoader*)loader loadedObject:(id<XUnitProtocol>)object forKey:(id)keyObj;
-(void) xLoader:(XLoader*)loader loadObjectFailedForKey:(id)keyObj;
@end


