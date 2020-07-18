#import "Computer.h"
#import "GCDAsyncUdpSocket.h"
#import <UserNotificationsUIKit/NCNotificationMasterList.h>

@interface NotificationSynchronizer : NSObject <GCDAsyncUdpSocketDelegate> {
	BOOL done;
}

@property GCDAsyncUdpSocket* udpSocket;
@property NCNotificationMasterList* list;
@property NSMutableArray* hosts;

+(instancetype)sharedInstance;
-(void)initWithMasterList:(NCNotificationMasterList*)masterList;

-(void)syncNotifications;
-(void)addNotification:(NCNotificationRequest*)request;

-(void)updatePort;

-(void)removeComputer:(Computer*)computer;
@end