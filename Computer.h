#import "Preferences.h"
#import "GCDAsyncSocket.h"

@class NotificationSynchronizer;

@interface Computer : NSObject <GCDAsyncSocketDelegate> {
	NSMutableArray* queue;
	NSMutableDictionary* sync;
	
	BOOL running;
	BOOL done;
	BOOL valid;
}

@property NSString* host;

-(instancetype)initWithHost:(NSString*)hostAddress;

-(void)send:(NSString*)command withParameters:(NSString*)parameters;
@end