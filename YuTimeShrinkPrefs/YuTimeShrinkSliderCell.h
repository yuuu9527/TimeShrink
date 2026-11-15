#pragma once

#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#include <math.h>

@protocol YuTimeShrinkSliderCellHandler <NSObject>
- (double)yu_timeshrink_sliderValueForSpecifier:(PSSpecifier *)specifier;
- (void)yu_timeshrink_setSliderValue:(double)value specifier:(PSSpecifier *)specifier;
@end

@interface YuTimeShrinkSliderCell : PSTableCell
@property (nonatomic, weak) id<YuTimeShrinkSliderCellHandler> handler;
- (void)yu_timeshrink_reloadState;
@end
