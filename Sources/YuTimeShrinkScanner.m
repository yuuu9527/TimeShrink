#import <math.h>
#import "YuTimeShrinkScanner.h"

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

// 遍历时限制节点数量，避免在异常层级上做无限工作。
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

UIView *yu_timeshrink_findClockLabel(UIView *root) {
    __block UIView *best = nil;
    __block CGFloat bestSize = 0;
    yu_timeshrink_enumerate(root, 6000, ^(UIView *view, BOOL *stop) {
        if (view.hidden || view.alpha < 0.05) return;
        BOOL matched = NO;
        CGFloat size = 0;
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            matched = yu_timeshrink_isTimeText(label.text);
            size = label.font.pointSize;
        }
        // 有些系统版本用自绘视图，只暴露无障碍文本。
        if (!matched) {
            matched = yu_timeshrink_isTimeText(view.accessibilityLabel);
            size = MAX(size, CGRectGetHeight(view.bounds));
        }
        if (!matched) return;
        if (size > bestSize) {
            bestSize = size;
            best = view;
        }
    });
    // 正常锁屏时间至少 40pt，避免误抓状态栏的小时间。
    return bestSize >= 34.0 ? best : nil;
}

UILabel *yu_timeshrink_findDateLabel(UIView *root, UIView *clock) {
    if (!clock) return nil;
    CGRect clockFrame = [clock.superview convertRect:clock.frame toView:root];
    __block UILabel *best = nil;
    __block CGFloat bestSize = 0;
    yu_timeshrink_enumerate(root, 6000, ^(UIView *view, BOOL *stop) {
        if (![view isKindOfClass:[UILabel class]]) return;
        UILabel *label = (UILabel *)view;
        if (label == clock || label.hidden || label.alpha < 0.05) return;
        NSString *text = label.text;
        if (text.length < 4) return;
        if (![text containsString:@"月"] || ![text containsString:@"日"]) return;
        CGRect frame = [label.superview convertRect:label.frame toView:root];
        // 只处理时钟上方或与时钟同一水平带的日期行。
        if (frame.origin.y > CGRectGetMaxY(clockFrame) + 40.0) return;
        if (label.font.pointSize > bestSize) {
            bestSize = label.font.pointSize;
            best = label;
        }
    });
    return best;
}

CGFloat yu_timeshrink_largestArtworkWidth(UIView *root, CGFloat screenWidth) {
    __block CGFloat best = 0;
    yu_timeshrink_enumerate(root, 6000, ^(UIView *view, BOOL *stop) {
        if (view.hidden || view.alpha < 0.05) return;
        CGRect bounds = view.bounds;
        CGFloat width = bounds.size.width;
        if (width < screenWidth * 0.4) return;

        NSString *className = NSStringFromClass(view.class).lowercaseString;
        BOOL named = [className containsString:@"artwork"] ||
                     [className containsString:@"albumart"] ||
                     [className containsString:@"nowplaying"];
        BOOL squareImage = [view isKindOfClass:[UIImageView class]] &&
                           fabs(bounds.size.width - bounds.size.height) < bounds.size.width * 0.25;
        if (named || squareImage) {
            best = MAX(best, width);
        }
    });
    return best;
}
