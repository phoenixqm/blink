#include <libssh/libssh.h>
#include <sys/time.h>

#import "SSHSession2.h"

@interface SSHSession2 ()
@end

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
  // TODO: This is for some reason necessary. Maybe we need to setup threads.
  if (!ssh_is_connected(_session)) {
    [self debugMsg:@"Yo!"];
  }
  // TODO: Configure session
  if (ssh_options_set(_session, SSH_OPTIONS_HOST, "25.33.115.47") < 0) {
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
  fd_set fds;
  struct timeval timeout;
  char buffer[4096];
  ssh_buffer readbuf=ssh_buffer_new();
  ssh_channel channels[2];
  int lus;
  int eof=0;
  int maxfd, infd;
  int ret;

  infd = fileno(_stream.in);

  while(_channel) {
    do {
      FD_ZERO(&fds);

      if(!eof) {
	FD_SET(infd, &fds);
      }

      timeout.tv_sec=30;
      timeout.tv_usec=0;
      FD_SET(ssh_get_fd(_session),&fds);
      maxfd=ssh_get_fd(_session)+1;
      ret=select(maxfd,&fds,NULL,NULL,&timeout);

      if(ret==EINTR)
	continue;

      if(FD_ISSET(infd, &fds)){
	lus=read(infd,buffer,sizeof(buffer));
	if(lus)
	  ssh_channel_write(_channel,buffer,lus);
	else {
	  eof=1;
	  ssh_channel_send_eof(_channel);
	}
      }
      if(FD_ISSET(ssh_get_fd(_session),&fds)){
	ssh_set_fd_toread(_session);
      }
      channels[0]=_channel; // set the first channel we want to read from
      channels[1]=NULL;
      ret=ssh_channel_select(channels,NULL,NULL,NULL); // no specific timeout - just poll
      // if(signal_delayed)
      // 	sizechanged();
    } while (ret==EINTR || ret==SSH_EINTR);

    // we already looked for input from stdin. Now, we are looking for input from the channel

    if(_channel && ssh_channel_is_closed(_channel)){
      ssh_channel_free(_channel);
      _channel=NULL;
      channels[0]=NULL;
    }
    if(channels[0]){
      while(_channel && ssh_channel_is_open(_channel) && ssh_channel_poll(_channel,0)>0){
	lus=channel_read_buffer(_channel,readbuf,0,0);
	if(lus==-1){
    [self dieMsg:@"Error reading channel"];
    break;
	  // fprintf(stderr, "Error reading channel: %s\n",
	  // 	  ssh_get_error(session));
	}
	if(lus==0){
	  ssh_channel_free(_channel);
	  _channel=channels[0]=NULL;
	} else
	  if (fwrite(ssh_buffer_get(readbuf),1,lus,_stream.out) < 0) {
	    [self dieMsg:@"Error writing"];
      break;
	  }
      }
    }
    if(_channel && ssh_channel_is_closed(_channel)){
      ssh_channel_free(_channel);
      _channel=NULL;
    }
  }

  ssh_buffer_free(readbuf);
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
