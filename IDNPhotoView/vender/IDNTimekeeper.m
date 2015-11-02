//
//  IDNTimekeeper.m
//  IDNPhotoView
//
//  Created by photondragon on 15/10/27.
//  Copyright © 2015年 iosdev.net. All rights reserved.
//

#import "IDNTimekeeper.h"
#include <mach/mach_time.h>

@implementation IDNTimekeeper
{
	clock_t	m_nCodeStart;
	clock_t	m_nCodeEnd;

	uint64_t m_nStart;
	uint64_t m_nEnd;
	double m_nStepDuration;	//单位秒
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		mach_timebase_info_data_t info;
		if (mach_timebase_info (&info) == KERN_SUCCESS)
			m_nStepDuration = ((double)info.numer) / info.denom / 1000000000.0;
	}
	return self;
}

- (void)codeStart
{
	m_nCodeStart = clock();
	m_nCodeEnd = m_nCodeStart;
}

- (void)codeEnd
{
	m_nCodeEnd = clock();
}

- (void)codeRestart
{
	m_nCodeStart = m_nCodeEnd;
}

- (double)getCodeElapsedTime
{
	return ((double)(m_nCodeEnd-m_nCodeStart))/CLOCKS_PER_SEC;
}

- (void)start
{
	m_nStart = mach_absolute_time();
	m_nEnd = m_nStart;
}

- (void)end
{
	m_nEnd = mach_absolute_time();
}

- (void)restart
{
	m_nStart = m_nEnd;
}

- (double)getElapsedTime
{
	return (double)(m_nEnd - m_nStart)*m_nStepDuration;
}
@end
