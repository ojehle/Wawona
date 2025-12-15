#import "WawonaPreferences.h"
#import "WawonaPreferencesManager.h"
#import "WawonaSettingsModel.h"
#import "WawonaWaypipeRunner.h"
#import <objc/runtime.h>
#import <Network/Network.h>

// System headers removed as they are now used in WawonaWaypipeRunner or unused
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <unistd.h>
#import <errno.h>

// MARK: - Helper Class Interfaces

#if !TARGET_OS_IPHONE
@interface WawonaPreferencesSidebar
    : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, weak) WawonaPreferences *parent;
@property(nonatomic, strong) NSOutlineView *outlineView;
@end

@interface WawonaPreferencesContent
    : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) WawonaPreferencesSection *section;
@property(nonatomic, strong) NSTableView *tableView;
@end
#endif

// MARK: - Main Class Extension

@interface WawonaPreferences () <WawonaWaypipeRunnerDelegate>
#if !TARGET_OS_IPHONE
<NSToolbarDelegate>
#endif
    @property(nonatomic, strong) NSArray<WawonaPreferencesSection *> *sections;
#if !TARGET_OS_IPHONE
@property(nonatomic, strong) NSSplitViewController *splitVC;
@property(nonatomic, strong) WawonaPreferencesSidebar *sidebar;
@property(nonatomic, strong) WawonaPreferencesContent *content;
@property(nonatomic, strong) NSWindowController *winController;
#endif
- (NSArray<WawonaPreferencesSection *> *)buildSections;
- (void)runWaypipe;
- (NSString *)localIPAddress;
- (void)pingHost;
#if !TARGET_OS_IPHONE
- (void)showSection:(NSInteger)idx;
#endif
@end

// MARK: - Main Implementation

@implementation WawonaPreferences

+ (instancetype)sharedPreferences {
  static WawonaPreferences *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

#if !TARGET_OS_IPHONE
- (instancetype)init {
  self = [super init];
  if (self) {
    self.sections = [self buildSections];
  }
  return self;
}
#else
- (instancetype)init {
  self = [super initWithStyle:UITableViewStyleInsetGrouped];
  if (self) {
    self.title = @"Settings";
    [WawonaWaypipeRunner sharedRunner].delegate = self;
    self.sections = [self buildSections];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(dismissSelf)];
  }
  return self;
}
#endif

#define ITEM(t, k, ty, def, d)                                                 \
  [WawonaSettingItem itemWithTitle:t key:k type:ty default:def desc:d]

- (NSArray<WawonaPreferencesSection *> *)buildSections {
  NSMutableArray *sects = [NSMutableArray array];

  // DISPLAY
  WawonaPreferencesSection *display = [[WawonaPreferencesSection alloc] init];
  display.title = @"Display";
  display.icon = @"display";
#if TARGET_OS_IPHONE
  display.iconColor = [UIColor systemBlueColor];
#else
  display.iconColor = [NSColor systemBlueColor];
#endif
  NSMutableArray *displayItems = [NSMutableArray arrayWithArray:@[
    ITEM(@"Force Server-Side Decorations", @"ForceServerSideDecorations",
         WSettingSwitch, @NO, @"Forces macOS-style window decorations."),
    ITEM(@"Auto Scale", @"AutoScale", WSettingSwitch, @NO,
         @"Matches macOS UI Scaling."),
    ITEM(@"Respect Safe Area", @"RespectSafeArea", WSettingSwitch, @NO,
         @"Avoids notch areas.")
  ]];
  
  // Only show macOS Cursor option on macOS (not iOS/Android)
#if !TARGET_OS_IPHONE
  [displayItems insertObject:ITEM(@"Show macOS Cursor", @"RenderMacOSPointer", WSettingSwitch, @NO,
                                   @"Toggles macOS cursor visibility.")
                      atIndex:1];
#endif
  
  display.items = displayItems;
  [sects addObject:display];

  // INPUT
  WawonaPreferencesSection *input = [[WawonaPreferencesSection alloc] init];
  input.title = @"Input";
  input.icon = @"keyboard";
#if TARGET_OS_IPHONE
  input.iconColor = [UIColor systemPurpleColor];
#else
  input.iconColor = [NSColor systemPurpleColor];
#endif
  WawonaSettingItem *touchInputItem =
      ITEM(@"Touch Input Type", @"TouchInputType", WSettingPopup, @"Multi-Touch",
           @"Input method for touch interactions.");
  touchInputItem.options = @[ @"Multi-Touch", @"Trackpad" ];
  
  input.items = @[
    touchInputItem,
    ITEM(@"Swap CMD with ALT", @"SwapCmdWithAlt", WSettingSwitch, @NO,
         @"Swaps Command and Alt keys."),
    ITEM(@"Universal Clipboard", @"UniversalClipboard", WSettingSwitch,
         @YES, @"Syncs clipboard with macOS.")
  ];
  [sects addObject:input];

  // GRAPHICS
  WawonaPreferencesSection *graphics = [[WawonaPreferencesSection alloc] init];
  graphics.title = @"Graphics";
  graphics.icon = @"cpu";
#if TARGET_OS_IPHONE
  graphics.iconColor = [UIColor systemRedColor];
#else
  graphics.iconColor = [NSColor systemRedColor];
#endif
  graphics.items = @[
    ITEM(@"Enable Vulkan Drivers", @"VulkanDriversEnabled", WSettingSwitch, @YES,
         @"Experimental Vulkan support."),
    ITEM(@"Enable EGL Drivers", @"EglDriversEnabled", WSettingSwitch, @NO,
         @"EGL hardware acceleration."),
    ITEM(@"Enable DMABUF", @"DmabufEnabled", WSettingSwitch, @YES,
         @"Zero-copy texture sharing.")
  ];
  [sects addObject:graphics];

  // CONNECTION
  WawonaPreferencesSection *connection = [[WawonaPreferencesSection alloc] init];
  connection.title = @"Connection";
  connection.icon = @"network";
#if TARGET_OS_IPHONE
  connection.iconColor = [UIColor systemOrangeColor];
#else
  connection.iconColor = [NSColor systemOrangeColor];
#endif
  connection.items = @[
    ITEM(@"TCP Port", @"TCPListenerPort", WSettingNumber, @6000,
         @"Port for TCP listener."),
    ITEM(@"Socket Directory", @"WaylandSocketDir", WSettingInfo, @"/tmp",
         @"Directory for sockets (tap to copy).")
  ];
  [sects addObject:connection];

  // ADVANCED
  WawonaPreferencesSection *advanced = [[WawonaPreferencesSection alloc] init];
  advanced.title = @"Advanced";
  advanced.icon = @"gearshape.2";
#if TARGET_OS_IPHONE
  advanced.iconColor = [UIColor systemGrayColor];
#else
  advanced.iconColor = [NSColor systemGrayColor];
#endif
  advanced.items = @[
    ITEM(@"Color Operations", @"ColorOperations", WSettingSwitch, @NO,
         @"Color profiles and HDR."),
    ITEM(@"Nested Compositors", @"NestedCompositorsSupport",
         WSettingSwitch, @YES, @"Support for nested compositors."),
    ITEM(@"Multiple Clients", @"MultipleClients", WSettingSwitch, @NO,
         @"Allow multiple clients."),
    ITEM(@"Enable Launcher", @"EnableLauncher", WSettingSwitch, @NO,
         @"Start the built-in Wayland Launcher.")
  ];
  [sects addObject:advanced];

  // WAYPIPE
  WawonaPreferencesSection *waypipe = [[WawonaPreferencesSection alloc] init];
  waypipe.title = @"Waypipe";
  waypipe.icon = @"arrow.triangle.2.circlepath";
#if TARGET_OS_IPHONE
  waypipe.iconColor = [UIColor systemGreenColor];
#else
  waypipe.iconColor = [NSColor systemGreenColor];
#endif

  __weak typeof(self) weakSelf = self;
  WawonaSettingItem *previewBtn =
      ITEM(@"Preview Command", @"WaypipePreview", WSettingButton, nil,
           @"View and copy the generated command.");
  previewBtn.actionBlock = ^{
    [weakSelf previewWaypipeCommand];
  };

  WawonaSettingItem *runBtn =
      ITEM(@"Run Waypipe", @"WaypipeRun", WSettingButton, nil,
           @"Launch waypipe with current settings.");
  runBtn.actionBlock = ^{
    [weakSelf runWaypipe];
  };

  WawonaSettingItem *compressItem =
      ITEM(@"Compression", @"WaypipeCompress", WSettingPopup, @"lz4",
           @"Compression method.");
  compressItem.options = @[ @"none", @"lz4", @"zstd" ];

  WawonaSettingItem *videoItem =
      ITEM(@"Video Codec", @"WaypipeVideo", WSettingPopup, @"none",
           @"Lossy video codec.");
  videoItem.options = @[ @"none", @"h264", @"vp9", @"av1" ];

  WawonaSettingItem *vEnc =
      ITEM(@"Encoding", @"WaypipeVideoEncoding", WSettingPopup, @"hw",
           @"Hardware vs Software.");
  vEnc.options = @[ @"hw", @"sw", @"hwenc", @"swenc" ];

  WawonaSettingItem *vDec =
      ITEM(@"Decoding", @"WaypipeVideoDecoding", WSettingPopup, @"hw",
           @"Hardware vs Software.");
  vDec.options = @[ @"hw", @"sw", @"hwdec", @"swdec" ];

  WawonaSettingItem *authMethodItem =
      ITEM(@"Auth Method", @"WaypipeSSHAuthMethod", WSettingPopup, @"Password",
           @"Authentication method.");
  authMethodItem.options = @[ @"Password", @"Public Key" ];

  WawonaSettingItem *pingBtn =
      ITEM(@"Ping Host", @"WaypipePingHost", WSettingButton, nil,
           @"Test network connectivity to SSH host.");
  pingBtn.actionBlock = ^{
    [weakSelf pingHost];
  };

  waypipe.items = @[
    ITEM(@"Local IP", nil, WSettingInfo, [self localIPAddress], nil),
    ITEM(@"Display Number", @"WaylandDisplayNumber", WSettingNumber, @0,
         @"Display number for socket and waypipe (e.g., 0 = wayland-0)."),
    compressItem,
    ITEM(@"Comp. Level", @"WaypipeCompressLevel", WSettingNumber, @7,
         @"Zstd level (1-22)."),
    ITEM(@"Threads", @"WaypipeThreads", WSettingNumber, @0, @"0 = auto."),
    videoItem,
    vEnc,
    vDec,
    ITEM(@"Bits Per Frame", @"WaypipeVideoBpf", WSettingNumber, @"",
         @"Target bit rate per frame for video encoding. Recommended range: 1000-10000 bits per frame. Higher values provide better quality but use more bandwidth. Leave empty for automatic bit rate."),
    ITEM(@"Enable SSH", @"WaypipeSSHEnabled", WSettingSwitch, @NO, @"Use SSH."),
    ITEM(@"SSH Host", @"WaypipeSSHHost", WSettingText, @"", @"Remote host."),
    ITEM(@"SSH User", @"WaypipeSSHUser", WSettingText, @"", @"SSH Username."),
    authMethodItem,
    ITEM(@"SSH Password", @"WaypipeSSHPassword", WSettingPassword, @"", @"SSH password (stored securely)."),
    ITEM(@"SSH Key Path", @"WaypipeSSHKeyPath", WSettingText, @"", @"Path to private key file."),
    ITEM(@"Key Passphrase", @"WaypipeSSHKeyPassphrase", WSettingPassword, @"", @"Passphrase for encrypted key (stored securely)."),
    pingBtn,
    ITEM(@"Remote Command", @"WaypipeRemoteCommand", WSettingText, @"",
         @"Command to run remotely."),
    ITEM(@"Debug Mode", @"WaypipeDebug", WSettingSwitch, @NO,
         @"Print debug logs. When enabled, waypipe will output detailed debugging information to help troubleshoot connection issues, protocol errors, and performance problems."),
    ITEM(@"Disable GPU", @"WaypipeNoGpu", WSettingSwitch, @NO,
         @"Block GPU protocols. Disables GPU-accelerated rendering and forces software rendering. Use this if you experience GPU-related crashes or compatibility issues."),
    ITEM(@"One-shot", @"WaypipeOneshot", WSettingSwitch, @NO,
         @"Exit when client disconnects. When enabled, waypipe will automatically terminate when the remote client disconnects, rather than waiting for a new connection. Useful for single-use remote sessions."),
    ITEM(@"Unlink Socket", @"WaypipeUnlinkSocket", WSettingSwitch, @NO,
         @"Unlink socket on exit. When enabled, waypipe will remove the Wayland socket file when it exits. This prevents \"socket already exists\" errors when restarting, but may cause issues if other processes are using the socket."),
    ITEM(@"Login Shell", @"WaypipeLoginShell", WSettingSwitch, @NO,
         @"Run in login shell. When enabled, waypipe will execute the remote command in a login shell (e.g., bash -l), which loads full user environment including .bash_profile and .bashrc. Use this if your remote applications need full environment setup."),
    ITEM(@"VSock", @"WaypipeVsock", WSettingSwitch, @NO,
         @"Use VSock. Enables virtio-vsock communication for virtual machines. VSock provides faster communication between host and guest VMs compared to TCP/IP. Only works when running inside a VM with VSock support (e.g., QEMU/KVM with virtio-vsock device)."),
    ITEM(@"XWayland", @"WaypipeXwls", WSettingSwitch, @NO,
         @"Enable XWayland support."),
    ITEM(@"Title Prefix", @"WaypipeTitlePrefix", WSettingText, @"",
         @"Prefix added to window titles. Example: \"Remote:\" will show windows as \"Remote: Application Name\". Leave empty for no prefix."),
    ITEM(@"Sec Context", @"WaypipeSecCtx", WSettingText, @"",
         @"SELinux security context for waypipe processes. This is a Linux security feature that labels processes with security attributes (e.g., \"system_u:system_r:waypipe_t:s0\"). Only needed if SELinux is enabled on the remote system. Leave empty to use default context."),
    previewBtn,
    runBtn
  ];
  [sects addObject:waypipe];

  return sects;
}

- (NSString *)findWaypipeBinary {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
  NSString *execDir =
      [[NSBundle mainBundle] executablePath].stringByDeletingLastPathComponent;

  // Potential paths in order of preference
  NSArray *candidates = @[
    [[NSBundle mainBundle] pathForResource:@"waypipe" ofType:nil] ?: @"",
    [[NSBundle mainBundle] pathForResource:@"waypipe" ofType:@"bin"] ?: @"",
    [bundlePath stringByAppendingPathComponent:@"waypipe"],
    [bundlePath stringByAppendingPathComponent:@"waypipe-bin"],
    [bundlePath stringByAppendingPathComponent:@"bin/waypipe"],
    [execDir stringByAppendingPathComponent:@"waypipe"],
    [[NSProcessInfo processInfo].environment[@"WAYPIPE_BIN"]
        stringByStandardizingPath]
        ?: @""
  ];

  for (NSString *path in candidates) {
    if (path.length == 0 || ![fm fileExistsAtPath:path])
      continue;

    // Fix permissions if needed
    if (![fm isExecutableFileAtPath:path]) {
      [fm setAttributes:@{NSFilePosixPermissions : @0755}
           ofItemAtPath:path
                  error:nil];
    }

    if ([fm isExecutableFileAtPath:path]) {
      NSLog(@"[WawonaPreferences] Found Waypipe at: %@", path);
      return path;
    }
  }

  NSLog(@"[WawonaPreferences] Waypipe binary not found.");
  return nil;
}

- (NSString *)localIPAddress {
  NSString *address = @"Not available";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = 0;
  
  // Retrieve the current interfaces - returns 0 on success
  success = getifaddrs(&interfaces);
  if (success == 0) {
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      if (temp_addr->ifa_addr->sa_family == AF_INET) {
        // Check if interface is en0 (WiFi) or en1 (Ethernet) or similar
        NSString *ifname = [NSString stringWithUTF8String:temp_addr->ifa_name];
        if ([ifname hasPrefix:@"en"] || [ifname hasPrefix:@"eth"]) {
          // Get NSString from C String
          char *ipCString = inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr);
          NSString *ipString = [NSString stringWithUTF8String:ipCString];
          
          // Skip localhost
          if (![ipString isEqualToString:@"127.0.0.1"]) {
            address = ipString;
            break;
          }
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }
  
  // Free memory
  freeifaddrs(interfaces);
  return address;
}

- (void)runWaypipe {
  // Save any pending text field changes first (macOS only - iOS uses alerts)
#if !TARGET_OS_IPHONE
  // On macOS, text fields might have unsaved changes
  // Force end editing to commit any pending changes
  [self.view.window makeFirstResponder:nil];
#endif
  
  // Ensure all settings are saved before running waypipe
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  // Launch waypipe
  [[WawonaWaypipeRunner sharedRunner]
      launchWaypipe:[WawonaPreferencesManager sharedManager]];
  
#if TARGET_OS_IPHONE
  // Dismiss settings view after launching waypipe on iOS
  // Use a small delay to ensure waypipe launch has started
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self dismissViewControllerAnimated:YES completion:nil];
  });
#endif
}

- (void)pingHost {
  WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
  NSString *host = prefs.waypipeSSHHost;
  
  if (!host || host.length == 0) {
#if TARGET_OS_IPHONE
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"No Host Specified"
                         message:@"Please enter an SSH host address first."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
#else
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"No Host Specified";
    alert.informativeText = @"Please enter an SSH host address first.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
#endif
    return;
  }

#if TARGET_OS_IPHONE
  UIAlertController *progressAlert = [UIAlertController
      alertControllerWithTitle:@"Pinging Host"
                       message:[NSString stringWithFormat:@"Testing connectivity to %@...", host]
                preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:progressAlert animated:YES completion:nil];
#else
  // Show progress indicator on macOS
  NSAlert *progressAlert = [[NSAlert alloc] init];
  progressAlert.messageText = @"Pinging Host";
  progressAlert.informativeText = [NSString stringWithFormat:@"Testing connectivity to %@...", host];
  [progressAlert addButtonWithTitle:@"Cancel"];
  NSModalResponse response = [progressAlert runModal];
  if (response == NSAlertFirstButtonReturn) {
    return; // User cancelled
  }
#endif

  // Perform ping on background thread using Network.framework
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDate *startTime = [NSDate date];
    __block BOOL success = NO;
    __block NSString *errorMessage = nil;
    __block NSTimeInterval latency = 0;

    // Use Network.framework to test connectivity
    nw_endpoint_t endpoint = nw_endpoint_create_host([host UTF8String], "22");
    
    // Explicitly configure for TCP without TLS, and enable local network access
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(
        NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_include_peer_to_peer(parameters, true);
    
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    if (!connection) {
      errorMessage = @"Failed to create Network.framework connection";
      NSLog(@"Ping error: %@", errorMessage);
    } else {
      dispatch_queue_t connectionQueue = dispatch_queue_create("com.wawona.ping", DISPATCH_QUEUE_SERIAL);
      nw_connection_set_queue(connection, connectionQueue);
      
      // Use semaphore to wait for connection synchronously
      dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
      
      nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t nw_error) {
        switch (state) {
          case nw_connection_state_ready: {
            success = YES;
            latency = [[NSDate date] timeIntervalSinceDate:startTime] * 1000; // Convert to ms
            nw_connection_cancel(connection);
            dispatch_semaphore_signal(semaphore);
            break;
          }
          case nw_connection_state_failed:
          case nw_connection_state_cancelled: {
            if (nw_error) {
              nw_error_domain_t domain = nw_error_get_error_domain(nw_error);
              int error_code = nw_error_get_error_code(nw_error);
              
              // Provide more user-friendly error messages
              NSString *domainName = @"Unknown";
              NSString *codeDescription = @"";
              
              if (domain == nw_error_domain_dns) {
                domainName = @"DNS";
                if (error_code == 1) { // kDNSServiceErr_NoSuchRecord
                  codeDescription = @" (Host not found)";
                } else if (error_code == -65554) { // kDNSServiceErr_NoAuth
                  codeDescription = @" (DNS authentication failed)";
                }
              } else if (domain == nw_error_domain_tls) {
                domainName = @"TLS";
              } else if (domain == nw_error_domain_posix) {
                domainName = @"POSIX";
                if (error_code == 61) { // ECONNREFUSED
                  codeDescription = @" (Connection refused - host may not be listening on port 22)";
                } else if (error_code == 51) { // ENETUNREACH
                  codeDescription = @" (Network unreachable)";
                } else if (error_code == 65) { // ENETDOWN
                  codeDescription = @" (Network is down)";
                } else {
                   codeDescription = [NSString stringWithFormat:@" (%s)", strerror(error_code)];
                }
              }
              
              errorMessage = [NSString stringWithFormat:@"Connection failed: %@ error %d%@", domainName, error_code, codeDescription];
              NSLog(@"Ping failed: %@", errorMessage);
            } else {
              errorMessage = @"Connection failed";
              NSLog(@"Ping failed: %@", errorMessage);
            }
            dispatch_semaphore_signal(semaphore);
            break;
          }
          default:
            break;
        }
      });
      
      nw_connection_start(connection);
      
      // Wait for connection with 10 second timeout (increased for simulator)
      dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC));
      if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        // Timeout
        errorMessage = @"Connection timeout after 10 seconds";
        NSLog(@"Ping timeout");
        nw_connection_cancel(connection);
      }
    }

    // Show results on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
      [progressAlert dismissViewControllerAnimated:YES completion:^{
        UIAlertController *resultAlert = [UIAlertController
            alertControllerWithTitle:success ? @"Ping Successful" : @"Ping Failed"
                             message:success
                                 ? [NSString stringWithFormat:@"Host %@ is reachable.\nLatency: %.0f ms", host, latency]
                                 : [NSString stringWithFormat:@"Could not reach %@.\n%@", host, errorMessage ?: @"Unknown error"]
                      preferredStyle:UIAlertControllerStyleAlert];
        [resultAlert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil]];
        [self presentViewController:resultAlert animated:YES completion:nil];
      }];
#else
      NSAlert *resultAlert = [[NSAlert alloc] init];
      resultAlert.messageText = success ? @"Ping Successful" : @"Ping Failed";
      resultAlert.informativeText = success
          ? [NSString stringWithFormat:@"Host %@ is reachable.\nLatency: %.0f ms", host, latency]
          : [NSString stringWithFormat:@"Could not reach %@.\n%@", host, errorMessage ?: @"Unknown error"];
      [resultAlert addButtonWithTitle:@"OK"];
      [resultAlert runModal];
#endif
    });
  });
}

#pragma mark - WawonaWaypipeRunnerDelegate

- (void)runnerDidReceiveSSHPasswordPrompt:(NSString *)prompt {
  NSLog(@"[WawonaPreferences] SSH password prompt: %@", prompt);
#if TARGET_OS_IPHONE
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"SSH Password Required"
                       message:prompt ?: @"Enter your SSH password:"
                preferredStyle:UIAlertControllerStyleAlert];

  __block UITextField *passwordField = nil;
  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    passwordField = textField;
    textField.placeholder = @"Password";
    textField.secureTextEntry = YES;
    
    // Add show/hide toggle button
    UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [toggleButton setImage:[UIImage systemImageNamed:@"eye"] forState:UIControlStateNormal];
    [toggleButton setImage:[UIImage systemImageNamed:@"eye.slash"] forState:UIControlStateSelected];
    toggleButton.frame = CGRectMake(0, 0, 30, 30);
    toggleButton.contentMode = UIViewContentModeCenter;
    [toggleButton addTarget:self action:@selector(togglePasswordVisibility:) forControlEvents:UIControlEventTouchUpInside];
    
    // Store reference to text field in button for toggling
    objc_setAssociatedObject(toggleButton, "passwordField", textField, OBJC_ASSOCIATION_ASSIGN);
    
    textField.rightView = toggleButton;
    textField.rightViewMode = UITextFieldViewModeAlways;
  }];

  UIAlertAction *cancel =
      [UIAlertAction actionWithTitle:@"Cancel"
                               style:UIAlertActionStyleCancel
                             handler:nil];
  UIAlertAction *submit = [UIAlertAction
      actionWithTitle:@"Save & Connect"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                NSString *password = passwordField.text;
                if (password && password.length > 0) {
                  // Save password to Keychain
                  WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
                  prefs.waypipeSSHPassword = password;
                  
                  // Retry waypipe connection
                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self runWaypipe];
                  });
                } else {
                  UIAlertController *errorAlert = [UIAlertController
                      alertControllerWithTitle:@"Password Required"
                                       message:@"Please enter a password."
                                preferredStyle:UIAlertControllerStyleAlert];
                  [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:nil]];
                  [self presentViewController:errorAlert animated:YES completion:nil];
                }
              }];
  [alert addAction:cancel];
  [alert addAction:submit];
  [self presentViewController:alert animated:YES completion:nil];
#else
  // macOS: Use NSAlert with secure text field
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"SSH Password Required";
  alert.informativeText = prompt ?: @"Enter your SSH password:";
  [alert addButtonWithTitle:@"Save & Connect"];
  [alert addButtonWithTitle:@"Cancel"];
  alert.alertStyle = NSAlertStyleInformational;
  
  NSSecureTextField *passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  alert.accessoryView = passwordField;
  
  NSModalResponse response = [alert runModal];
  if (response == NSAlertFirstButtonReturn) {
    NSString *password = passwordField.stringValue;
    if (password && password.length > 0) {
      WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
      prefs.waypipeSSHPassword = password;
      
      // Retry waypipe connection
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self runWaypipe];
      });
    }
  }
#endif
}

- (void)runnerDidReceiveSSHError:(NSString *)error {
#if TARGET_OS_IPHONE
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"SSH/Waypipe Error"
                                          message:error
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
#endif
}

- (void)runnerDidFinishWithExitCode:(int)exitCode {
  // Handle finish
}

#if TARGET_OS_IPHONE

- (void)showPreferences:(id)sender {
  // On iOS, showPreferences is typically called to present the view controller
  // Since WawonaPreferences is a UIViewController on iOS, this might be called
  // from elsewhere. For now, we'll ensure the view is loaded.
  [self loadViewIfNeeded];
}

- (void)dismissSelf {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
  return self.sections.count;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
  return self.sections[sec].items.count;
}
- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)sec {
  return self.sections[sec].title;
}

- (UITableViewCell *)tableView:(UITableView *)tv
         cellForRowAtIndexPath:(NSIndexPath *)ip {
  WawonaSettingItem *item = self.sections[ip.section].items[ip.row];
  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:@"Cell"];
  }

  cell.textLabel.text = item.title;
  cell.textLabel.textColor = [UIColor labelColor]; // Reset to default color (not blue)
  cell.detailTextLabel.text = nil;
  cell.accessoryView = nil;
  cell.selectionStyle = UITableViewCellSelectionStyleNone;

  if (item.type == WSettingSwitch) {
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:item.key];
    sw.tag = (ip.section * 1000) + ip.row;
    [sw addTarget:self
                  action:@selector(swChg:)
        forControlEvents:UIControlEventValueChanged];
    
    // Add help button (?) for certain settings that need detailed explanations
    NSArray *helpSettings = @[@"WaypipeDebug", @"WaypipeNoGpu", @"WaypipeOneshot", 
                              @"WaypipeUnlinkSocket", @"WaypipeLoginShell", @"WaypipeVsock"];
    if ([helpSettings containsObject:item.key]) {
      UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
      helpButton.tag = (ip.section * 1000) + ip.row;
      [helpButton addTarget:self action:@selector(showHelpForSetting:) forControlEvents:UIControlEventTouchUpInside];
      
      // Create container view with switch and help button
      UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 31)];
      sw.frame = CGRectMake(0, 0, 51, 31);
      helpButton.frame = CGRectMake(55, 0, 25, 25);
      helpButton.center = CGPointMake(helpButton.center.x, containerView.center.y);
      [containerView addSubview:sw];
      [containerView addSubview:helpButton];
      cell.accessoryView = containerView;
    } else {
      cell.accessoryView = sw;
    }
  } else if (item.type == WSettingText || item.type == WSettingNumber) {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    if (!val) {
      val = item.defaultValue;
    }
    
    // Special handling for Display Number: show computed wayland-X value
    if ([item.key isEqualToString:@"WaylandDisplayNumber"]) {
      NSInteger displayNum = [val isKindOfClass:[NSNumber class]] ? [val integerValue] : 0;
      cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld (wayland-%ld)", (long)displayNum, (long)displayNum];
    } else {
      cell.detailTextLabel.text = [val description];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
  } else if (item.type == WSettingPassword) {
    // For password fields, show dots if password exists, otherwise show placeholder
    WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
    NSString *password = nil;
    if ([item.key isEqualToString:@"WaypipeSSHPassword"]) {
      password = prefs.waypipeSSHPassword;
    } else if ([item.key isEqualToString:@"WaypipeSSHKeyPassphrase"]) {
      password = prefs.waypipeSSHKeyPassphrase;
    }
    if (password && password.length > 0) {
      cell.detailTextLabel.text = @"••••••••";
    } else {
      cell.detailTextLabel.text = @"Tap to set";
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
  } else if (item.type == WSettingPopup) {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    if (!val) {
      val = item.defaultValue;
    }
    
    // Special handling for Auth Method: convert integer to string
    if ([item.key isEqualToString:@"WaypipeSSHAuthMethod"]) {
      NSInteger methodIndex = [val isKindOfClass:[NSNumber class]] ? [val integerValue] : 0;
      if (methodIndex >= 0 && methodIndex < item.options.count) {
        cell.detailTextLabel.text = item.options[methodIndex];
      } else {
        cell.detailTextLabel.text = item.options[0]; // Default to "Password"
      }
    } else {
      cell.detailTextLabel.text = [val description];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
  } else if (item.type == WSettingButton) {
    cell.textLabel.textColor = [UIColor systemBlueColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
  } else if (item.type == WSettingInfo) {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    if (!val) {
      val = item.defaultValue;
    }
    cell.detailTextLabel.text = [val description];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
  }
  return cell;
}

- (void)swChg:(UISwitch *)s {
  WawonaSettingItem *item = self.sections[s.tag / 1000].items[s.tag % 1000];
  [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:item.key];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)showHelpForSetting:(UIButton *)button {
  NSInteger section = button.tag / 1000;
  NSInteger row = button.tag % 1000;
  WawonaSettingItem *item = self.sections[section].items[row];
  [self showHelpForSettingWithItem:item];
}

- (void)showHelpForSettingWithItem:(WawonaSettingItem *)item {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:item.title
                       message:item.desc
                preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
  [alert addAction:okAction];
  
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
  [tv deselectRowAtIndexPath:ip animated:YES];
  WawonaSettingItem *item = self.sections[ip.section].items[ip.row];

  // For switch items with help buttons, show help when row is tapped
  if (item.type == WSettingSwitch) {
    NSArray *helpSettings = @[@"WaypipeDebug", @"WaypipeNoGpu", @"WaypipeOneshot", 
                              @"WaypipeUnlinkSocket", @"WaypipeLoginShell", @"WaypipeVsock"];
    if ([helpSettings containsObject:item.key]) {
      [self showHelpForSettingWithItem:item];
      return;
    }
  }

  if (item.type == WSettingText || item.type == WSettingNumber) {
    // Present text entry view controller
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:item.title
                         message:item.desc
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      id currentValue =
          [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
      if (!currentValue) {
        currentValue = item.defaultValue;
      }
      textField.text = [currentValue description];
      if (item.type == WSettingNumber) {
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
      } else {
        textField.keyboardType = UIKeyboardTypeDefault;
      }
      // Set placeholder text - special case for Remote Command
      if ([item.key isEqualToString:@"WaypipeRemoteCommand"]) {
        textField.placeholder = @"e.g. weston-terminal";
      } else {
        textField.placeholder = item.desc;
      }
    }];

    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    UIAlertAction *saveAction = [UIAlertAction
        actionWithTitle:@"Save"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                  UITextField *textField = alert.textFields.firstObject;
                  NSString *value = textField.text;

                  if (item.type == WSettingNumber) {
                    NSNumber *numberValue = @([value doubleValue]);
                    [[NSUserDefaults standardUserDefaults] setObject:numberValue
                                                              forKey:item.key];
                  } else {
                    [[NSUserDefaults standardUserDefaults] setObject:value
                                                              forKey:item.key];
                  }
                  [[NSUserDefaults standardUserDefaults] synchronize];

                  // Reload the table view to show updated value
                  [tv reloadRowsAtIndexPaths:@[ ip ]
                            withRowAnimation:UITableViewRowAnimationNone];
                }];

    [alert addAction:cancelAction];
    [alert addAction:saveAction];

    [self presentViewController:alert animated:YES completion:nil];
  } else if (item.type == WSettingPassword) {
    // Present password entry with show/hide toggle
    WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
    NSString *currentPassword = nil;
    if ([item.key isEqualToString:@"WaypipeSSHPassword"]) {
      currentPassword = prefs.waypipeSSHPassword;
    } else if ([item.key isEqualToString:@"WaypipeSSHKeyPassphrase"]) {
      currentPassword = prefs.waypipeSSHKeyPassphrase;
    }
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:item.title
                         message:item.desc
                  preferredStyle:UIAlertControllerStyleAlert];

    __block UITextField *passwordField = nil;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
      passwordField = textField;
      textField.secureTextEntry = YES;
      textField.placeholder = @"Enter password";
      textField.text = currentPassword; // Show current password (will be masked)
      
      // Add show/hide toggle button
      UIButton *toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
      [toggleButton setImage:[UIImage systemImageNamed:@"eye"] forState:UIControlStateNormal];
      [toggleButton setImage:[UIImage systemImageNamed:@"eye.slash"] forState:UIControlStateSelected];
      toggleButton.frame = CGRectMake(0, 0, 30, 30);
      toggleButton.contentMode = UIViewContentModeCenter;
      [toggleButton addTarget:self action:@selector(togglePasswordVisibility:) forControlEvents:UIControlEventTouchUpInside];
      
      // Store reference to text field in button for toggling
      objc_setAssociatedObject(toggleButton, "passwordField", textField, OBJC_ASSOCIATION_ASSIGN);
      
      textField.rightView = toggleButton;
      textField.rightViewMode = UITextFieldViewModeAlways;
    }];

    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    UIAlertAction *saveAction = [UIAlertAction
        actionWithTitle:@"Save"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                  NSString *value = passwordField.text;
                  
                  if ([item.key isEqualToString:@"WaypipeSSHPassword"]) {
                    prefs.waypipeSSHPassword = value;
                  } else if ([item.key isEqualToString:@"WaypipeSSHKeyPassphrase"]) {
                    prefs.waypipeSSHKeyPassphrase = value;
                  }
                  
                  // Reload the table view to show updated value
                  [tv reloadRowsAtIndexPaths:@[ ip ]
                            withRowAnimation:UITableViewRowAnimationNone];
                }];

    [alert addAction:cancelAction];
    [alert addAction:saveAction];

    [self presentViewController:alert animated:YES completion:nil];
  } else if (item.type == WSettingInfo) {
    // For info items, show copy dialog
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    if (!val) {
      val = item.defaultValue;
    }
    NSString *valueString = [val description];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:item.title
                         message:[NSString stringWithFormat:@"%@\n\n%@",
                                                            item.desc,
                                                            valueString]
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *copyAction = [UIAlertAction
        actionWithTitle:@"Copy"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                  pasteboard.string = valueString;
                }];

    UIAlertAction *okAction =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleCancel
                               handler:nil];

    [alert addAction:copyAction];
    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
  } else if (item.type == WSettingPopup) {
    // Present popup selection
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:item.title
                         message:item.desc
                  preferredStyle:UIAlertControllerStyleActionSheet];

    id currentValue =
        [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    if (!currentValue) {
      currentValue = item.defaultValue;
    }
    
    // Special handling for Auth Method: convert integer to string for comparison
    NSString *currentValueString = nil;
    NSInteger currentIndex = -1;
    if ([item.key isEqualToString:@"WaypipeSSHAuthMethod"]) {
      currentIndex = [currentValue isKindOfClass:[NSNumber class]] ? [currentValue integerValue] : 0;
      if (currentIndex >= 0 && currentIndex < item.options.count) {
        currentValueString = item.options[currentIndex];
      } else {
        currentValueString = item.options[0]; // Default to "Password"
        currentIndex = 0;
      }
    } else {
      currentValueString = [currentValue description];
    }

    for (NSInteger i = 0; i < item.options.count; i++) {
      NSString *option = item.options[i];
      NSString *optionCopy = option; // Capture for block
      NSInteger optionIndex = i; // Capture index for block
      UIAlertAction *optionAction = [UIAlertAction
          actionWithTitle:option
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *alertAction) {
                    // For Auth Method, store as integer index
                    if ([item.key isEqualToString:@"WaypipeSSHAuthMethod"]) {
                      [[NSUserDefaults standardUserDefaults] setInteger:optionIndex
                                                                   forKey:item.key];
                    } else {
                      [[NSUserDefaults standardUserDefaults] setObject:optionCopy
                                                                  forKey:item.key];
                    }
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    // Reload the table view to show updated value
                    [tv reloadRowsAtIndexPaths:@[ ip ]
                              withRowAnimation:UITableViewRowAnimationNone];
                  }];

      // Mark current selection with checkmark
      if ([item.key isEqualToString:@"WaypipeSSHAuthMethod"]) {
        if (i == currentIndex) {
          [optionAction setValue:@YES forKey:@"checked"];
        }
      } else {
        if ([option isEqualToString:currentValueString]) {
          [optionAction setValue:@YES forKey:@"checked"];
        }
      }

      [alert addAction:optionAction];
    }

    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    [alert addAction:cancelAction];

    // For iPad, we need to set the popover presentation
    if (alert.popoverPresentationController) {
      UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
      alert.popoverPresentationController.sourceView = cell;
      alert.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
  } else if (item.actionBlock) {
    item.actionBlock();
  }
}

#else

// MARK: - macOS Interface

- (void)showPreferences:(id)sender {
  if (self.winController) {
    [self.winController.window makeKeyAndOrderFront:sender];
    return;
  }

  NSWindow *win = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 700, 500)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  win.title = @"Wawona Settings";
  win.titleVisibility = NSWindowTitleVisible;
  win.titlebarAppearsTransparent = YES;
  win.styleMask |= NSWindowStyleMaskFullSizeContentView;
  win.movableByWindowBackground = YES;

  // Add Toolbar (Liquid Glass Style)
  NSToolbar *toolbar =
      [[NSToolbar alloc] initWithIdentifier:@"WawonaPreferencesToolbar"];
  toolbar.delegate = self;
  toolbar.displayMode = NSToolbarDisplayModeIconOnly;
  win.toolbar = toolbar;

  NSVisualEffectView *v =
      [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 700, 500)];
  v.material = NSVisualEffectMaterialSidebar;
  v.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  v.state = NSVisualEffectStateActive;
  win.contentView = v;

  self.sidebar = [[WawonaPreferencesSidebar alloc] init];
  self.sidebar.parent = self;
  self.content = [[WawonaPreferencesContent alloc] init];

  self.splitVC = [[NSSplitViewController alloc] init];
  NSSplitViewItem *sItem =
      [NSSplitViewItem sidebarWithViewController:self.sidebar];
  sItem.minimumThickness = 130;
  sItem.maximumThickness = 160;
  NSSplitViewItem *cItem =
      [NSSplitViewItem contentListWithViewController:self.content];
  [self.splitVC addSplitViewItem:sItem];
  [self.splitVC addSplitViewItem:cItem];

  // Embed SplitVC in Visual Effect View
  self.splitVC.view.frame = v.bounds;
  self.splitVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [v addSubview:self.splitVC.view];

  self.winController = [[NSWindowController alloc] initWithWindow:win];
  [win center];
  [win makeKeyAndOrderFront:sender];

  if (self.sections.count > 0) {
    [self.sidebar.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                          byExtendingSelection:NO];
  }
}

- (void)showSection:(NSInteger)idx {
  self.content.section = self.sections[idx];
  [self.content.tableView reloadData];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:
    (NSToolbar *)toolbar {
  return @[
    @"com.apple.NSToolbar.toggleSidebar", NSToolbarFlexibleSpaceItemIdentifier
  ];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:
    (NSToolbar *)toolbar {
  return @[ @"com.apple.NSToolbar.toggleSidebar" ];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
        itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag {
  if ([itemIdentifier isEqualToString:@"com.apple.NSToolbar.toggleSidebar"]) {
    NSToolbarItem *item =
        [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.label = @"Toggle Sidebar";
    item.paletteLabel = @"Toggle Sidebar";
    item.toolTip = @"Toggle Sidebar";
    item.image = [NSImage imageWithSystemSymbolName:@"sidebar.left"
                           accessibilityDescription:nil];
    item.target = nil; // First Responder
    item.action = @selector(toggleSidebar:);
    return item;
  }
  return nil;
}

- (void)toggleSidebar:(id)sender {
  [NSApp sendAction:@selector(toggleSidebar:) to:nil from:sender];
}

#endif

- (void)togglePasswordVisibility:(UIButton *)sender {
  UITextField *textField = objc_getAssociatedObject(sender, "passwordField");
  if (textField) {
    textField.secureTextEntry = !textField.secureTextEntry;
    sender.selected = !textField.secureTextEntry;
  }
}

- (void)previewWaypipeCommand {
  NSString *cmdString = [[WawonaWaypipeRunner sharedRunner]
      generatePreviewString:[WawonaPreferencesManager sharedManager]];

#if TARGET_OS_OSX
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Waypipe Command Preview";
  alert.informativeText = cmdString;
  [alert addButtonWithTitle:@"Copy"];
  [alert addButtonWithTitle:@"OK"];
  NSModalResponse response = [alert runModal];

  if (response == NSAlertFirstButtonReturn) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:cmdString forType:NSPasteboardTypeString];
  }
#else
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"Waypipe Command Preview"
                                          message:cmdString
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *copyAction = [UIAlertAction
      actionWithTitle:@"Copy"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *_Nonnull action) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = cmdString;
              }];

  UIAlertAction *okAction =
      [UIAlertAction actionWithTitle:@"OK"
                               style:UIAlertActionStyleCancel
                             handler:nil];

  [alert addAction:copyAction];
  [alert addAction:okAction];

  [self presentViewController:alert animated:YES completion:nil];
#endif
}

@end

// MARK: - Helper Implementations

#if !TARGET_OS_IPHONE

@implementation WawonaPreferencesSidebar
- (void)loadView {
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 400)];
  self.view = v;
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:v.bounds];
  sv.drawsBackground = NO;
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.outlineView = [[NSOutlineView alloc] initWithFrame:sv.bounds];
  self.outlineView.dataSource = self;
  self.outlineView.delegate = self;
  self.outlineView.headerView = nil;
  self.outlineView.rowHeight = 28.0; // Standard sidebar height
  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"M"];
  [self.outlineView addTableColumn:col];
  self.outlineView.outlineTableColumn = col;
  sv.documentView = self.outlineView;
  [v addSubview:sv];
}
- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
  return item ? 0 : self.parent.sections.count;
}
- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
  return NO;
}
- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item {
  return self.parent.sections[idx];
}
- (NSView *)outlineView:(NSOutlineView *)ov
     viewForTableColumn:(NSTableColumn *)tc
                   item:(id)item {
  WawonaPreferencesSection *s = item;
  NSTableCellView *cell = [ov makeViewWithIdentifier:@"Cell" owner:self];
  if (!cell) {
    cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 28)];
    cell.identifier = @"Cell";

    NSImageView *iv = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:iv];
    cell.imageView = iv;

    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSZeroRect];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.bordered = NO;
    tf.drawsBackground = NO;
    tf.editable = NO;
    [tf setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                 forOrientation:
                                     NSLayoutConstraintOrientationHorizontal]; // Allow truncation if needed
    [cell addSubview:tf];
    cell.textField = tf;

    [NSLayoutConstraint activateConstraints:@[
      [iv.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:5],
      [iv.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
      [iv.widthAnchor constraintEqualToConstant:20],
      [iv.heightAnchor constraintEqualToConstant:20],

      [tf.leadingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:5],
      [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor
                                        constant:-5],
      [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
    ]];
  }
  cell.imageView.image =
      [NSImage imageWithSystemSymbolName:s.icon accessibilityDescription:nil];
  cell.imageView.contentTintColor = s.iconColor;
  cell.textField.stringValue = s.title;
  return cell;
}
- (void)outlineViewSelectionDidChange:(NSNotification *)n {
  NSInteger row = self.outlineView.selectedRow;
  if (row >= 0)
    [self.parent showSection:row];
}
@end

// MARK: - WawonaPreferenceCell
// A robust, statically laid-out cell to prevent visual corruption and reduce
// LOC.
@interface WawonaPreferenceCell : NSTableCellView
@property(strong) NSTextField *titleLabel;
@property(strong) NSTextField *descLabel;
@property(strong) NSSwitch *switchControl;
@property(strong) NSTextField *textControl;
@property(strong) NSButton *buttonControl;
@property(strong) NSPopUpButton *popupControl;
@property(strong) WawonaSettingItem *item;
@end

@implementation WawonaPreferenceCell
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.identifier = @"PCell";

    _titleLabel = [NSTextField labelWithString:@""];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [NSFont systemFontOfSize:13];
    _titleLabel.textColor = [NSColor labelColor];
    [_titleLabel
        setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                 forOrientation:
                                     NSLayoutConstraintOrientationVertical];
    [self addSubview:_titleLabel];

    _descLabel = [NSTextField labelWithString:@""];
    _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descLabel.font = [NSFont systemFontOfSize:11];
    _descLabel.textColor = [NSColor secondaryLabelColor];
    [_descLabel
        setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                 forOrientation:
                                     NSLayoutConstraintOrientationVertical];
    [self addSubview:_descLabel];

    // Initialize all potential controls hidden
    _switchControl = [[NSSwitch alloc] init];
    _switchControl.translatesAutoresizingMaskIntoConstraints = NO;
    _switchControl.hidden = YES;
    [self addSubview:_switchControl];

    _textControl = [[NSTextField alloc] init];
    _textControl.translatesAutoresizingMaskIntoConstraints = NO;
    _textControl.hidden = YES;
    [self addSubview:_textControl];

    _buttonControl = [NSButton buttonWithTitle:@"Run" target:nil action:nil];
    _buttonControl.translatesAutoresizingMaskIntoConstraints = NO;
    _buttonControl.bezelStyle = NSBezelStyleRounded;
    _buttonControl.hidden = YES;
    [self addSubview:_buttonControl];

    _popupControl =
        [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _popupControl.translatesAutoresizingMaskIntoConstraints = NO;
    _popupControl.hidden = YES;
    [self addSubview:_popupControl];

    // Static Auto Layout
    [NSLayoutConstraint activateConstraints:@[
      [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                constant:20],
      [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],

      [_descLabel.leadingAnchor
          constraintEqualToAnchor:_titleLabel.leadingAnchor],
      [_descLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor
                                           constant:2],

      // Anchoring controls to trailing edge
      [_switchControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                    constant:-20],
      [_switchControl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

      [_textControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                  constant:-20],
      [_textControl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_textControl.widthAnchor constraintEqualToConstant:120],

      [_buttonControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                    constant:-20],
      [_buttonControl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

      [_popupControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                   constant:-20],
      [_popupControl.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
      [_popupControl.widthAnchor constraintEqualToConstant:100],

      // Prevent Overlap (Leading <-> Control)
      [_titleLabel.trailingAnchor
          constraintLessThanOrEqualToAnchor:_switchControl.leadingAnchor
                                   constant:-10],
      [_titleLabel.trailingAnchor
          constraintLessThanOrEqualToAnchor:_textControl.leadingAnchor
                                   constant:-10],
      [_titleLabel.trailingAnchor
          constraintLessThanOrEqualToAnchor:_buttonControl.leadingAnchor
                                   constant:-10],
      [_titleLabel.trailingAnchor
          constraintLessThanOrEqualToAnchor:_popupControl.leadingAnchor
                                   constant:-10],
    ]];
  }
  return self;
}

- (void)configureWithItem:(WawonaSettingItem *)item
                   target:(id)target
                   action:(SEL)action {
  self.item = item;
  self.titleLabel.stringValue = item.title;
  self.descLabel.stringValue = item.desc ? item.desc : @"";

  // Reset Visibility
  self.switchControl.hidden = YES;
  self.textControl.hidden = YES;
  self.buttonControl.hidden = YES;
  self.popupControl.hidden = YES;

  NSControl *active = nil;

  if (item.type == WSettingSwitch) {
    self.switchControl.hidden = NO;
    self.switchControl.state =
        [[NSUserDefaults standardUserDefaults] boolForKey:item.key]
            ? NSControlStateValueOn
            : NSControlStateValueOff;
    self.switchControl.target = target;
    self.switchControl.action = action;
    active = self.switchControl;
  } else if (item.type == WSettingText || item.type == WSettingNumber) {
    self.textControl.hidden = NO;
    NSString *val =
        [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
    self.textControl.stringValue = val ? val : [item.defaultValue description];
    self.textControl.target = target;
    self.textControl.action = action;
    active = self.textControl;
  } else if (item.type == WSettingPassword) {
    self.textControl.hidden = NO;
    // For password fields, get from Keychain
    WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
    NSString *password = nil;
    if ([item.key isEqualToString:@"WaypipeSSHPassword"]) {
      password = prefs.waypipeSSHPassword;
    } else if ([item.key isEqualToString:@"WaypipeSSHKeyPassphrase"]) {
      password = prefs.waypipeSSHKeyPassphrase;
    }
    // Show dots if password exists (but don't show actual password)
    if (password && password.length > 0) {
      self.textControl.stringValue = @"••••••••";
    } else {
      self.textControl.stringValue = @"";
    }
    // Ensure it's a secure text field
    if (![self.textControl.cell isKindOfClass:[NSSecureTextFieldCell class]]) {
      NSSecureTextFieldCell *secureCell = [[NSSecureTextFieldCell alloc] init];
      secureCell.placeholderString = @"Enter password";
      self.textControl.cell = secureCell;
    }
    self.textControl.target = target;
    self.textControl.action = action;
    active = self.textControl;
  } else if (item.type == WSettingButton) {
    self.buttonControl.hidden = NO;
    self.buttonControl.target = target;
    self.buttonControl.action = action;
    active = self.buttonControl;
  } else if (item.type == WSettingPopup) {
    self.popupControl.hidden = NO;
    [self.popupControl removeAllItems];
    [self.popupControl addItemsWithTitles:item.options];
    NSString *val =
        [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
    [self.popupControl selectItemWithTitle:val ? val : item.defaultValue];
    self.popupControl.target = target;
    self.popupControl.action = action;
    active = self.popupControl;
  } else if (item.type == WSettingInfo) {
    // Info type: show read-only text with copy button
    self.textControl.hidden = NO;
    NSString *val =
        [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
    self.textControl.stringValue = val ? val : [item.defaultValue description];
    self.textControl.editable = NO;
    self.textControl.selectable = YES;
    self.textControl.bezeled = NO;
    self.textControl.bordered = NO;
    self.textControl.backgroundColor = [NSColor clearColor];
    self.textControl.drawsBackground = NO;
    // Add copy button functionality via right-click or double-click
    active = self.textControl;
  }
}
@end

@interface WawonaSeparatorRowView : NSTableRowView
@end
@implementation WawonaSeparatorRowView
- (void)drawSeparatorInRect:(NSRect)dirtyRect {
  // Draw custom iOS-style separator
  NSRect sRect =
      NSMakeRect(20, 0, self.bounds.size.width - 20, 1.0); // Inset left
  [[NSColor separatorColor] setFill];
  NSRectFill(sRect);
}
@end

@implementation WawonaPreferencesContent
- (void)loadView {
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
  self.view = v;
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:v.bounds];
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.drawsBackground = NO; // Fix Unified Background

  self.tableView = [[NSTableView alloc] initWithFrame:sv.bounds];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  self.tableView.headerView = nil;
  self.tableView.backgroundColor =
      [NSColor clearColor];                           // Fix Unified Background
  self.tableView.gridStyleMask = NSTableViewGridNone; // Custom separators
  self.tableView.intercellSpacing =
      NSMakeSize(0, 0); // Tight packing for custom rows

  NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@"C"];
  c.width = 380;
  [self.tableView addTableColumn:c];
  sv.documentView = self.tableView;
  [v addSubview:sv];
}

// Use custom row view for separators
- (NSTableRowView *)tableView:(NSTableView *)tableView
                rowViewForRow:(NSInteger)row {
  WawonaSeparatorRowView *rv =
      [tableView makeViewWithIdentifier:@"Row" owner:self];
  if (!rv) {
    rv = [[WawonaSeparatorRowView alloc] initWithFrame:NSZeroRect];
    rv.identifier = @"Row";
  }
  return rv;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.section.items.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)tc
                   row:(NSInteger)row {
  WawonaPreferenceCell *cell = [tv makeViewWithIdentifier:@"PCell" owner:self];
  if (!cell) {
    cell =
        [[WawonaPreferenceCell alloc] initWithFrame:NSMakeRect(0, 0, 400, 50)];
  }
  WawonaSettingItem *item = self.section.items[row];
  [cell configureWithItem:item target:self action:@selector(act:)];

  // Ensure tags are set correctly for 'act:' lookup if needed (though we rely
  // on sender usually)
  if (!cell.switchControl.hidden)
    cell.switchControl.tag = row;
  if (!cell.textControl.hidden)
    cell.textControl.tag = row;
  if (!cell.buttonControl.hidden)
    cell.buttonControl.tag = row;
  if (!cell.popupControl.hidden)
    cell.popupControl.tag = row;

  return cell;
}

- (void)act:(id)sender {
  NSInteger row = (NSInteger)[sender tag];
  if (row < 0 || row >= (NSInteger)self.section.items.count) {
    return;
  }

  WawonaSettingItem *item = self.section.items[row];
  if (item.type == WSettingButton) {
    if (item.actionBlock) {
      item.actionBlock();
    }
    return;
  }

  if (item.type == WSettingInfo) {
    // For Info type, copy to clipboard on click
    NSString *val =
        [[NSUserDefaults standardUserDefaults] stringForKey:item.key];
    NSString *valueString = val ? val : [item.defaultValue description];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:valueString forType:NSPasteboardTypeString];
    return;
  }

  id val = nil;
  if ([sender isKindOfClass:[NSSwitch class]]) {
    val = @([(NSSwitch *)sender state] == NSControlStateValueOn);
  } else if ([sender isKindOfClass:[NSTextField class]]) {
    val = [(NSTextField *)sender stringValue];
    // For text fields, save immediately when value changes
    if (val && item.key) {
      if (item.type == WSettingPassword) {
        // Save password to Keychain
        WawonaPreferencesManager *prefs = [WawonaPreferencesManager sharedManager];
        if ([item.key isEqualToString:@"WaypipeSSHPassword"]) {
          prefs.waypipeSSHPassword = val;
        } else if ([item.key isEqualToString:@"WaypipeSSHKeyPassphrase"]) {
          prefs.waypipeSSHKeyPassphrase = val;
        }
      } else {
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:item.key];
        [[NSUserDefaults standardUserDefaults] synchronize];
      }
    }
    return; // Return early for text fields - they save on each change
  } else if ([sender isKindOfClass:[NSPopUpButton class]]) {
    val = [(NSPopUpButton *)sender titleOfSelectedItem];
  }

  if (val && item.key) {
    [[NSUserDefaults standardUserDefaults] setObject:val forKey:item.key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"WawonaPreferencesChanged"
                      object:nil];
  }
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)row {
  return 50.0;
}

@end

#endif
