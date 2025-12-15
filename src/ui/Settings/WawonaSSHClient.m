#import "WawonaSSHClient.h"
#import <libssh2.h>
#import <Network/Network.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <fcntl.h>
#import <unistd.h>
#import <string.h>
#import <errno.h>
#import <Security/Security.h>

@interface WawonaSSHClient ()
{
  LIBSSH2_SESSION *_session;
  int _sock;
  BOOL _isConnected;
  BOOL _isAuthenticated;
}

@end

@implementation WawonaSSHClient

- (instancetype)initWithHost:(NSString *)host username:(NSString *)username port:(NSInteger)port {
  self = [super init];
  if (self) {
    _host = [host copy];
    _username = [username copy];
    _port = port > 0 ? port : 22;
    _connectionTimeout = 30.0;
    _readTimeout = 10.0;
    _authMethod = WawonaSSHAuthMethodPassword;
    _session = NULL;
    _sock = -1;
    _isConnected = NO;
    _isAuthenticated = NO;
  }
  return self;
}

- (void)dealloc {
  [self disconnect];
}

- (BOOL)connect:(NSError **)error {
  if (_isConnected) {
    return YES;
  }

  // Initialize libssh2
  int rc = libssh2_init(0);
  if (rc != 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to initialize libssh2: %d", rc]}];
    }
    return NO;
  }

  // Use Network.framework for hostname resolution, then BSD socket for connection
  // (libssh2 requires a file descriptor, which Network.framework doesn't provide)
  nw_endpoint_t endpoint = nw_endpoint_create_host([_host UTF8String], [[NSString stringWithFormat:@"%ld", (long)_port] UTF8String]);
  
  // Resolve endpoint to get address (using Network.framework for modern resolution)
  // But we'll use BSD socket for the actual connection since libssh2 needs a file descriptor
  struct addrinfo hints, *result = NULL;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  
  int gai_result = getaddrinfo([_host UTF8String], [[NSString stringWithFormat:@"%ld", (long)_port] UTF8String], &hints, &result);
  if (gai_result != 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:gai_result
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to resolve hostname: %s", gai_strerror(gai_result)]}];
    }
    libssh2_exit();
    return NO;
  }

  // Create socket
  _sock = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
  if (_sock < 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create socket: %s", strerror(errno)]}];
    }
    freeaddrinfo(result);
    libssh2_exit();
    return NO;
  }

  // Connect with timeout using Network.framework path monitoring
  // Set socket to non-blocking for timeout handling
  int flags = fcntl(_sock, F_GETFL, 0);
  fcntl(_sock, F_SETFL, flags | O_NONBLOCK);
  
  int connect_result = connect(_sock, result->ai_addr, result->ai_addrlen);
  freeaddrinfo(result);
  
  if (connect_result < 0 && errno != EINPROGRESS) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to connect: %s", strerror(errno)]}];
    }
    close(_sock);
    _sock = -1;
    libssh2_exit();
    return NO;
  }
  
  // Wait for connection with timeout
  fd_set writefds;
  struct timeval tv;
  FD_ZERO(&writefds);
  FD_SET(_sock, &writefds);
  tv.tv_sec = (long)_connectionTimeout;
  tv.tv_usec = 0;
  
  int select_result = select(_sock + 1, NULL, &writefds, NULL, &tv);
  if (select_result <= 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:ETIMEDOUT
                                userInfo:@{NSLocalizedDescriptionKey: @"Connection timeout"}];
    }
    close(_sock);
    _sock = -1;
    libssh2_exit();
    return NO;
  }
  
  // Check if connection succeeded
  int so_error = 0;
  socklen_t len = sizeof(so_error);
  if (getsockopt(_sock, SOL_SOCKET, SO_ERROR, &so_error, &len) != 0 || so_error != 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:so_error
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Connection failed: %s", strerror(so_error)]}];
    }
    close(_sock);
    _sock = -1;
    libssh2_exit();
    return NO;
  }
  
  // Set back to blocking mode for libssh2
  flags = fcntl(_sock, F_GETFL, 0);
  fcntl(_sock, F_SETFL, flags & ~O_NONBLOCK);

  // Create libssh2 session
  _session = libssh2_session_init();
  if (!_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize SSH session"}];
    }
    close(_sock);
    _sock = -1;
    libssh2_exit();
    return NO;
  }

  // Set blocking mode
  libssh2_session_set_blocking(_session, 1);

  // Perform SSH handshake
  rc = libssh2_session_handshake(_session, _sock);
  if (rc != 0) {
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"SSH handshake failed: %s", errmsg ?: "Unknown error"]}];
    }
    libssh2_session_free(_session);
    _session = NULL;
    close(_sock);
    _sock = -1;
    libssh2_exit();
    return NO;
  }

  _isConnected = YES;
  
  if ([self.delegate respondsToSelector:@selector(sshClientDidConnect:)]) {
    [self.delegate sshClientDidConnect:self];
  }

  return YES;
}

- (BOOL)authenticate:(NSError **)error {
  if (!_isConnected || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not connected"}];
    }
    return NO;
  }

  if (_isAuthenticated) {
    return YES;
  }

  int rc = 0;

  switch (_authMethod) {
    case WawonaSSHAuthMethodPassword: {
      if (!_password) {
        if (error) {
          *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Password not provided"}];
        }
        return NO;
      }
      
      rc = libssh2_userauth_password(_session, [_username UTF8String], [_password UTF8String]);
      if (rc != 0) {
        if (error) {
          char *errmsg = NULL;
          libssh2_session_last_error(_session, &errmsg, NULL, 0);
          *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                        code:rc
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Password authentication failed: %s", errmsg ?: "Unknown error"]}];
        }
        return NO;
      }
      break;
    }
    
    case WawonaSSHAuthMethodPublicKey: {
      if (!_privateKeyPath) {
        if (error) {
          *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Private key path not provided"}];
        }
        return NO;
      }

      const char *publicKeyPath = NULL;
      if (_publicKeyPath) {
        publicKeyPath = [_publicKeyPath UTF8String];
      } else {
        // Try to auto-detect public key (common patterns)
        NSString *privateKeyDir = [_privateKeyPath stringByDeletingLastPathComponent];
        NSString *privateKeyName = [[_privateKeyPath lastPathComponent] stringByDeletingPathExtension];
        NSString *possiblePubKey = [[privateKeyDir stringByAppendingPathComponent:privateKeyName] stringByAppendingPathExtension:@"pub"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:possiblePubKey]) {
          publicKeyPath = [possiblePubKey UTF8String];
        }
      }

      const char *passphrase = _keyPassphrase ? [_keyPassphrase UTF8String] : NULL;
      
      rc = libssh2_userauth_publickey_fromfile(_session,
                                               [_username UTF8String],
                                               publicKeyPath,
                                               [_privateKeyPath UTF8String],
                                               passphrase);
      if (rc != 0) {
        if (error) {
          char *errmsg = NULL;
          libssh2_session_last_error(_session, &errmsg, NULL, 0);
          *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                        code:rc
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Public key authentication failed: %s", errmsg ?: "Unknown error"]}];
        }
        return NO;
      }
      break;
    }
  }

  _isAuthenticated = YES;
  return YES;
}

- (void)disconnect {
  if (_session) {
    libssh2_session_disconnect(_session, "Normal Shutdown");
    libssh2_session_free(_session);
    _session = NULL;
  }
  
  if (_sock >= 0) {
    close(_sock);
    _sock = -1;
  }
  
  libssh2_exit();
  
  _isConnected = NO;
  _isAuthenticated = NO;
  
  if ([self.delegate respondsToSelector:@selector(sshClientDidDisconnect:)]) {
    [self.delegate sshClientDidDisconnect:self];
  }
}

- (BOOL)executeCommand:(NSString *)command output:(NSString **)output error:(NSError **)error {
  if (!_isAuthenticated || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not authenticated"}];
    }
    return NO;
  }

  LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(_session);
  if (!channel) {
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open channel: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  int rc = libssh2_channel_exec(channel, [command UTF8String]);
  if (rc != 0) {
    libssh2_channel_free(channel);
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to execute command"}];
    }
    return NO;
  }

  // Read output
  NSMutableData *outputData = [NSMutableData data];
  char buffer[4096];
  
  while (1) {
    ssize_t n = libssh2_channel_read(channel, buffer, sizeof(buffer));
    if (n > 0) {
      [outputData appendBytes:buffer length:n];
    } else if (n == 0) {
      break;
    } else {
      if (n != LIBSSH2_ERROR_EAGAIN) {
        break;
      }
    }
  }

  int exitStatus = libssh2_channel_get_exit_status(channel);
  libssh2_channel_close(channel);
  libssh2_channel_free(channel);
  
  NSLog(@"[SSH] Command exit status: %d", exitStatus);

  if (output) {
    *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
  }

  if (exitStatus != 0 && error) {
    *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                  code:exitStatus
                              userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Command exited with status %d", exitStatus]}];
    return NO;
  }

  return YES;
}

- (BOOL)forwardLocalPort:(NSInteger)localPort toRemoteHost:(NSString *)remoteHost remotePort:(NSInteger)remotePort error:(NSError **)error {
  if (!_isAuthenticated || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not authenticated"}];
    }
    return NO;
  }

  // Create listening socket on local port
  int listenSock = socket(AF_INET, SOCK_STREAM, 0);
  if (listenSock < 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create listening socket: %s", strerror(errno)]}];
    }
    return NO;
  }

  int opt = 1;
  setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

  struct sockaddr_in sin;
  sin.sin_family = AF_INET;
  sin.sin_port = htons((uint16_t)localPort);
  sin.sin_addr.s_addr = INADDR_ANY;

  if (bind(listenSock, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
    close(listenSock);
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to bind local port: %s", strerror(errno)]}];
    }
    return NO;
  }

  if (listen(listenSock, 1) < 0) {
    close(listenSock);
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to listen: %s", strerror(errno)]}];
    }
    return NO;
  }

  // Accept connection
  struct sockaddr_in clientAddr;
  socklen_t clientLen = sizeof(clientAddr);
  int clientSock = accept(listenSock, (struct sockaddr *)&clientAddr, &clientLen);
  close(listenSock);

  if (clientSock < 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to accept connection: %s", strerror(errno)]}];
    }
    return NO;
  }

  // Forward to remote
  LIBSSH2_CHANNEL *channel = libssh2_channel_direct_tcpip(_session, [remoteHost UTF8String], (int)remotePort);
  if (!channel) {
    close(clientSock);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create forwarding channel: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  // TODO: Implement bidirectional forwarding in background thread
  // For now, this is a basic implementation
  // In a real implementation, you'd want to handle data transfer in both directions
  
  libssh2_channel_close(channel);
  libssh2_channel_free(channel);
  close(clientSock);

  return YES;
}

- (int)createShellChannel:(NSError **)error {
  if (!_isAuthenticated || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not authenticated"}];
    }
    return -1;
  }

  LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(_session);
  if (!channel) {
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open channel: %s", errmsg ?: "Unknown error"]}];
    }
    return -1;
  }

  // Request a shell (not exec - this keeps the channel open)
  int rc = libssh2_channel_shell(channel);
  if (rc != 0) {
    libssh2_channel_free(channel);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to request shell: %s", errmsg ?: "Unknown error"]}];
    }
    return -1;
  }

  // Get the file descriptor for the channel
  // Note: libssh2 doesn't directly provide a file descriptor for channels
  // We need to use the underlying socket
  return _sock;
}

- (int)socketFileDescriptor {
  return _sock;
}

- (BOOL)createBidirectionalChannelWithLocalFD:(int *)localFd remoteFD:(int *)remoteFd error:(NSError **)error {
  if (!_isAuthenticated || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not authenticated"}];
    }
    return NO;
  }

  // Create a socket pair for bidirectional communication
  int socketPair[2];
  if (socketpair(AF_UNIX, SOCK_STREAM, 0, socketPair) != 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create socket pair: %s", strerror(errno)]}];
    }
    return NO;
  }

  // Open an SSH channel
  LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(_session);
  if (!channel) {
    close(socketPair[0]);
    close(socketPair[1]);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open channel: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  // Request a shell (this keeps the channel open for bidirectional communication)
  int rc = libssh2_channel_shell(channel);
  if (rc != 0) {
    libssh2_channel_free(channel);
    close(socketPair[0]);
    close(socketPair[1]);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to request shell: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  // Return the local socket (for waypipe) and store the channel for forwarding
  // Note: We'd need to implement bidirectional forwarding in a background thread
  // For now, just return the socket pair
  if (localFd) *localFd = socketPair[0];
  if (remoteFd) *remoteFd = socketPair[1]; // This would be used for forwarding to/from the SSH channel
  
  // TODO: Implement bidirectional data forwarding between socketPair[1] and the SSH channel
  // This requires a background thread that reads from one and writes to the other
  
  return YES;
}

- (BOOL)startTunnelForCommand:(NSString *)command localSocket:(int *)localSocket error:(NSError **)error {
  if (!_isAuthenticated || !_session) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: @"Not authenticated"}];
    }
    return NO;
  }

  // Create a socket pair
  int socketPair[2];
  if (socketpair(AF_UNIX, SOCK_STREAM, 0, socketPair) != 0) {
    if (error) {
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:errno
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create socket pair: %s", strerror(errno)]}];
    }
    return NO;
  }

  // Open SSH channel
  LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(_session);
  if (!channel) {
    close(socketPair[0]);
    close(socketPair[1]);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open channel: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  // Exec command or shell
  int rc;
  if (command) {
    rc = libssh2_channel_exec(channel, [command UTF8String]);
  } else {
    rc = libssh2_channel_shell(channel);
  }

  if (rc != 0) {
    libssh2_channel_free(channel);
    close(socketPair[0]);
    close(socketPair[1]);
    if (error) {
      char *errmsg = NULL;
      libssh2_session_last_error(_session, &errmsg, NULL, 0);
      *error = [NSError errorWithDomain:@"WawonaSSHClient"
                                    code:rc
                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to start command: %s", errmsg ?: "Unknown error"]}];
    }
    return NO;
  }

  // Start forwarding loop
  // We pass the REMOTE side of the socket pair (socketPair[1]) to the loop
  // The caller gets the LOCAL side (socketPair[0])
  [self startForwardingLoopForChannel:channel socket:socketPair[1]];

  if (localSocket) {
    *localSocket = socketPair[0];
  } else {
    close(socketPair[0]);
  }

  return YES;
}

- (void)startForwardingLoopForChannel:(LIBSSH2_CHANNEL *)channel socket:(int)fd {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char buffer[32768];
        ssize_t nread;
        ssize_t nwritten;
        
        // Set session to non-blocking for this loop
        // Note: This assumes exclusive access to the session by this thread!
        libssh2_session_set_blocking(self->_session, 0);
        
        fd_set fds;
        struct timeval tv;
        
        while (self->_isConnected && channel) {
            FD_ZERO(&fds);
            FD_SET(fd, &fds);
            FD_SET(self->_sock, &fds);
            
            tv.tv_sec = 0;
            tv.tv_usec = 100000; // 100ms
            
            int maxfd = (fd > self->_sock) ? fd : self->_sock;
            int rc = select(maxfd + 1, &fds, NULL, NULL, &tv);
            
            if (rc < 0) {
                if (errno == EINTR) continue;
                break; // Error
            }
            
            // 1. Read from local socket -> Write to SSH channel
            if (FD_ISSET(fd, &fds)) {
                nread = read(fd, buffer, sizeof(buffer));
                if (nread <= 0) break; // EOF or error from local side
                
                char *ptr = buffer;
                size_t remaining = nread;
                while (remaining > 0) {
                    nwritten = libssh2_channel_write(channel, ptr, remaining);
                    if (nwritten < 0) {
                        if (nwritten == LIBSSH2_ERROR_EAGAIN) {
                            usleep(1000);
                            continue;
                        }
                        goto cleanup;
                    }
                    ptr += nwritten;
                    remaining -= nwritten;
                }
            }
            
            // 2. Read from SSH channel -> Write to local socket
            while (1) {
                nread = libssh2_channel_read(channel, buffer, sizeof(buffer));
                if (nread == LIBSSH2_ERROR_EAGAIN) break; // No more data
                if (nread < 0) goto cleanup; // Error
                if (nread == 0) goto cleanup; // EOF
                
                char *ptr = buffer;
                size_t remaining = nread;
                while (remaining > 0) {
                    nwritten = write(fd, ptr, remaining);
                    if (nwritten < 0) {
                        if (errno == EAGAIN || errno == EINTR) continue;
                        goto cleanup;
                    }
                    ptr += nwritten;
                    remaining -= nwritten;
                }
            }
            
            if (libssh2_channel_eof(channel)) {
                goto cleanup;
            }
        }
        
    cleanup:
        int exitStatus = libssh2_channel_get_exit_status(channel);
        NSLog(@"[SSH] Tunnel closed. Exit status: %d", exitStatus);
        
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        close(fd);
    });
}


@end
