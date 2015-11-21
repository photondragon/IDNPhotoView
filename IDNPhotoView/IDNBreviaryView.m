#import "IDNBreviaryView.h"
#import "IDNTask.h"
#import "UIImage+IDNExtend.h"

@protocol BreviaryImageViewDelegate<NSObject>
- (void)breviaryImageViewClicked:(NSInteger)index;
@end

@interface BreviaryImageView : UIImageView
{
	BOOL	bMoved;
}
@property (nonatomic) NSInteger index;
@property (nonatomic, weak) id<BreviaryImageViewDelegate> delegate;
@end
@implementation BreviaryImageView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		self.userInteractionEnabled = YES;
	}
	return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	bMoved = FALSE;
	[[self nextResponder] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	bMoved = TRUE;
	[[self nextResponder] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if(bMoved==FALSE)
	{
		[_delegate breviaryImageViewClicked:_index];
	}
	[[self nextResponder] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[self nextResponder] touchesCancelled:touches withEvent:event];
}

@end

#pragma mark

/*
 containerSize和cellSize决定scrollViewFrame
 在以上因素都确定的基础上，cellsCount的改变影响contentSize
 在以上因素都确定的基础上，contentOffset的改变会影响visibleRange和bufferRange
 */
@interface IDNBreviaryLayout : NSObject
{
	CGFloat cellMargin; //不取整
	CGFloat unitWidth; //不取整
	CGFloat rowHeight; //取整
	CGFloat scrollMaxY; //不取整

	NSInteger countPerRow;	//每行缩略图个数
	NSInteger maxVisibleRows;	//最多可见的行数，限制为偶数，因为预加载行数是上下各是maxVisibleRows/2
	NSInteger rows;//行数
}
@property(nonatomic) CGSize containerSize;
@property(nonatomic) CGSize cellSize;
@property(nonatomic) NSInteger cellsCount;
@property(nonatomic,readonly) CGPoint contentOffset; //影响visibleRange和bufferRange

@property(nonatomic,readonly) CGRect scrollViewFrame;
@property(nonatomic,readonly) CGSize contentSize;

@property(nonatomic,readonly) NSRange visibleRange;
@property(nonatomic,readonly) NSRange bufferRange;
@end

@implementation IDNBreviaryLayout

- (instancetype)init
{
	self = [super init];
	if (self) {
		_cellSize.width = 80.0;
		_cellSize.height = 80.0;

		_containerSize.width = -1.0;
		_containerSize.height = -1.0;
		self.containerSize = CGSizeZero; // 计算内部参数
	}
	return self;
}

- (void)setContainerSize:(CGSize)containerSize
{
	NSInteger oldBreviaryPerRow = countPerRow;
	CGFloat oldBreviaryUnitWidth = unitWidth;

	if(containerSize.width<0.0)
		containerSize.width = 0.0;
	else if(containerSize.width>20480.0)
		containerSize.width = 20480.0; //随便加个上限
	else
		containerSize.width = roundf(containerSize.width); //取整
	if(containerSize.height<0.0)
		containerSize.height = 0.0;
	else if(containerSize.height>20480.0)
		containerSize.height = 20480.0; //随便加个上限
	else
		containerSize.height = roundf(containerSize.height); //取整

	if(CGSizeEqualToSize(_containerSize, containerSize))
		return;

	_containerSize = containerSize;

	[self calcLayout];
	[self calcContentSize];

	if(oldBreviaryPerRow==countPerRow && oldBreviaryUnitWidth==unitWidth)//宽度没变
		;
	else
		_contentOffset = CGPointZero;
	[self calcVisibleRange];
}

- (void)setCellSize:(CGSize)cellSize
{
	if(cellSize.width<8.0)
		cellSize.width = 8.0;
	else if(cellSize.width>20480.0)
		cellSize.width = 20480.0; //随便加个上限
	else
		cellSize.width = roundf(cellSize.width); //取整
	if(cellSize.height<8.0)
		cellSize.height = 8.0;
	else if(cellSize.height>20480.0)
		cellSize.height = 20480.0; //随便加个上限
	else
		cellSize.height = roundf(cellSize.height); //取整

	if(CGSizeEqualToSize(_cellSize, cellSize)) //大小没有改变
		return;

	_cellSize = cellSize;
	_contentOffset = CGPointZero;

	[self calcLayout];
	[self calcContentSize];
	[self calcVisibleRange];
}

- (void)setCellsCount:(NSInteger)cellsCount
{
	if(cellsCount<0)
		cellsCount = 0;

	if(_cellsCount==cellsCount)
		return;
	_cellsCount = cellsCount;

	[self calcContentSize];
	[self calcVisibleRange];
}

// 如果更新了contentOffset，返回YES；否则返回NO
- (BOOL)updateContentOffset:(CGPoint)contentOffset
{
	if(contentOffset.y<0)
		contentOffset.y = 0;
	else if(contentOffset.y>scrollMaxY)
		contentOffset.y = scrollMaxY;
	if(CGPointEqualToPoint(_contentOffset, contentOffset))
		return NO;

	_contentOffset = contentOffset;

	[self calcVisibleRange];

	return YES;
}

- (void)calcLayout
{
	//每行个数
	countPerRow = (NSInteger)(_containerSize.width/_cellSize.width);
	if(countPerRow<1)
		countPerRow = 1;
	else if(countPerRow>1024) //每行个数加个上限（虽然实际中不太可能遇到）
		countPerRow = 1024;

	CGFloat space = _containerSize.width - countPerRow*_cellSize.width;
	if(space<0)
	{
		if(countPerRow>1)
		{
			countPerRow--;
			space = _containerSize.width - countPerRow*_cellSize.width;
		}
		else
			space = 0;
	}
	cellMargin = space/countPerRow/2.0; //不取整
	unitWidth = _cellSize.width+cellMargin*2.0; //不取整
	rowHeight = roundf(_cellSize.height+cellMargin*2); //取整

	if(_containerSize.height<=0.0 || _containerSize.width<=0.0)
		maxVisibleRows = 0;
	else
	{
		//计算可视的行数
		maxVisibleRows = floorf(_containerSize.height/rowHeight);
		if((_containerSize.height - maxVisibleRows*rowHeight)>0.0) //不是整除
			maxVisibleRows++;
		maxVisibleRows++; //还要再+1，因为最上面或者最下面哪怕只冒出新的一行的半个像素，也要算作可视
		if(maxVisibleRows%2)//奇数
			maxVisibleRows++; //变偶数
	}
	_scrollViewFrame = CGRectMake(0, 0, _containerSize.width, _containerSize.height);
}

- (void)calcContentSize
{
	rows = (_cellsCount+countPerRow-1)/countPerRow;
	_contentSize = CGSizeMake(0, rowHeight*rows);

	scrollMaxY = _contentSize.height-_containerSize.height;
	if(scrollMaxY<0)
		scrollMaxY = 0;
}

- (void)calcVisibleRange
{
	// 计算显示范围
	NSInteger row = _contentOffset.y/rowHeight;
	_visibleRange.location = row*countPerRow;
	_visibleRange.length = maxVisibleRows*countPerRow;
	if(_visibleRange.location + _visibleRange.length > _cellsCount)
		_visibleRange.length = _cellsCount - _visibleRange.location;

	// 计算缓存范围
	NSInteger bufferRowStart = row-maxVisibleRows/2;
	if(bufferRowStart<0)
		_bufferRange.location = 0;
	else
		_bufferRange.location = bufferRowStart*countPerRow;
	_bufferRange.length = maxVisibleRows*2*countPerRow;
	if(_bufferRange.location + _bufferRange.length > _cellsCount)
		_bufferRange.length = _cellsCount - _bufferRange.location;
	
}

// 计算Cell的frame
- (CGRect)cellFrameAtIndex:(NSInteger)index
{
	if(index<0 || index>=_cellsCount)
		return CGRectZero;
	CGFloat x = index%countPerRow*unitWidth;
	CGFloat y = index/countPerRow*rowHeight;
	CGRect frame = CGRectMake(roundf(x+cellMargin), roundf(y+cellMargin), _cellSize.width, _cellSize.height);
	return frame;
}

@end

#pragma mark

@interface IDNBreviaryView()
<UIScrollViewDelegate,
BreviaryImageViewDelegate>
{
	IDNBreviaryLayout* layout;
	UIScrollView*	viewScroll;

	id<IDNBreviaryViewSource>	source;
	NSInteger breviaryCount;

	//显示范围[visibleHeadIndex,visibleTailIndex)
	NSInteger visibleHeadIndex;
	NSInteger visibleTailIndex;//（不包括visibleTailIndex本身）
	//缓冲范围[bufferHeadIndex,bufferTailIndex)
	NSInteger bufferHeadIndex;
	NSInteger bufferTailIndex;//（不包括visibleTailIndex本身）
	NSMutableDictionary* dicBufferedImages;	//缓存的缩略图
	NSMutableDictionary* dicBreviaryImageViews;
	NSMutableArray*	arrayImageViewTrash;
}

@end

@implementation IDNBreviaryView

- (void)initializer
{
	if(viewScroll)
		return;
	dicBufferedImages = [[NSMutableDictionary alloc] init];
	dicBreviaryImageViews = [[NSMutableDictionary alloc] init];
	arrayImageViewTrash = [[NSMutableArray alloc] init];

	layout = [[IDNBreviaryLayout alloc] init];

	viewScroll = [[UIScrollView alloc] init];
	viewScroll.alwaysBounceVertical = YES;
	viewScroll.panGestureRecognizer.delaysTouchesBegan = NO;
	viewScroll.panGestureRecognizer.delaysTouchesEnded = NO;
	viewScroll.pinchGestureRecognizer.delaysTouchesBegan = NO;
	viewScroll.pinchGestureRecognizer.delaysTouchesEnded = NO;
	[viewScroll setDelegate:self];
	[self addSubview:viewScroll];
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self initializer];
	}
	return self;
}
- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self initializer];
	}
	return self;
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initializer];
	}
	return self;
}

- (void)setSource:(id<IDNBreviaryViewSource>)aSource
{
	[self performSelectorOnMainThread:@selector(setSourceOnMainThread:) withObject:aSource waitUntilDone:YES];
}

- (void)setSourceOnMainThread:(id <IDNBreviaryViewSource>)aSource
{
	[IDNTask cancelAllTasksInGroup:self];
	[self showFrom:0 to:0 updateVisibleCellFrames:NO];
	[self bufferFrom:0 to:0];

	source = aSource;

	layout.cellsCount = [source breviaryViewGetCount];
	[layout updateContentOffset:CGPointZero];
	viewScroll.contentSize = layout.contentSize;
	viewScroll.contentOffset = CGPointZero; // 如果修改了offset，会触发scrollViewDidScroll
	[self bufferAndShow];

	[arrayImageViewTrash removeAllObjects];//移除垃圾箱里的多余的view
}

// updateVisibleCellFrames==YES表示更新之前已显示cell的frame
- (void)showFrom:(NSInteger)head to:(NSInteger)tail updateVisibleCellFrames:(BOOL)updateVisibleCellFrames//显示范围[head,tail)
{
	NSInteger istart = head<=visibleHeadIndex ? head : visibleHeadIndex;
	NSInteger iend = tail>=visibleTailIndex ? tail : visibleTailIndex;

	for (NSInteger i=istart; i<iend; i++) {
		if((i>=visibleHeadIndex && i<visibleTailIndex)//以前可见
		   && (i<head || i>=tail))//现在不可见
		{
			// 移除cell
			NSNumber* index = @(i);
			BreviaryImageView* view = [dicBreviaryImageViews objectForKey:index];
			if(view)
			{
				[arrayImageViewTrash addObject:view];
				[view removeFromSuperview];
				view.image = nil;
				[dicBreviaryImageViews removeObjectForKey:index];
			}
		}
		else if((i>=head && i<tail) //现在可见
				&& (i<visibleHeadIndex || i>=visibleTailIndex)) //以前不可见
		{
			NSNumber* index = @(i);
			BreviaryImageView* view = [self allocBreviaryImageView];
			view.index = i;
			view.frame = [layout cellFrameAtIndex:i];
			view.image = [dicBufferedImages objectForKey:index];

			[viewScroll addSubview:view];
			[dicBreviaryImageViews setObject:view forKey:index];
		}
		else // 以前现在都可见
		{
			if(updateVisibleCellFrames) //更新之前已显示cell的frame
			{
				NSNumber* index = @(i);
				BreviaryImageView* view = [dicBreviaryImageViews objectForKey:index];
				view.frame = [layout cellFrameAtIndex:i];
			}
		}
	}
	visibleHeadIndex = head;
	visibleTailIndex = tail;
}

- (void)bufferFrom:(NSInteger)head to:(NSInteger)tail//缓冲范围[head,tail)
{
	//先移除
	for(NSInteger i=bufferHeadIndex;i<bufferTailIndex;i++)//已缓冲的
	{
		if(i<head || i>=tail)//但不在缓冲目标中的
		{
			NSNumber* index = @(i);
			[IDNTask cancelTaskWithKey:index group:self];
			[dicBufferedImages removeObjectForKey:index];
		}
	}

	CGSize cellSize = layout.cellSize;
	cellSize.width *= [UIScreen mainScreen].scale;
	cellSize.height *= [UIScreen mainScreen].scale;
	//再新增
	for(NSInteger i=head;i<tail;i++)//要缓冲的
	{
		if(i<bufferHeadIndex || i>=bufferTailIndex)//不在现有缓冲中
		{
			NSString* imgName;
			int subsCount;
			NSString* imgPath = [source breviaryViewGetImagePathByIndex:i name:&imgName subsCount:&subsCount];

			NSNumber* indexNumber = @(i);
			__weak __typeof(self) wself = self;
			[IDNTask submitTask:^id{
				if([IDNTask isTaskCancelled])
					return nil;
				// 加载图片
				NSData* data = [[NSData alloc] initWithContentsOfFile:imgPath];
				if([IDNTask isTaskCancelled])
					return nil;
				UIImage* image = [[UIImage alloc] initWithData:data];
				return [image resizedImageWithAspectFillSize:cellSize clipToBounds:YES];
			} finished:^(UIImage* img) {
				__typeof(self) sself = wself;
				[sself loadedImage:img atIndex:indexNumber];
			} cancelled:nil key:indexNumber group:self];
		}
	}
	bufferHeadIndex = head;
	bufferTailIndex = tail;
}

- (BreviaryImageView*)allocBreviaryImageView
{
	BreviaryImageView* view;
	if(arrayImageViewTrash.count==0)
	{
		view = [[BreviaryImageView alloc] init];
		view.delegate = self;
	}
	else
	{
		view = [arrayImageViewTrash lastObject] ;
		[arrayImageViewTrash removeLastObject];
	}
	return view;
}

- (void)loadedImage:(UIImage*)image atIndex:(NSNumber*)indexNumber
{
	[dicBufferedImages setObject:image forKey:indexNumber];
	BreviaryImageView* view = [dicBreviaryImageViews objectForKey:indexNumber];
	view.image = image;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if([layout updateContentOffset:scrollView.contentOffset])//成功更新
		[self bufferAndShow];
}

#pragma mark BreviaryImageViewDelegate

- (void)breviaryImageViewClicked:(NSInteger)index
{
	[_delegate breviaryViewImageClicked:index];
}

#pragma mark Layout

- (void)layoutSubviews
{
	[super layoutSubviews];
	layout.containerSize = self.frame.size;
	viewScroll.frame = layout.scrollViewFrame;
	viewScroll.contentSize = layout.contentSize;
	viewScroll.contentOffset = layout.contentOffset;

	NSRange bufferRange = layout.bufferRange;
	[self bufferFrom:bufferRange.location to:bufferRange.location + bufferRange.length];

	NSRange visibleRange = layout.visibleRange;
	[self showFrom:visibleRange.location to:visibleRange.location + visibleRange.length updateVisibleCellFrames:YES];
}

- (void)bufferAndShow
{
	NSRange bufferRange = layout.bufferRange;
	[self bufferFrom:bufferRange.location to:bufferRange.location + bufferRange.length];

	NSRange visibleRange = layout.visibleRange;
	[self showFrom:visibleRange.location to:visibleRange.location + visibleRange.length updateVisibleCellFrames:NO];
}

@end
