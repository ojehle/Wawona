#import "WawonaPreferencesManager.h"
#import <Foundation/Foundation.h>

typedef void (^WaypipeOutputHandler)(NSString *output);

@protocol WawonaWaypipeRunnerDelegate <NSObject>
- (void)runnerDidReceiveSSHPasswordPrompt:(NSString *)prompt;
- (void)runnerDidReceiveSSHError:(NSString *)error;
- (void)runnerDidFinishWithExitCode:(int)exitCode;
@end

@class WawonaSSHClient;

@interface WawonaWaypipeRunner : NSObject

@property(nonatomic, weak) id<WawonaWaypipeRunnerDelegate> delegate;
@property(nonatomic, strong, nullable) WawonaSSHClient *sshClient;

+ (instancetype)sharedRunner;

// Logic Helpers
- (NSString *)findWaypipeBinary;
- (NSArray<NSString *> *)buildWaypipeArguments:
    (WawonaPreferencesManager *)prefs;
- (NSString *)generatePreviewString:(WawonaPreferencesManager *)prefs;

// Execution
- (void)launchWaypipe:(WawonaPreferencesManager *)prefs;

@end
