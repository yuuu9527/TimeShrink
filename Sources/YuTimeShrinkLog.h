#pragma once

#import <Foundation/Foundation.h>

// 只写少量状态行，用于排查；默认开启，写入 /var/mobile/Documents/timeshrink.log。
FOUNDATION_EXPORT void yu_timeshrink_log(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
