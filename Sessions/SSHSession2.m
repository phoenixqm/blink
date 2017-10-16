#include <libssh/libssh.h>

#import "SSHSession2.h"

@interface SSHSession2 ()
@end

@implementation SSHSession2 {
  ssh_session _session;
}

- (int)main:(int)argc argv:(char **)argv
{
  _session = ssh_new();
  if (_session == NULL) {
    return [self dieMsg:@"Couldn't start ssh session"];
  }
  // TODO: This is for some reason necessary. Maybe we need to setup threads.
  if (!ssh_is_connected(_session)) {
    [self debugMsg:@"Yo!"];
  }
  // TODO: Configure session
  if (ssh_options_set(_session, SSH_OPTIONS_HOST, "localhost") < 0) {
    [self dieMsg:@"Error setting host"];
  }
  if (ssh_options_set(_session, SSH_OPTIONS_USER, "carlos") < 0) {
    [self dieMsg:@"Error setting host"];
  }    
  //ssh_options_set(_session, SSH_OPTIONS_PORT, &port);
  // int verbosity = SSH_LOG_PROTOCOL;
  // ssh_options_set(_session, SSH_OPTIONS_LOG_VERBOSITY, &verbosity);
  // TODO:Log verbosity with callback.
  int rc = ssh_connect(_session);
  if (rc != SSH_OK) {
    // TODO: free on die? how were we doing this before? How about on cleanup of the object?    
    [self dieMsg:@"Error connecting to HOST"];
  }

  // TODO: Authenticate server

  // TODO: Authenticate user
  rc = ssh_userauth_password(_session, NULL, "asdf");
  if (rc != SSH_AUTH_SUCCESS) {
    [self dieMsg:@"Wrong password"];
  }
  // TODO: Channel / Interactive & Non-Interactive Shell
  ssh_disconnect(_session);
  ssh_free(_session);
  return 0;
}

- (int)dieMsg:(NSString *)msg
{
  fprintf(_stream.out, "%s\r\n", [msg UTF8String]);
  return -1;
}

- (void)errMsg:(NSString *)msg
{
  fprintf(_stream.err, "%s\r\n", [msg UTF8String]);
}

- (void)debugMsg:(NSString *)msg
{
  //if (_debug) {
    fprintf(_stream.out, "SSHSession:DEBUG:%s\r\n", [msg UTF8String]);
  //}
}

@end
