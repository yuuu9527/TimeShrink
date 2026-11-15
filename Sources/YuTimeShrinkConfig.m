#import "YuTimeShrinkConfig.h"
#import "YuTimeShrinkPreferences.h"

@interface YuTimeShrinkConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void yu_timeshrink_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    YuTimeShrinkConfig *config = (__bridge YuTimeShrinkConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config yu_timeshrink_reload];
    });
}

@implementation YuTimeShrinkConfig

+ (instancetype)yu_timeshrink_shared {
    static YuTimeShrinkConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.yu.timeshrink.preferences", DISPATCH_QUEUE_SERIAL);
        [self yu_timeshrink_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, yu_timeshrink_preferencesDidChange,
            (__bridge CFStringRef)YuTimeShrinkPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self yu_timeshrink_reload]; });
    }
    return self;
}

- (void)yu_timeshrink_reload {
    self.snapshot = yu_timeshrink_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:YuTimeShrinkPreferencesChanged object:self];
    });
}

- (id)yu_timeshrink_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)yu_timeshrink_isEnabled {
    id value = [self yu_timeshrink_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
