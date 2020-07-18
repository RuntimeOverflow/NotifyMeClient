#import "Preferences.h"
#import "NotificationSynchronizer.h"

@implementation Preferences
@synthesize settings;
@synthesize apps;

//Returns the sharedInstance, as this is a singleton class
+(instancetype)sharedInstance{
	static Preferences* sharedInstance = NULL;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[Preferences alloc] init];
		
		//Adds the notification observer
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, updateSettings, CFSTR("com.runtimeoverflow.notifyme.UpdateSettings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	});

	return sharedInstance;
}

//Gets called when the settings changed and reloads the settings
static void updateSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo){
	[[Preferences sharedInstance] loadSettings];
	
	[[NotificationSynchronizer sharedInstance] updatePort];
}

//Loads the settings to a NSMutableArray
-(void)loadSettings{
	settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.runtimeoverflow.notifymeprefs.plist"];
	apps = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.runtimeoverflow.notifymeprefs.filter.plist"];
}

//Returns if the tweak is enabled in settings
-(BOOL)isEnabled{
	id preference = [settings objectForKey:@"enabled"];
	
	if(preference) return [preference boolValue];
	else return true;
}

//Returns if the phone is discoverable through wifi
-(BOOL)isDiscoverable{
	id preference = [settings objectForKey:@"discoverable"];
	
	if(preference) return [preference boolValue];
	else return true;
}

//Returns the port after checking if it's valid (if the port is invalid, it will return the port 1337)
-(int)getPort{
	id preference = [settings objectForKey:@"port"];
	
	if(preference) return MAX(MIN([preference intValue], 65535), 0);
	else return 1337;
}

//Returns the key
-(NSString*)getKey{
	id preference = [settings objectForKey:@"key"];
	
	if(preference) return [preference stringValue];
	else return @"CHANGE THIS";
}

//gets the display and sound option (3 = Popup + Sound, 2 = Sound only, 1 = Popup only, 0 = Hidden)
-(int)getDefaultBehaviour{
	id preference = [settings objectForKey:@"defaultBehaviour"];
	
	if(preference) return [preference intValue];
	else return 3;
}

//gets the display and sound option, when the ringer is toggled (3 = Popup + Sound, 2 = Sound only, 1 = Popup only, 0 = Hidden)
-(int)getRingerBehaviour{
	id preference = [settings objectForKey:@"ringerBehaviour"];
	
	if(preference) return [preference intValue];
	else return 3;
}

//gets the display and sound option, when dnd is enabled (3 = Popup + Sound, 2 = Sound only, 1 = Popup only, 0 = Hidden)
-(int)getDndBehaviour{
	id preference = [settings objectForKey:@"dndBehaviour"];
	
	if(preference) return [preference intValue];
	else return 3;
}

//Returns if the app was selected in settings
-(BOOL)isAppEnabled:(NSString*)bundleId{
	//Refresh app preferences
	apps = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.runtimeoverflow.notifymeprefs.filter.plist"];
	
	id app = [apps objectForKey:bundleId];
	
	if(app) return [app boolValue];
	else return false;
}

//Returns if the filter type is set to blacklist
-(BOOL)isBlacklist{
	id preference = [settings objectForKey:@"filterType"];
	
	if(preference) return [preference boolValue];
	else return true;
}

//Returns if the filter type is set to whitelist
-(BOOL)isWhitelist{
	return ![self isBlacklist];
}
@end