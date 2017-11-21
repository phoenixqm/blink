#import <Foundation/Foundation.h>


@interface TermDevice : NSObject

@property (readonly) TermStream *stream;
// TODO: @property TermWidget *control;
@property TermView *control;

- (void)write:(NSString *)input;
@end

