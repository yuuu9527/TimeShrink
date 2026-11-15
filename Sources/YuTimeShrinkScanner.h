#pragma once

#import <UIKit/UIKit.h>

// 返回锁屏上字号最大的“时间”标签（例如 15:04）。
FOUNDATION_EXPORT UILabel *yu_timeshrink_findClockLabel(UIView *root);

// 返回锁屏上位于时钟上方的日期标签（例如 11月15日 周日）。
FOUNDATION_EXPORT UILabel *yu_timeshrink_findDateLabel(UIView *root, UIView *clock);

// 返回当前锁屏里最大的一块封面区域宽度（折叠时很小，展开时接近屏宽）。
FOUNDATION_EXPORT CGFloat yu_timeshrink_largestArtworkWidth(UIView *root, CGFloat screenWidth);
