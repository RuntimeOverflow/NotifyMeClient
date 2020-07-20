#import "NotificationSynchronizer.h"
#import "Preferences.h"
#import "Utilities.h"
#import <UserNotificationsUIKit/NCNotificationStructuredListViewController.h>
#import <UserNotificationsUIKit/NCNotificationMasterList.h>
#import <UserNotificationsUIKit/NCNotificationStructuredSectionList.h>
#import <UserNotificationsUIKit/NCNotificationGroupList.h>
#import <UserNotificationsUIKit/NCBulletinActionRunner.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotificationsKit/NCNotificationRequest.h>
#import <UserNotificationsKit/NCNotificationContent.h>
#import <UserNotificationsKit/NCNotificationAction.h>

@implementation NotificationSynchronizer
@synthesize udpSocket;
@synthesize list;
@synthesize hosts;

NCNotificationRequest* latestNotification;
NSDate* latestNotificationExpiry;

dispatch_queue_t socketQueue;

//Returns the sharedInstance, as this is a singleton class
+(instancetype)sharedInstance{
	static NotificationSynchronizer* sharedInstance = NULL;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[NotificationSynchronizer alloc] init];
	});

	return sharedInstance;
}

//Initializes a new NotificationSynchronizer object
-(void)initWithMasterList:(NCNotificationMasterList*)masterList{
	//Initialize all properties
	hosts = [[NSMutableArray alloc] init];
	
	socketQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	self.list = masterList;
	self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
	
	//Connects the udp socket to the broadcast ip
	NSError *error = nil;
	if(![self.udpSocket bindToPort:[[Preferences sharedInstance] getPort] error:&error] || ![self.udpSocket enableBroadcast:YES error:&error] || ![self.udpSocket beginReceiving:&error]) {
		[Utilities logError:[NSString stringWithFormat:@"%@", error]];
		
		[self.udpSocket close];
	}
}

//Creates a json of all the notifications and sends it to all hosts
-(void)syncNotifications{
	[[Preferences sharedInstance] loadSettings];
	
	if(![[Preferences sharedInstance] isEnabled]) return;
	
	[self send:@"SYNC" withParameters:[Utilities encrypt:[NotificationSynchronizer jsonFromMasterList:self.list] withKey:[[Preferences sharedInstance] getKey]]];
	
	//Search for new computers
	[self discoverComputers];
}

//Creates a json of all the notifications and sends it to the specified host
-(void)syncNotifications:(Computer*)host{
	[[Preferences sharedInstance] loadSettings];
	
	if(![[Preferences sharedInstance] isEnabled]) return;
	
	[self send:@"SYNC" withParameters:[Utilities encrypt:[NotificationSynchronizer jsonFromMasterList:self.list] withKey:[[Preferences sharedInstance] getKey]] toHost:host];
}

//Creates a json of the new notification and sends it to all hosts
-(void)addNotification:(NCNotificationRequest*)request{
	if([request.sectionIdentifier isEqualToString:@"com.RuntimeOverflow.Runner"]){
		NCNotificationAction* clearAction = request.clearAction;
		[clearAction.actionRunner executeAction:clearAction fromOrigin:NULL endpoint:NULL withParameters:[[NSMutableDictionary alloc] init] completion:NULL];
	}
	
	[[Preferences sharedInstance] loadSettings];
	
	if(![[Preferences sharedInstance] isEnabled]) return;
	
	if(!([[Preferences sharedInstance] isWhitelist] && [[Preferences sharedInstance] isAppEnabled:request.sectionIdentifier]) && !([[Preferences sharedInstance] isBlacklist] && ![[Preferences sharedInstance] isAppEnabled:request.sectionIdentifier])) return;
	
	BOOL popup = true;
	BOOL sound = true;
	
	popup = [[Preferences sharedInstance] getDefaultBehaviour] & (1 << 0);
	sound = [[Preferences sharedInstance] getDefaultBehaviour] & (1 << 1);
	
	if([Utilities isRingerMuted]){
		if(popup) popup = [[Preferences sharedInstance] getRingerBehaviour] & (1 << 0);
		if(sound) sound = [[Preferences sharedInstance] getRingerBehaviour] & (1 << 1);
	}
	
	if([Utilities isDndEnabled]){
		if(popup) popup = [[Preferences sharedInstance] getDndBehaviour] & (1 << 0);
		if(sound) sound = [[Preferences sharedInstance] getDndBehaviour] & (1 << 1);
	}
	
	//Sets the notification as the newest one. It will expire after 10 seconds
	latestNotification = request;
	latestNotificationExpiry = [NSDate dateWithTimeIntervalSinceNow:10.0];
	
	NSError* error = nil;
	NSData* jsonData = [NSJSONSerialization dataWithJSONObject:[NotificationSynchronizer notificationAsDictionary:request] options:0 error:&error];
	if(!jsonData || error){
		[Utilities logError:[NSString stringWithFormat:@"%@", error]];
		return;
	}
	
	NSString* json = [[NSMutableString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	json = [json stringByReplacingOccurrencesOfString: @"\r" withString:@""];
	
	[self send:[NSString stringWithFormat:@"NOTIFICATION %@ %@", popup ? @"VISIBLE" : @"HIDDEN", sound ? @"SOUND" : @"MUTED"] withParameters:[Utilities encrypt:json withKey:[[Preferences sharedInstance] getKey]]];
}

//Creates a json of the new notification and sends it to the specified host
-(void)addNotification:(NCNotificationRequest*)request host:(Computer*)host{
	[[Preferences sharedInstance] loadSettings];
	
	if(![[Preferences sharedInstance] isEnabled]) return;
	
	if(!([[Preferences sharedInstance] isWhitelist] && [[Preferences sharedInstance] isAppEnabled:request.sectionIdentifier]) && !([[Preferences sharedInstance] isBlacklist] && ![[Preferences sharedInstance] isAppEnabled:request.sectionIdentifier])) return;
	
	BOOL popup = true;
	BOOL sound = true;
	
	popup = [[Preferences sharedInstance] getDefaultBehaviour] & (1 << 0);
	sound = [[Preferences sharedInstance] getDefaultBehaviour] & (1 << 1);
	
	if([Utilities isRingerMuted]){
		popup = [[Preferences sharedInstance] getRingerBehaviour] & (1 << 0);
		sound = [[Preferences sharedInstance] getRingerBehaviour] & (1 << 1);
	}
	
	if([Utilities isDndEnabled]){
		if(popup) popup = [[Preferences sharedInstance] getDndBehaviour] & (1 << 0);
		if(sound) sound = [[Preferences sharedInstance] getDndBehaviour] & (1 << 1);
	}
	
	//Sets the notification as the newest one. It will expire after 10 seconds
	latestNotification = request;
	latestNotificationExpiry = [NSDate dateWithTimeIntervalSinceNow:10.0];
	
	NSError* error = nil;
	NSData* jsonData = [NSJSONSerialization dataWithJSONObject:[NotificationSynchronizer notificationAsDictionary:request] options:0 error:&error];
	if(!jsonData || error){
		[Utilities logError:[NSString stringWithFormat:@"%@", error]];
		return;
	}
	
	NSString* json = [[NSMutableString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	json = [json stringByReplacingOccurrencesOfString: @"\r" withString:@""];
	
	[self send:[NSString stringWithFormat:@"NOTIFICATION %@ %@", popup ? @"VISIBLE" : @"HIDDEN", sound ? @"SOUND" : @"MUTED"] withParameters:[Utilities encrypt:json withKey:[[Preferences sharedInstance] getKey]] toHost:host];
}

//Creates a json string from all notifications
+(NSString*)jsonFromMasterList: (NCNotificationMasterList*)masterList{
	//Puts new notifications together with older notifications
	NSMutableArray* allGroups = [[NSMutableArray alloc] init];
	for(NCNotificationStructuredSectionList* sectionList in masterList.notificationSections) [allGroups addObjectsFromArray:sectionList.notificationGroups];
	
	//Iterates through all notification groups
	NSMutableArray* groups = [[NSMutableArray alloc] init];
	for(NCNotificationGroupList* groupList in allGroups){
		//Iterates through all requests in the group and creates a dictionary for each notification
		NSMutableArray* requests = [[NSMutableArray alloc] init];
		[requests addObjectsFromArray:groupList.orderedRequests];
		
		if(requests.count <= 0) continue;
		
		NSMutableArray* group = NULL;
		for(NSMutableArray* g in groups){
			if([[g objectAtIndex:0][@"threadId"] isEqualToString:((NCNotificationRequest*)[requests objectAtIndex:0]).threadIdentifier]){
				group = g;
				break;
			}
		}
		
		if(!group){
			group = [[NSMutableArray alloc] init];
			[groups addObject:group];
		}
		
		for(NCNotificationRequest* request in requests){
			NSMutableDictionary* notification = [NotificationSynchronizer notificationAsDictionary:request];
			
			[group addObject:notification];
		}
	}
	
	//Converts everything to a json string
	NSError* error = nil;
	NSData* jsonData = [NSJSONSerialization dataWithJSONObject:groups options:0 error:&error];
	if(!jsonData || error){
		[Utilities logError:[NSString stringWithFormat:@"%@", error]];
		return @"";
	}
	
	return [[NSMutableString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

//Puts all important information of an NCNotificationRequest in a dictionary (All icons first get base64 encoded to be saved as a string)
+(NSMutableDictionary*)notificationAsDictionary: (NCNotificationRequest*)request{
	NSMutableDictionary* notification = [[NSMutableDictionary alloc] init];
	
	notification[@"title"] = request.content.title;
	notification[@"subtitle"] = request.content.subtitle;
	notification[@"body"] = request.content.message;
	notification[@"bundleId"] = request.sectionIdentifier;
	notification[@"threadId"] = request.threadIdentifier;
	notification[@"id"] = request.notificationIdentifier;
	notification[@"category"] = request.categoryIdentifier;
	notification[@"date"] = [NSNumber numberWithLong:(long)([request.content.date timeIntervalSince1970] * 1000.0)];
	notification[@"app"] = request.content.header;
	notification[@"icon"] = [UIImagePNGRepresentation(request.content.icon) base64EncodedStringWithOptions:0];
	notification[@"attachment"] = request.content.attachmentImage ? [UIImagePNGRepresentation(request.content.attachmentImage) base64EncodedStringWithOptions:0] : NULL;
	
	notification[@"dismissAction"] = [NotificationSynchronizer actionAsDictionary:request.closeAction];
	
	NSMutableArray* actions = [[NSMutableArray alloc] init];
	for(NCNotificationAction* action in request.supplementaryActions[@"NCNotificationActionEnvironmentDefault"]){
		[actions addObject:[NotificationSynchronizer actionAsDictionary:action]];
	}
	
	notification[@"actions"] = actions;
	
	return notification;
}

//Puts all important information of an NCNotificationRequest in a dictionary (All icons first get base64 encoded to be saved as a string)
+(NSMutableDictionary*)actionAsDictionary: (NCNotificationAction*)action{
	NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
	
	dict[@"id"] = action.identifier;
	dict[@"text"] = [NSNumber numberWithBool:(BOOL)action.behavior];;
	dict[@"title"] = action.title;
	
	return dict;
}

//Search for computers by broadcasting a message using UDP
-(void)discoverComputers{
	NSString* uuidEncoded = [[[UIDevice currentDevice].identifierForVendor.UUIDString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
	NSString* nameEncoded = [[[UIDevice currentDevice].name dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
	
	if([Utilities calculateBroadcastAddress]) [udpSocket sendData:[[NSString stringWithFormat:@"[NotifyMe] SEARCH COMPUTER %@ %@", uuidEncoded, nameEncoded] dataUsingEncoding:NSUTF8StringEncoding] toHost:[Utilities calculateBroadcastAddress] port:[[Preferences sharedInstance] getPort] withTimeout:-1 tag:0];
}

//Same as function below
-(void)send:(NSString*)command withParameters:(NSString*)parameters{
	[self send:command withParameters:parameters toHosts:[NSMutableArray arrayWithArray:self.hosts]];
}

//Same as function below
-(void)send:(NSString*)command withParameters:(NSString*)parameters toHost:(Computer*)host{
	[self send:command withParameters:parameters toHosts:[[NSMutableArray alloc] initWithObjects:host, nil]];
}

//Simple method for sending a message
-(void)send:(NSString*)command withParameters:(NSString*)parameters toHosts:(NSMutableArray*)hostsArray{
	if(!hostsArray) return;
	
	for(Computer* host in hostsArray){
		[host send:command withParameters:parameters];
	}
}

-(void)updatePort{
	//Closes the udp socket
	if(self.udpSocket){
		[self.udpSocket close];
	}
	
	//Wait for connection to close (When the connection closed, the udpSocketDidClose:withError: function gets called and sets the done to true)
	done = false;
	while (!done) {
		NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.1];
		[[NSRunLoop currentRunLoop] runUntilDate:date];
	}
	done = false;
	
	[self.udpSocket setDelegate:nil delegateQueue:NULL];
	
	//Creates a new udp socket
	self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
	
	//Connects the udp socket to the broadcast ip
	NSError *error = nil;
	if(![self.udpSocket bindToPort:[[Preferences sharedInstance] getPort] error:&error] || ![self.udpSocket enableBroadcast:YES error:&error] || ![self.udpSocket beginReceiving:&error]) {
		[Utilities logError:[NSString stringWithFormat:@"%@", error]];
		
		[self.udpSocket close];
	}
}

-(Computer*)computerForHost:(NSString*)host{
	NSMutableArray* hostsCopy = [NSMutableArray arrayWithArray:hosts];
	for(Computer* c in hostsCopy){
		if([c.host isEqualToString:host]) return c;
	}
	
	return NULL;
}

-(void)removeComputer:(Computer*)computer{
	[hosts removeObject:computer];
}

//Processes all data received by the UDP socket
-(void)udpSocket:(GCDAsyncUdpSocket*)sock didReceiveData:(NSData*)data fromAddress:(NSData*)address withFilterContext:(id)filterContext {
	if(![[Preferences sharedInstance] isEnabled]) return;
	
	NSString* msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	NSString* host = @"";
	uint16_t port = 0;
	[GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
	
	//Adds a computer (which is ready) to the connected hosts and syncs all notifications with it
	if(msg && [msg isEqualToString:@"[NotifyMe] READY"]){
		if(![self computerForHost:host]){
			Computer* c = [[Computer alloc] initWithHost:host];
			[hosts addObject:c];
			
			//Sending the latest notification if it hasn't expired (expiration after 10 seconds)
			if(latestNotification && latestNotificationExpiry && [latestNotificationExpiry compare: [NSDate date]] == NSOrderedDescending) [self addNotification:latestNotification host:c];
			
			//Synchronize all notifications with the new computer
			[self syncNotifications:c];
		}
	}
	
	//Synchronizes all notifications, if the computer requests it
	if(msg && [msg isEqualToString:@"[NotifyMe] RELOAD"]){
		[self syncNotifications:[self computerForHost:host]];
	}
	
	//Sends a message, when a computer searches for this device
	if(msg && [msg hasPrefix:@"[NotifyMe] SEARCH DEVICE"] && [[Preferences sharedInstance] isDiscoverable]){
		NSString* uuidEncoded = [[[UIDevice currentDevice].identifierForVendor.UUIDString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
		NSString* nameEncoded = [[[UIDevice currentDevice].name dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
		
		[udpSocket sendData:[[NSString stringWithFormat:@"[NotifyMe] FOUND %@ %@", uuidEncoded, nameEncoded] dataUsingEncoding:NSUTF8StringEncoding] toHost:host port:[[Preferences sharedInstance] getPort] withTimeout:-1 tag:0];
	}
}

-(void)udpSocketDidClose:(GCDAsyncUdpSocket*)sock withError:(NSError*)error{
	done = true;
}
@end