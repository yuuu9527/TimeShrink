#import "YuTimeShrinkLog.h"
#import <stdarg.h>

static NSString * const yu_timeshrink_logPath = @"/var/mobile/Documents/timeshrink.log";

void yu_timeshrink_log(NSString *format, ...) {
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

    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *attributes = [manager attributesOfItemAtPath:yu_timeshrink_logPath error:nil];
    if (!attributes || [attributes fileSize] > 120 * 1024) {
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
