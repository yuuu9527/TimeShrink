#pragma once

#import <UIKit/UIKit.h>

// 锁屏主控制器（CoverSheet）。只声明用到的入口，避免依赖完整私有头。
@interface CSCoverSheetViewController : UIViewController
@end

// iOS 26 起锁屏正文也可能由这个控制器承载，一并挂上作为兜底。
@interface CSMainPageContentViewController : UIViewController
@end
