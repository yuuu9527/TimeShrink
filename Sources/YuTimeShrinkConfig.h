#pragma once

#import <Foundation/Foundation.h>

@interface YuTimeShrinkConfig : NSObject
+ (instancetype)yu_timeshrink_shared;
- (BOOL)yu_timeshrink_isEnabled;
- (id)yu_timeshrink_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)yu_timeshrink_reload;
@end
