#import "Computer.h"
#import "Utilities.h"
#import "NotificationSynchronizer.h"

@implementation Computer
@synthesize host;

-(instancetype)initWithHost:(NSString*)hostAddress{
	self = [super init];
	
	queue = [[NSMutableArray alloc] init];
	
	self.host = hostAddress;
	
	return self;
}

//Adds a command with parameters to the queue for them to be sent
-(void)send:(NSString*)command withParameters:(NSString*)parameters{
	NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
	dict[@"command"] = command;
	dict[@"parameters"] = parameters;
	
	[queue addObject:dict];
	
	//Process the queue asynchronously
	dispatch_async([Utilities getProcessingQueue], ^{
		[self processQueue];
	});
}

//Sends each command of the queue to the computer, and closes the connection once finished
-(void)processQueue{
	//Returns if the queue is already being processed
	if(running) return;
	
	running = true;
	
	//Creates a socket and connects it the computer
	GCDAsyncSocket* socket = [self createConnection];
	
	BOOL secondAttempt = false;
	
	//Processes items as long as there are items in the queue
	while(queue.count > 0){
		NSMutableDictionary* dict = [queue objectAtIndex:0];
		
		done = false;
		[socket writeData:[[NSString stringWithFormat:@"[NotifyMe] %@ %@\r", dict[@"command"], dict[@"parameters"]] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
		
		//Wait for the socket to send the message (When the data was sent, the socket:didWriteDataWithTag: function gets called and sets done to true)
		NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:3.0];
		while (!done && [timeout compare: [NSDate date]] == NSOrderedDescending) {
			NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.1];
			[[NSRunLoop currentRunLoop] runUntilDate:date];
		}
		
		//If the data couldn't be sent, assume that the computer is not available anymore and therefore clear the queue and remove this computer from the array
		if(!done){
			[[NotificationSynchronizer sharedInstance] removeComputer:self];
			[queue removeAllObjects];
			running = false;
			return;
		}
		
		done = false;
		
		//Tell the socket to read until a \r character arrives
		[socket readDataToData:[@"\r" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3 tag:1];
		
		//Waits for confirmation of computer (When the computer answers, the socket:didReadData:withTag: function gets called and sets done to true). Additionally; there is a timeout if the computer is no longer available
		timeout = [NSDate dateWithTimeIntervalSinceNow:3.0];
		while (!done && [timeout compare: [NSDate date]] == NSOrderedDescending) {
			NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.1];
			[[NSRunLoop currentRunLoop] runUntilDate:date];
		}
		
		if(!done){
			if(!secondAttempt){
				//When the computer didn't answer in time, try a second time (there may have been a short disconnect from the wifi)
				secondAttempt = true;
				continue;
			} else {
				//When the computer didn't answer twice in a row, assume that the computer is not available anymore and therefore clear the queue and remove this computer from the array
				[[NotificationSynchronizer sharedInstance] removeComputer:self];
				[queue removeAllObjects];
				running = false;
				return;
			}
		}
		
		//If everythong went correctly, remove this entry from the queue and proceed to the next one
		done = false;
		secondAttempt = false;
		[queue removeObjectAtIndex:0];
	}
	
	//Once everything has been processed, send the close message
	[socket writeData:[@"[NotifyMe] CLOSE\r" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
	
	running = false;
}

//Utility for connecting to a computer and verifying the key
-(GCDAsyncSocket*)createConnection{
	GCDAsyncSocket* socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[Utilities getProcessingQueue]];
	
	//Attempt a connection to host
	NSError* error = nil;
	if (![socket connectToHost:host onPort:[[Preferences sharedInstance] getPort] withTimeout:3 error:&error]) {
		[[NotificationSynchronizer sharedInstance] removeComputer:self];
		
		return NULL;
	}
	
	//Wait for connection to computer (When the phone connected, the socket:didConnectToHost:port: function gets called and sets done to true). Additionally there is a timeout, if the computer isn't reachable
	done = false;
	NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:3.0];
	while (!done && [timeout compare: [NSDate date]] == NSOrderedDescending) {
		NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.1];
		[[NSRunLoop currentRunLoop] runUntilDate:date];
	}
	
	//If the computer wasn't reachable remove it from the array of available computers
	if(!done){
		[[NotificationSynchronizer sharedInstance] removeComputer:self];
		
		return NULL;
	}
	
	//Start reading until \r (my separator)
	[socket readDataToData:[@"\r" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3 tag:0];
	
	//Waiting for confirmation of the computer (When the computer answers, the socket:didReadData:withTag: function gets called and sets done to true)
	done = false;
	valid = false;
	timeout = [NSDate dateWithTimeIntervalSinceNow:3.0];
	while (!done && [timeout compare: [NSDate date]] == NSOrderedDescending) {
		NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.1];
		[[NSRunLoop currentRunLoop] runUntilDate:date];
	}
	
	//If the computer didn't answer in time, assume it's unavailable and remove it from the array of available computers
	if(!done) {
		[socket writeData:[@"[NotifyMe] CLOSE\r" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
		[[NotificationSynchronizer sharedInstance] removeComputer:self];
		
		return NULL;
	}
	
	//If the computer didn't answer correctly, send the close signal and remove it from the array of available computers
	if(!valid) {
		[socket writeData:[@"[NotifyMe] CLOSE\r" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:2];
		[[NotificationSynchronizer sharedInstance] removeComputer:self];
		
		return NULL;
	}
	
	done = false;
	valid = false;
	return socket;
}

//Gets called when a socket successfully connects
-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port{
	done = true;
}

//Processes all data, which gets received by the sockets
-(void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag{
	NSString* msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	//Removing \r from the end of the message
	msg = [msg substringWithRange:NSMakeRange(0, msg.length - 1)];
	
	if(tag == 0){
		//Check if computer knows this device
		if([msg isEqualToString:@"[NotifyMe] UNKNOWN DEVICE"]){
			valid = false;
			done = true;
			return;
		}
		
		//Check if Computer has correct key
		if([msg hasPrefix:@"[NotifyMe] VERIFY"]){
			NSString* decrypted = [Utilities decrypt:[msg substringFromIndex:@"[NotifyMe] VERIFY ".length] withKey:[[Preferences sharedInstance] getKey]];
			
			valid = [decrypted isEqualToString:@"Manufactured in Switzerland"];
			
			if(!valid){
				//Write that the key was wrong
				[socket writeData:[[NSString stringWithFormat:@"[NotifyMe] VERIFICATION FALSE\r"] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
			} else [socket writeData:[[NSString stringWithFormat:@"[NotifyMe] VERIFICATION TRUE\r"] dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:1];
			
			done = true;
			return;
		}
		
		valid = false;
		done = true;
	} else if(tag == 1){
		if([msg isEqualToString:@"[NotifyMe] CONFIRMED"]){
			done = true;
			return;
		}
	}
}

//Disconnect sockets when they have sent all of their data (tag == 2 means the close signal has been sent)
-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
	if(tag == 1){
		done = true;
	} else if(tag == 2){
		[sock setDelegate:nil delegateQueue:NULL];
		[sock disconnect];
	}
}
@end