#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "YuTimeShrinkConfig.h"
#import "YuTimeShrinkPrivate.h"
#import "YuTimeShrinkScanner.h"

static const CGFloat YuTimeShrinkArtworkRatio = 0.45;   // 封面超过屏宽这个比例即视为展开
static const NSTimeInterval YuTimeShrinkScanInterval = 0.4;

@interface YuTimeShrinkAnimator : NSObject
@property (nonatomic, weak) UILabel *clockLabel;
@property (nonatomic, weak) UILabel *dateLabel;
@property (nonatomic, weak) UIView *rootView;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, strong) NSTimer *scanTimer;

+ (instancetype)yu_timeshrink_shared;
- (void)yu_timeshrink_startScanning;
- (void)yu_timeshrink_stopScanning;
- (void)yu_timeshrink_refreshInView:(UIView *)root;
- (void)yu_timeshrink_reset;
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

#pragma mark - 扫描控制

- (void)yu_timeshrink_startScanning {
    if (self.scanTimer) return;
    __weak typeof(self) weakSelf = self;
    self.scanTimer = [NSTimer timerWithTimeInterval:YuTimeShrinkScanInterval
                                             repeats:YES
                                               block:^(NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self yu_timeshrink_refreshInView:self.rootView ?: [self yu_timeshrink_lockScreenView]];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.scanTimer forMode:NSRunLoopCommonModes];
}

- (void)yu_timeshrink_stopScanning {
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    [self yu_timeshrink_reset];
}

- (UIView *)yu_timeshrink_lockScreenView {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            for (UIView *view in window.subviews) {
                if ([view isKindOfClass:NSClassFromString(@"CSCoverSheetView")]) {
                    return view;
                }
            }
        }
    }
    return nil;
}

#pragma mark - 主逻辑

- (void)yu_timeshrink_refreshInView:(UIView *)root {
    if (!root || !root.window || root.hidden) return;
    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];
    if (![config yu_timeshrink_isEnabled]) {
        [self yu_timeshrink_reset];
        return;
    }
    self.rootView = root;

    UILabel *clock = yu_timeshrink_findClockLabel(root);
    if (!clock) return;

    CGFloat screenWidth = CGRectGetWidth(root.window.bounds);
    CGFloat artwork = yu_timeshrink_largestArtworkWidth(root, screenWidth);
    BOOL shouldExpand = artwork > screenWidth * YuTimeShrinkArtworkRatio;

    if (clock != self.clockLabel) {
        // 控件重建时先恢复旧的那个，避免残留 transform。
        [self yu_timeshrink_restoreViews];
        self.clockLabel = clock;
        self.expanded = NO;
    } else if (shouldExpand == self.expanded && [self yu_timeshrink_isApplied]) {
        return;
    }

    self.expanded = shouldExpand;
    [self yu_timeshrink_applyExpanded:shouldExpand animated:YES];
}

- (BOOL)yu_timeshrink_isApplied {
    UILabel *clock = self.clockLabel;
    if (!clock) return NO;
    BOOL identity = CGAffineTransformIsIdentity(clock.transform);
    return self.expanded ? !identity : identity;
}

- (void)yu_timeshrink_applyExpanded:(BOOL)expanded animated:(BOOL)animated {
    UILabel *clock = self.clockLabel;
    if (!clock || !clock.superview) return;
    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];

    CGFloat scale = [[config yu_timeshrink_valueForKey:@"scale" defaultValue:@(0.30)] doubleValue];
    scale = MAX(0.12, MIN(0.70, scale));

    UIView *superview = clock.superview;
    UIView *root = self.rootView ?: clock.window;
    CGRect frame = clock.frame;
    CGRect clockInRoot = [superview convertRect:frame toView:root];

    CGFloat topInRoot = root.safeAreaInsets.top + 6.0;
    CGRect targetInRoot = CGRectMake(CGRectGetMinX(clockInRoot), topInRoot,
                                     CGRectGetWidth(clockInRoot) * scale,
                                     CGRectGetHeight(clockInRoot) * scale);
    CGRect targetInSuper = [root convertRect:targetInRoot toView:superview];

    CGAffineTransform transform = CGAffineTransformIdentity;
    if (expanded) {
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
    CGFloat dateAlpha = (hideDate && expanded) ? 0.0 : 1.0;

    void (^changes)(void) = ^{
        clock.transform = transform;
        if (self.dateLabel) self.dateLabel.alpha = dateAlpha;
        clock.alpha = expanded ? 0.9 : 1.0;
    };

    if (!animated) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.42
                          delay:0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)yu_timeshrink_restoreViews {
    if (self.clockLabel) {
        self.clockLabel.transform = CGAffineTransformIdentity;
        self.clockLabel.alpha = 1.0;
    }
    if (self.dateLabel) {
        self.dateLabel.alpha = 1.0;
    }
}

- (void)yu_timeshrink_reset {
    [self yu_timeshrink_restoreViews];
    self.clockLabel = nil;
    self.dateLabel = nil;
    self.expanded = NO;
}

@end

#pragma mark - Hooks

%hook CSCoverSheetViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_refreshInView:self.view];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_startScanning];
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_refreshInView:self.view];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_stopScanning];
}

%end

%hook CSMainPageContentViewController

- (void)viewDidLayoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_refreshInView:self.view];
}

%end

%ctor {
    @autoreleasepool {
        [YuTimeShrinkConfig yu_timeshrink_shared];
    }
}
