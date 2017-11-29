#include <libssh/libssh.h>
#include <libssh/callbacks.h>
#include <sys/time.h>

#import "SSHSession2.h"

@interface SSHSession2 ()
@end

void loggingEvent(ssh_session session, int priority, const char *message, void *userdata)
{
  printf("%s\n", message);
}

struct ssh_callbacks_struct cb = {
  .userdata = NULL,
  .auth_function = NULL,
  .log_function = loggingEvent
};

@implementation SSHSession2 {
  ssh_session _session;
  ssh_channel _channel;
}

- (int)main:(int)argc argv:(char **)argv
{
  _session = ssh_new();
  if (_session == NULL) {
    return [self dieMsg:@"Couldn't start ssh session"];
  }
  ssh_callbacks_init(&cb);
  ssh_set_callbacks(_session, &cb);
  ssh_set_log_level(100);
  // TODO: This is for some reason necessary. Maybe we need to setup threads.
  if (!ssh_is_connected(_session)) {
    [self debugMsg:@"Yo!"];
  }
  // TODO: Configure session
  if (ssh_options_set(_session, SSH_OPTIONS_HOST, "192.168.128.109") < 0) {
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
    return [self dieMsg:@"Error connecting to HOST"];
  }

  // TODO: Authenticate server

  // TODO: Authenticate user
  rc = ssh_userauth_password(_session, NULL, "carl0sMBP15");
  if (rc != SSH_AUTH_SUCCESS) {
    return [self dieMsg:@"Wrong password"];
  }

  // TODO: Channel / Interactive & Non-Interactive Shell
  _channel = ssh_channel_new(_session);
  if (_channel == NULL) {
    return [self dieMsg:@"Error opening channel"];
  }

  rc = ssh_channel_open_session(_channel);
  if (rc != SSH_OK) {
    return [self dieMsg:@"Error opening channel"];
  }

  rc = ssh_channel_request_pty(_channel);
  if (rc != SSH_OK)
    return [self dieMsg:@"Error requesting remote pty"];

  rc = ssh_channel_change_pty_size(_channel, 80, 80);
  if (rc != SSH_OK)
    return [self dieMsg:@"Error setting pty size"];
  
  rc = ssh_channel_request_shell(_channel);
  if (rc != SSH_OK)
    return [self dieMsg:@"Error requesting shell"];

  [self debugMsg:@"Entering loop"];
  // Probably not needed, closed within the sesison.
  // ssh_channel_close(_channel);
  // ssh_channel_send_eof(_channel);
  // ssh_channel_free(_channel);
  [self loop];

  ssh_disconnect(_session);
  ssh_free(_session);
  return 0;
}

- (void)loop
{
  ssh_connector connector_in, connector_out, connector_err;
  ssh_event event = ssh_event_new();
  
  //  ssh_set_blocking(_session, 0);
  //  ssh_channel_set_blocking(_channel, 0);
  /* stdin */
  connector_in = ssh_connector_new(_session);
  ssh_connector_set_out_channel(connector_in, _channel, SSH_CONNECTOR_STDOUT);
  ssh_connector_set_in_fd(connector_in, fileno(_stream.in));
  ssh_event_add_connector(event, connector_in);

  /* stdout */
  connector_out = ssh_connector_new(_session);
  ssh_connector_set_out_fd(connector_out, fileno(_stream.out));
  ssh_connector_set_in_channel(connector_out, _channel, SSH_CONNECTOR_STDOUT);
  ssh_event_add_connector(event, connector_out);

  /* stderr */
//  connector_err = ssh_connector_new(_session);
//  ssh_connector_set_out_fd(connector_err, fileno(_stream.err));
//  ssh_connector_set_in_channel(connector_err, _channel, SSH_CONNECTOR_STDERR);
//  ssh_event_add_connector(event, connector_err);

  while(1){
    //    if(signal_delayed)
    //      sizechanged();
    ssh_event_dopoll(event, 60000);
  }
  ssh_event_remove_connector(event, connector_in);
  ssh_event_remove_connector(event, connector_out);
  //ssh_event_remove_connector(event, connector_err);

  ssh_connector_free(connector_in);
  ssh_connector_free(connector_out);
  //ssh_connector_free(connector_err);

  ssh_event_free(event);
  ssh_channel_free(_channel);
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

- (void)sigwinch
{
  ssh_channel_change_pty_size(_channel,
			      _stream.sz->ws_col, 
			      _stream.sz->ws_row);
  // libssh2_channel_request_pty_size(_channel,
  // 				   _stream.sz->ws_col,
  // 				   _stream.sz->ws_row);
}

@end
