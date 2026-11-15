#pragma once

#import <UIKit/UIKit.h>

// 只声明会被 hook 的入口，避免依赖完整私有头。
// iOS 16+ 锁屏时间的宿主视图（LiquidAss 也是在这一层做文章）。
@interface CSProminentDisplayView : UIView
@end

@interface CSProminentTimeView : UIView
@end

@interface CSProminentSubtitleDateView : UIView
@end

// 锁屏 / 音乐 App 的 Now Playing 视图（MediaRemoteUI）。
@interface MRUActivityNowPlayingView : UIView
@end

@interface MRUNowPlayingView : UIView
@end

@interface MRUArtworkView : UIView
@end
