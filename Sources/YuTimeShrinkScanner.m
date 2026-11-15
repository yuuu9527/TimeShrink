#import <math.h>
#import <objc/runtime.h>
#import <string.h>
#import "YuTimeShrinkScanner.h"

// 视图树规模上限：锁屏通常只有几百个视图，超过说明找错层级了。
static const NSUInteger yu_timeshrink_viewBudget = 1400;
static const CGFloat yu_timeshrink_clockMinSize = 34.0;

static BOOL yu_timeshrink_isTimeText(NSString *text) {
    if (text.length < 3 || text.length > 8) return NO;
    BOOL hasDigit = NO, hasColon = NO;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= '0' && c <= '9') hasDigit = YES;
        else if (c == ':' || c == 0xFF1A) hasColon = YES;
        else if (c != ' ') return NO;
    }
    return hasDigit && hasColon;
}

static BOOL yu_timeshrink_classContains(UIView *view, const char *needle) {
    const char *name = object_getClassName(view);
    return name && strcasestr(name, needle) != NULL;
}

static void yu_timeshrink_enumerate(UIView *root, NSUInteger budget,
                                    void (^block)(UIView *view, BOOL *stop)) {
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    BOOL stop = NO;
    while (stack.count > 0 && budget > 0 && !stop) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        budget--;
        block(view, &stop);
        if (stop) break;
        for (UIView *sub in view.subviews) {
            [stack addObject:sub];
        }
    }
}

UIView *yu_timeshrink_findClockView(UIView *root) {
    __block UILabel *bestLabel = nil;
    __block CGFloat bestSize = 0;
    yu_timeshrink_enumerate(root, yu_timeshrink_viewBudget, ^(UIView *view, BOOL *stop) {
        if (![view isKindOfClass:[UILabel class]]) return;
        UILabel *label = (UILabel *)view;
        if (label.hidden || label.alpha < 0.05) return;
        if (!yu_timeshrink_isTimeText(label.text)) return;
        CGFloat size = label.font.pointSize;
        if (size > bestSize) {
            bestSize = size;
            bestLabel = label;
        }
    });
    if (bestSize >= yu_timeshrink_clockMinSize) return bestLabel;
    // 不做无障碍文本回退：遍历时唤醒无障碍树会拖死 SpringBoard。
    return nil;
}

UILabel *yu_timeshrink_findDateLabel(UIView *root, UIView *clock) {
    if (!clock) return nil;
    __block UILabel *best = nil;
    __block CGFloat bestSize = 0;
    yu_timeshrink_enumerate(root, yu_timeshrink_viewBudget, ^(UIView *view, BOOL *stop) {
        if (![view isKindOfClass:[UILabel class]]) return;
        UILabel *label = (UILabel *)view;
        if (label == clock || label.hidden || label.alpha < 0.05) return;
        NSString *text = label.text;
        if (text.length < 4) return;
        if (![text containsString:@"月"] || ![text containsString:@"日"]) return;
        if (label.font.pointSize > bestSize) {
            bestSize = label.font.pointSize;
            best = label;
        }
    });
    return best;
}

CGFloat yu_timeshrink_largestArtworkWidth(UIView *root, CGFloat screenWidth) {
    __block CGFloat best = 0;
    CGFloat threshold = screenWidth * 0.4;
    yu_timeshrink_enumerate(root, yu_timeshrink_viewBudget, ^(UIView *view, BOOL *stop) {
        if (view.hidden || view.alpha < 0.05) return;
        CGRect bounds = view.bounds;
        CGFloat width = bounds.size.width;
        if (width < threshold) return;
        BOOL named = yu_timeshrink_classContains(view, "artwork") ||
                     yu_timeshrink_classContains(view, "albumart") ||
                     yu_timeshrink_classContains(view, "nowplaying");
        BOOL square = [view isKindOfClass:[UIImageView class]] &&
                      fabs(bounds.size.width - bounds.size.height) < bounds.size.width * 0.25;
        if (named || square) best = MAX(best, width);
    });
    return best;
}
