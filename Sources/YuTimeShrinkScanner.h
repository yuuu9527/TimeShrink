#pragma once

#import <UIKit/UIKit.h>

// 只做轻量查询：不触发无障碍树，不分配字符串。
FOUNDATION_EXPORT UIView *yu_timeshrink_findClockView(UIView *root);
FOUNDATION_EXPORT UILabel *yu_timeshrink_findDateLabel(UIView *root, UIView *clock);
FOUNDATION_EXPORT CGFloat yu_timeshrink_largestArtworkWidth(UIView *root, CGFloat screenWidth);
