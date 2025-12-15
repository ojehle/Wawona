#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WawonaSSHAuthMethod) {
  WawonaSSHAuthMethodPassword,
  WawonaSSHAuthMethodPublicKey
};

@class WawonaSSHClient;

@protocol WawonaSSHClientDelegate <NSObject>
@optional
- (void)sshClient:(WawonaSSHClient *)client didReceivePasswordPrompt:(NSString *)prompt;
- (void)sshClient:(WawonaSSHClient *)client didReceiveError:(NSError *)error;
- (void)sshClientDidConnect:(WawonaSSHClient *)client;
- (void)sshClientDidDisconnect:(WawonaSSHClient *)client;
@end

@interface WawonaSSHClient : NSObject

@property (nonatomic, weak, nullable) id<WawonaSSHClientDelegate> delegate;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) BOOL isAuthenticated;

// Connection settings
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port; // Default: 22
@property (nonatomic, copy) NSString *username;

// Authentication
@property (nonatomic, assign) WawonaSSHAuthMethod authMethod;
@property (nonatomic, copy, nullable) NSString *password; // For password authentication
@property (nonatomic, copy, nullable) NSString *privateKeyPath; // For key file authentication
@property (nonatomic, copy, nullable) NSString *publicKeyPath; // Optional, auto-detected if nil
@property (nonatomic, copy, nullable) NSString *keyPassphrase; // For encrypted private keys

// Timeout settings (in seconds)
@property (nonatomic, assign) NSTimeInterval connectionTimeout; // Default: 30
@property (nonatomic, assign) NSTimeInterval readTimeout; // Default: 10

- (instancetype)initWithHost:(NSString *)host
                     username:(NSString *)username
                        port:(NSInteger)port;

// Connection management
- (BOOL)connect:(NSError **)error;
- (BOOL)authenticate:(NSError **)error;
- (void)disconnect;

// Execute remote command
- (BOOL)executeCommand:(NSString *)command
            output:(NSString *__autoreleasing _Nullable *)output
            error:(NSError **)error;

// Forward local port to remote (for waypipe)
- (BOOL)forwardLocalPort:(NSInteger)localPort
            toRemoteHost:(NSString *)remoteHost
            remotePort:(NSInteger)remotePort
            error:(NSError **)error;

// Create a persistent shell channel for waypipe (returns file descriptor)
- (int)createShellChannel:(NSError **)error;

// Get the underlying socket file descriptor (for waypipe)
- (int)socketFileDescriptor;

// Create a shell channel and return a file descriptor pair for waypipe
// Returns YES on success, with localFd and remoteFd set
// The localFd can be used as stdin/stdout for waypipe
// The remoteFd is the SSH channel that forwards data
- (BOOL)createBidirectionalChannelWithLocalFD:(int *)localFd remoteFD:(int *)remoteFd error:(NSError **)error;

// Start a tunnel for a specific command (or shell if command is nil)
// Returns the local socket file descriptor connected to the tunnel
- (BOOL)startTunnelForCommand:(nullable NSString *)command localSocket:(int *)localSocket error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
