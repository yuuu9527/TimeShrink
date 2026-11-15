#import <UIKit/UIKit.h>
#import <stdarg.h>
#import <QuartzCore/QuartzCore.h>
#import "YuTimeShrinkConfig.h"
#import "YuTimeShrinkPrivate.h"
#import "YuTimeShrinkScanner.h"

// 封面超过屏宽这个比例才视为“音乐已展开”。
static const CGFloat yu_timeshrink_artworkRatio = 0.45;
// 两次扫描之间的最小间隔，避免布局回调里反复遍历视图树。
static const CFTimeInterval yu_timeshrink_refreshInterval = 0.45;
// 单次扫描超过这个耗时就自我冷却，防止把主线程拖死。
static const CFTimeInterval yu_timeshrink_heavyCost = 0.030;
static const CFTimeInterval yu_timeshrink_cooldown = 5.0;
static NSString * const yu_timeshrink_logPath = @"/var/mobile/Documents/timeshrink.log";

static void yu_timeshrink_log(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[TimeShrink] %@", message);

    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM-dd HH:mm:ss.SSS";
    });
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n",
                      [formatter stringFromDate:[NSDate date]], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:yu_timeshrink_logPath]) {
        [data writeToFile:yu_timeshrink_logPath atomically:YES];
        return;
    }
    NSDictionary *attributes = [fm attributesOfItemAtPath:yu_timeshrink_logPath error:nil];
    if ([attributes fileSize] > 180 * 1024) {
        [data writeToFile:yu_timeshrink_logPath atomically:YES];
        return;
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:yu_timeshrink_logPath];
    if (!handle) {
        [data writeToFile:yu_timeshrink_logPath atomically:YES];
        return;
    }
    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
    }
}

@interface YuTimeShrinkAnimator : NSObject
@property (nonatomic, weak) UIView *clockView;
@property (nonatomic, weak) UILabel *dateLabel;
@property (nonatomic, weak) UIView *rootView;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL scheduled;
@property (nonatomic, assign) CFTimeInterval lastRefresh;
@property (nonatomic, assign) CFTimeInterval cooldownUntil;
@property (nonatomic, assign) CFTimeInterval armedAt;
@property (nonatomic, assign) NSInteger heavyStrikes;
@property (nonatomic, assign) BOOL sessionDisabled;
@property (nonatomic, assign) CFTimeInterval lastLogTime;
@end

@implementation YuTimeShrinkAnimator

+ (instancetype)yu_timeshrink_shared {
    static YuTimeShrinkAnimator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - 节流入口

- (void)yu_timeshrink_scheduleRefreshInView:(UIView *)view {
    if (!view) return;
    CFTimeInterval now = CACurrentMediaTime();
    if (self.sessionDisabled) return;
    if (self.armedAt <= 0) {
        // 启动后先稳定几秒，避免在 SpringBoard 初始化阶段做任何遍历。
        self.armedAt = now + 3.0;
    }
    if (now < self.armedAt || now < self.cooldownUntil) return;
    if (self.scheduled) return;
    if (now - self.lastRefresh < yu_timeshrink_refreshInterval) return;
    self.scheduled = YES;
    self.lastRefresh = now;
    self.rootView = view;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.scheduled = NO;
        [self yu_timeshrink_performRefresh];
    });
}

- (void)yu_timeshrink_performRefresh {
    UIView *root = self.rootView;
    if (!root || !root.window || root.hidden) return;

    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];
    if (![config yu_timeshrink_isEnabled]) {
        [self yu_timeshrink_restoreViews];
        self.clockView = nil;
        self.dateLabel = nil;
        self.expanded = NO;
        return;
    }

    CFTimeInterval start = CACurrentMediaTime();

    UIView *clock = self.clockView;
    if (!clock || !clock.window) {
        clock = yu_timeshrink_findClockView(root);
        self.clockView = clock;
        self.expanded = NO;
    }
    if (!clock) {
        CFTimeInterval now = CACurrentMediaTime();
        if (now - self.lastLogTime > 10.0) {
            self.lastLogTime = now;
            yu_timeshrink_log(@"clock not found (views budget exhausted), artwork=%.0f",
                              yu_timeshrink_largestArtworkWidth(root, CGRectGetWidth(root.window.bounds)));
        }
        return;
    }

    CGFloat screenWidth = CGRectGetWidth(root.window.bounds);
    CGFloat artwork = yu_timeshrink_largestArtworkWidth(root, screenWidth);
    BOOL shouldExpand = artwork > screenWidth * yu_timeshrink_artworkRatio;
    BOOL dryRun = [[config yu_timeshrink_valueForKey:@"dryRun" defaultValue:@(YES)] boolValue];

    NSString *clockInfo = @"nil";
    if ([clock isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)clock;
        clockInfo = [NSString stringWithFormat:@"UILabel text=%@ size=%.0f frame=%@",
                     label.text, label.font.pointSize, NSStringFromCGRect(label.frame)];
    } else {
        clockInfo = [NSString stringWithFormat:@"%@ frame=%@",
                     NSStringFromClass(clock.class), NSStringFromCGRect(clock.frame)];
    }
    CFTimeInterval now = CACurrentMediaTime();
    if (dryRun && (shouldExpand != self.expanded || now - self.lastLogTime > 10.0)) {
        self.lastLogTime = now;
        yu_timeshrink_log(@"dry-run clock=%@ artwork=%.0f screen=%.0f expand=%d state=%d",
                          clockInfo, artwork, screenWidth, shouldExpand, self.expanded);
    }
    if (dryRun) {
        self.expanded = shouldExpand;
        return;
    }

    if (shouldExpand != self.expanded || ![self yu_timeshrink_isApplied]) {
        self.expanded = shouldExpand;
        [self yu_timeshrink_applyExpanded:shouldExpand];
    }

    CFTimeInterval cost = CACurrentMediaTime() - start;
    if (cost > yu_timeshrink_heavyCost) {
        // 视图树异常庞大时先停一会儿；连续超时就整个会话停用。
        self.heavyStrikes += 1;
        if (self.heavyStrikes >= 3) {
            self.sessionDisabled = YES;
        } else {
            self.cooldownUntil = CACurrentMediaTime() + yu_timeshrink_cooldown;
        }
    }
}

- (BOOL)yu_timeshrink_isApplied {
    UIView *clock = self.clockView;
    if (!clock) return NO;
    BOOL identity = CGAffineTransformIsIdentity(clock.transform);
    return self.expanded ? !identity : identity;
}

#pragma mark - 应用动画

- (void)yu_timeshrink_applyExpanded:(BOOL)expanded {
    UIView *clock = self.clockView;
    if (!clock || !clock.superview) return;
    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];

    CGFloat scale = [[config yu_timeshrink_valueForKey:@"scale" defaultValue:@(0.30)] doubleValue];
    scale = MAX(0.12, MIN(0.70, scale));

    CGRect frame = clock.frame;
    UIView *superview = clock.superview;
    UIView *root = self.rootView ?: clock.window;
    CGRect clockInRoot = [superview convertRect:frame toView:root];
    CGFloat topInRoot = root.safeAreaInsets.top + 6.0;

    CGAffineTransform transform = CGAffineTransformIdentity;
    if (expanded) {
        CGRect targetInRoot = CGRectMake(CGRectGetMinX(clockInRoot), topInRoot,
                                         CGRectGetWidth(clockInRoot) * scale,
                                         CGRectGetHeight(clockInRoot) * scale);
        CGRect targetInSuper = [root convertRect:targetInRoot toView:superview];
        transform = CGAffineTransformMakeScale(scale, scale);
        transform.tx = CGRectGetMidX(targetInSuper) - CGRectGetMidX(frame);
        transform.ty = CGRectGetMidY(targetInSuper) - CGRectGetMidY(frame);
    }

    UILabel *date = nil;
    BOOL hideDate = [[config yu_timeshrink_valueForKey:@"hideDate" defaultValue:@(YES)] boolValue];
    if (hideDate && expanded) {
        date = yu_timeshrink_findDateLabel(root, clock);
        self.dateLabel = date;
    }

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.42
                          delay:0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        __strong typeof(weakSelf) self = weakSelf;
        clock.transform = transform;
        clock.alpha = expanded ? 0.9 : 1.0;
        if (self.dateLabel) self.dateLabel.alpha = expanded ? 0.0 : 1.0;
    } completion:nil];
}

- (void)yu_timeshrink_restoreViews {
    if (self.clockView) {
        self.clockView.transform = CGAffineTransformIdentity;
        self.clockView.alpha = 1.0;
    }
    if (self.dateLabel) {
        self.dateLabel.alpha = 1.0;
    }
}

@end

#pragma mark - Hooks

%hook CSCoverSheetViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_scheduleRefreshInView:self.view];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_scheduleRefreshInView:self.view];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    YuTimeShrinkAnimator *animator = [YuTimeShrinkAnimator yu_timeshrink_shared];
    [animator yu_timeshrink_restoreViews];
    animator.clockView = nil;
    animator.dateLabel = nil;
    animator.expanded = NO;
}

%end

%hook CSMainPageContentViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_scheduleRefreshInView:self.view];
}

%end

%ctor {
    @autoreleasepool {
        [YuTimeShrinkConfig yu_timeshrink_shared];
    }
}
