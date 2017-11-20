#import "Session.h"
#import "TermDevice.h"


// The TermStream is the PTYDevice
// They might actually be different. The Device listens, the stream is lower level.
// The PTY never listens. The Device or Wigdget is a way to indicate that
@implementation TermDevice {
  // Initialized from stream, and make the stream duplicate itself.
  // The stream then has access to the "device" or "widget"
  // The Widget then has functions to read from the stream and pass it.
  int _pinput[2];
  int _poutput[2];
  int _perror[2];
  struct winsize *_termsz;
  dispatch_io_t _channel;
}

// Creates descriptors
// NO. This should be part of the control. Opens / runs a session on a pty device
//   When creating the session, we pass it the descriptors
// Manages master / slave transparently between the descriptors.
// Replaces fterm
// Signals here too instead of in TermController? Signals might depend on the Session though. How is this done in real UNIX? How is the signal sent to the process if the pty knows nothing?

// TODO: Temporary fix, get rid of the control in the Stream?
// This smells like the Device will have to implement this functions, wrapping the Widget. Wait and see...
- (void)setControl:(TermView *)control
{
  _control = control;
  _stream.control = control;
}

- (id)init
{
  self = [super init];

  if (self) {
    pipe(_pinput);
    pipe(_poutput);
    pipe(_perror);

    // TODO: Change the interface
    // Initialize on the stream
    _stream = [[TermStream alloc] init];
    _stream.in = fdopen(_pinput[0], "r");
    _stream.out = fdopen(_poutput[1], "w");
    _stream.err = fdopen(_perror[1], "w");
    setvbuf(_stream.out, NULL, _IONBF, 0);
    setvbuf(_stream.err, NULL, _IONBF, 0);
    setvbuf(_stream.in, NULL, _IONBF, 0);

    // TODO: Can we take the size outside the stream too?
    // Although in some way the size should belong to the pty.
    _termsz = malloc(sizeof(struct winsize));
    _stream.sz = _termsz;

    // Create channel with a callback
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, _poutput[0],
					       dispatch_get_global_queue(0, 0),
                                               ^(int error) { printf("Error creating channel"); });

    dispatch_io_set_low_water(_channel, 1);
    //dispatch_io_set_high_water(channel, SIZE_MAX);
    // TODO: Get read of the main queue on TermView write. It will always happen here.
    dispatch_io_read(_channel, 0, SIZE_MAX, dispatch_get_global_queue(0,0),
		     ^(bool done, dispatch_data_t data, int error) {
		       NSString *output = [self parseStream: data];
		       // TODO: Change to render
		       [_control write:output];
		     });
  
  }
  
  return self;
}

- (NSString *)parseStream:(dispatch_data_t)data
{
  // TODO: Handle incomplete UTF sequences and other encodings
  NSString *output;
  output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return output;
}

- (void)write:(NSString *)input
{
  const char *str = [input UTF8String];
  write(_pinput[1], str, [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}
	       
- (void)close
{
  // TODO: Close the channel
  // TODO: Closing the streams!! But they are duplicated!!!!
  if (_pinput) {
    fclose(_pinput);    
  }
  if (_poutput) {
    fclose(_poutput);
  }
  if (_perror) {
    fclose(_perror);
  }
  if (_termsz) {
    free(_termsz);
  }
}

- (void)dealloc
{
  [self close];  
}

@end
