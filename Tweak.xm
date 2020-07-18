#import "NotificationSynchronizer.h"
#import "Preferences.h"
#import "Utilities.h"
#import <UserNotificationsUIKit/NCNotificationStructuredListViewController.h>
#import <UserNotificationsUIKit/NCNotificationMasterList.h>
#import <UserNotificationsUIKit/NCNotificationStructuredSectionList.h>
#import <UserNotificationsUIKit/NCNotificationGroupList.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotificationsKit/NCNotificationRequest.h>
#import <UserNotificationsKit/NCNotificationContent.h>

//ViewController which handles the notification center
%hook NCNotificationStructuredListViewController
NotificationSynchronizer* ns;
NSDate* readyDate;

//Initialize the NotificationSynchronizer
-(void)viewDidLoad{
	%orig;
	
	ns = [NotificationSynchronizer sharedInstance];
	[ns initWithMasterList:self.masterList];
}

//Called when there is a new notification
-(void)insertNotificationRequest:(id)request{
	%orig;
	
	//Initial timeout (because all notifications get added after a respring and I don't want to flood the sockets)
	if(!readyDate){
		readyDate = [NSDate dateWithTimeIntervalSinceNow:5.0];
	}
	
	if(readyDate && [readyDate compare: [NSDate date]] == NSOrderedAscending){
		[ns addNotification:request];
		[ns syncNotifications];
	}
}

//Called when a notification gets modified (actually I don't know when it gets called, but I will still synchronize all notifications)
-(void)modifyNotificationRequest:(id)request{
	%orig;
	
	if(readyDate && [readyDate compare: [NSDate date]] == NSOrderedAscending){
		[ns syncNotifications];
	}
}

//Called when a notification gets removed
-(void)removeNotificationRequest:(id)request{
	%orig;
	
	if(readyDate && [readyDate compare: [NSDate date]] == NSOrderedAscending){
		[ns syncNotifications];
	}
}
%end

/*%hook NCBulletinActionRunner
-(void)executeAction:(id)action fromOrigin:(id)origin endpoint:(id)endpoint withParameters:(id)parameters completion:(id)completion{
	dispatch_async(dispatch_get_main_queue(), ^{
		//UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"" message:[NSString stringWithFormat:@"%lu", (long)[parameters count]] preferredStyle:UIAlertControllerStyleAlert];
		UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"" message:[NSString stringWithFormat:@"%@", parameters] preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
		[alert addAction:dismissAction];
		[[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
	});
	
	%orig;
}
%end*/

//Initializes/loads the settings
%ctor{
	[[Preferences sharedInstance] loadSettings];
}

/*
-(void)executeAction:(NCNotificationAction*)action fromOrigin:(NSString*)origin endpoint:(BSServiceConnectionEndpoint*)endpoint withParameters:(NSDictionary*)parameters completion:(id)completion
origin: @"BulletinDestinationCoverSheet"
*/