/** @file UIImageAdjust.h
 */
#import <UIKit/UIKit.h>

/// 提供一些操作UIImage对象的功能方法
@interface UIImageAdjust:NSObject
/// 改变图像大小
/**
 * @param newSize 新的大小
 * @param originImage 原始图像
 * @return 返回大小改变后的新图像
 */
+ (UIImage*)allocImageAndResize:(CGSize)newSize fromImage:(UIImage*)originImage;
/// 改变图像大小，并且新图像在指定Path范围以内
/** @param size 新的大小
 @param path 路径，新图像在这个范围以内
 @param originImage 原始图像
 @return 返回新图像 */
+ (UIImage*)allocImageWithNewSize:(CGSize)size withinPath:(CGPathRef)path fromImage:(UIImage*)originImage;
/// 给图像加上倒影
/** @param reflectionFraction 倒影系数，倒影与图像原始高度之比，0到1之间
 @param originImage 原始图像
 @return 返回新图像 */
+ (UIImage*)addImageReflection:(CGFloat)reflectionFraction fromImage:(UIImage*)originImage;
/// 改变图像大小，同时增加倒影
/** @param size 新的大小
 @param reflectionFraction 倒影系数，倒影与图像原始高度之比，0到1之间
 @param originImage 原始图像
 @return 返回新图像 */
+ (UIImage*)copyImageWithNewSize:(CGSize)newSize withRefletionHeightRatio:(CGFloat)ratio fromImage:(UIImage*)originImage;
/// 根据从文件中得到的图像生成一幅一样的新的BITMAP图像
/**
 * 如果读取jpg或png等压缩格式的图像文件，生成UIImage对象，
 * 默认这个对象内部的图像数据是未解码的，只有在第一次显示的时候才会解码。
 * 本函数可以将压缩的图像数据解码，生成一个解码后的UIImage对象。
 * @param imgFromFile 从文件中得到的图像
 * @return 返回新图像
 */
+ (UIImage*)allocMemoryImageFromImage:(UIImage*)imgFromFile;
/// 根据原始图像生成一幅合成图像，看起来就好像几张照片堆叠在一起
/** @param image 原始图像
 @param shadowRadius 阴影半径（范围）
 @return 返回新的图像 */
+ (UIImage*)allocStackImageFromImage:(UIImage*)image shadowRadius:(float)shadowRadius;
/// 生成圆角按钮图像
/** @param size 按钮大小
 @param redColor 红色分量
 @param greenColor 黄色分量
 @param blueColor 蓝色分量
 @param alpha 不透明度 */
+ (UIImage*)allocRoundedButtonImageWithSize:(CGSize)size redColor:(CGFloat)redColor greenColor:(CGFloat)greenColor blueColor:(CGFloat)blueColor alpha:(CGFloat)alpha;
@end