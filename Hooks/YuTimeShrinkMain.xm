#import <UIKit/UIKit.h>
#import "YuTimeShrinkConfig.h"
#import "YuTimeShrinkPrivate.h"
#import "YuTimeShrinkLog.h"

// 参考 LiquidAss 的做法：不遍历视图树，只 hook 明确的锁屏类，
// 拿到时间容器的指针后直接对它做变换。
static const CGFloat yu_timeshrink_playerHeightRatio = 0.42;
static const CGFloat yu_timeshrink_playerWidthRatio = 0.50;

@interface YuTimeShrinkAnimator : NSObject
@property (nonatomic, weak) UIView *clockView;
@property (nonatomic, weak) UIView *dateView;
@property (nonatomic, weak) UIView *playerView;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL applying;
+ (instancetype)yu_timeshrink_shared;
- (void)yu_timeshrink_noteClockView:(UIView *)view;
- (void)yu_timeshrink_noteDateView:(UIView *)view;
- (void)yu_timeshrink_notePlayerView:(UIView *)view;
- (void)yu_timeshrink_evaluate;
- (void)yu_timeshrink_reset;
- (void)yu_timeshrink_applyExpanded:(BOOL)expanded;
- (void)yu_timeshrink_restoreViews;
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

- (void)yu_timeshrink_noteClockView:(UIView *)view {
    if (!view || self.clockView == view) return;
    [self yu_timeshrink_restoreViews];
    self.clockView = view;
    self.expanded = NO;
    yu_timeshrink_log(@"clock view captured: %@ frame=%@", NSStringFromClass(view.class),
                      NSStringFromCGRect(view.frame));
}

- (void)yu_timeshrink_noteDateView:(UIView *)view {
    if (view) self.dateView = view;
}

- (void)yu_timeshrink_notePlayerView:(UIView *)view {
    if (!view || !view.window) return;
    self.playerView = view;
    [self yu_timeshrink_evaluate];
}

- (void)yu_timeshrink_evaluate {
    if (self.applying) return;
    UIView *clock = self.clockView;
    if (!clock || !clock.window) return;

    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];
    if (![config yu_timeshrink_isEnabled]) {
        if (self.expanded) {
            self.expanded = NO;
            [self yu_timeshrink_restoreViews];
        }
        return;
    }

    CGFloat screenHeight = CGRectGetHeight(clock.window.bounds);
    CGFloat screenWidth = CGRectGetWidth(clock.window.bounds);
    UIView *player = self.playerView;
    BOOL expanded = NO;
    if (player && player.window) {
        CGRect bounds = player.bounds;
        expanded = CGRectGetHeight(bounds) > screenHeight * yu_timeshrink_playerHeightRatio ||
                   CGRectGetWidth(bounds) > screenWidth * yu_timeshrink_playerWidthRatio;
    }

    if (expanded == self.expanded) return;
    self.expanded = expanded;
    yu_timeshrink_log(@"state -> %@ (player=%@ %.0fx%.0f)", expanded ? @"expanded" : @"collapsed",
                      player ? NSStringFromClass(player.class) : @"nil",
                      CGRectGetWidth(player.bounds), CGRectGetHeight(player.bounds));

    if ([[config yu_timeshrink_valueForKey:@"dryRun" defaultValue:@(NO)] boolValue]) return;
    [self yu_timeshrink_applyExpanded:expanded];
}

- (void)yu_timeshrink_applyExpanded:(BOOL)expanded {
    UIView *clock = self.clockView;
    if (!clock || !clock.superview) return;
    YuTimeShrinkConfig *config = [YuTimeShrinkConfig yu_timeshrink_shared];

    CGFloat scale = [[config yu_timeshrink_valueForKey:@"scale" defaultValue:@(0.30)] doubleValue];
    scale = MAX(0.12, MIN(0.70, scale));
    BOOL hideDate = [[config yu_timeshrink_valueForKey:@"hideDate" defaultValue:@(YES)] boolValue];

    CGRect frame = clock.frame;
    UIView *superview = clock.superview;
    UIView *root = clock.window;
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

    self.applying = YES;
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
        if (hideDate) self.dateView.alpha = expanded ? 0.0 : 1.0;
    } completion:^(__unused BOOL finished) {
        __strong typeof(weakSelf) self = weakSelf;
        self.applying = NO;
    }];
}

- (void)yu_timeshrink_restoreViews {
    if (self.clockView) {
        self.clockView.transform = CGAffineTransformIdentity;
    }
    if (self.dateView) {
        self.dateView.alpha = 1.0;
    }
}

- (void)yu_timeshrink_reset {
    [self yu_timeshrink_restoreViews];
    self.clockView = nil;
    self.dateView = nil;
    self.playerView = nil;
    self.expanded = NO;
}

@end

#pragma mark - 锁屏时间容器

%hook CSProminentTimeView

- (void)didMoveToWindow {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_noteClockView:self];
}

- (void)layoutSubviews {
    %orig;
    YuTimeShrinkAnimator *animator = [YuTimeShrinkAnimator yu_timeshrink_shared];
    if (animator.clockView != self) {
        [animator yu_timeshrink_noteClockView:self];
    }
}

%end

%hook CSProminentSubtitleDateView

- (void)didMoveToWindow {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_noteDateView:self];
}

%end

#pragma mark - Now Playing 视图

%hook MRUActivityNowPlayingView

- (void)didMoveToWindow {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_notePlayerView:self];
}

- (void)layoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_notePlayerView:self];
}

%end

%hook MRUNowPlayingView

- (void)didMoveToWindow {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_notePlayerView:self];
}

- (void)layoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_notePlayerView:self];
}

%end

%hook MRUArtworkView

- (void)layoutSubviews {
    %orig;
    [[YuTimeShrinkAnimator yu_timeshrink_shared] yu_timeshrink_notePlayerView:self];
}

%end

%ctor {
    @autoreleasepool {
        [YuTimeShrinkConfig yu_timeshrink_shared];
        yu_timeshrink_log(@"loaded");
    }
}
