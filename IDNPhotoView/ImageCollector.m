//
//  ImageCollector.m
//  ImagePreviewer
//
//  Created by mahj on 5/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ImageCollector.h"

int ImageCollectorFindSubString(const char*substr,int sublen,const char*string,int len)
{
	int end = len-sublen;
	for(int i=0;i<=end;i++)
	{
		int j = 0;
		while(j<sublen && (string[i+j]==substr[j]))
			j++;
		if(j==sublen)
			return i;
	}
	return -1;
}

@implementation ImageCollector

-(void)scanImages:(NSString*)dir
{
	if(dir==nil)
		dir = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES)[0];
	arrayImageNames = [[NSMutableArray alloc] init];
	NSFileManager* fm = [NSFileManager defaultManager];
	NSArray* files = [fm contentsOfDirectoryAtPath:dir error:nil];
	NSInteger count = files.count;
	const char* exts = ".png.jpg.bmp.gif.tiff.jpeg.tif.ico.cur.bmpf.xbm.";
	int extslen = (int)strlen(exts);
	char ext[12];//存储文件后缀名
	unichar* p = (unichar*)ext;
	for(int i=0;i<count;i++)
	{
		NSString* name = [files objectAtIndex:i];
		int len = (int)name.length;
		int cpylen;
		if (len<4)
			continue;
		else if(len>5)
			cpylen = 5;
		else
			cpylen = len;
		[name getCharacters:p range:NSMakeRange(len-cpylen,cpylen)];
		int j = 0;
		while (j<cpylen && p[j++]!='.');
		if(j>cpylen-3)//后缀长度<3
			continue;
		int extlen=0;
		ext[extlen++] = '.';//后缀名前面加个.
		for (; j<cpylen; j++)
		{
			if(p[j]>127)//非ASCII字符
			{
				extlen=0;
				break;
			}
			else if (p[j]>='A' && p[j]<='Z')
				ext[extlen++] = p[j]+0x20;
			else
				ext[extlen++] = p[j];
		}
		if(extlen==0)
			continue;
		ext[extlen++] = '.';//后缀名后面加个.
		if(ImageCollectorFindSubString(ext,extlen,exts,extslen)>=0)
			[arrayImageNames addObject:name];
	}
}

-(id)init
{
	if((self=[super init]))
	{
//		NSFileManager* fm = [NSFileManager defaultManager];
//		NSString* doc = [IPhoneCommonPath documentPath];
//		NSArray* files = [fm contentsOfDirectoryAtPath:[doc stringByAppendingPathComponent:@"testimages/pngs"] error:nil];
//		for (NSString* file in files) {
//			[fm moveItemAtPath:[NSString stringWithFormat:@"%@/testimages/pngs/%@",doc,file] toPath:[doc stringByAppendingPathComponent:file] error:nil];
//		}
//		files = [fm contentsOfDirectoryAtPath:[doc stringByAppendingPathComponent:@"testimages/jpgs"] error:nil];
//		for (NSString* file in files) {
//			[fm moveItemAtPath:[NSString stringWithFormat:@"%@/testimages/jpgs/%@",doc,file] toPath:[doc stringByAppendingPathComponent:file] error:nil];
//		}
		[self scanImages:nil];
	}
	return self;
}

#pragma mark IDNBreviaryViewSource
-(int) breviaryViewGetCount
{
	return (int)arrayImageNames.count;
}

-(NSString*) breviaryViewGetImagePathByIndex:(int)index name:(NSString**)name subsCount:(int*)subsCount	//subsCount返回－1表示这是张图片，大于等于0表示这是个目录
{
	NSString* imgname = [arrayImageNames objectAtIndex:index];
	*name = imgname;
	*subsCount = -1;
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:imgname];
}

#pragma mark PhotoBrowseViewSource
-(int) getPhotosCount
{
	return (int)arrayImageNames.count;
}
-(NSString*) getPhotoPathByIndex:(int)index	//获取第index张图片的路径
{
	NSString* imgname = [arrayImageNames objectAtIndex:index];
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:imgname];
}

@end
