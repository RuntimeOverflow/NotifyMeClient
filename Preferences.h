@interface Preferences : NSObject
@property NSMutableDictionary* settings;
@property NSMutableDictionary* apps;

+(instancetype)sharedInstance;
-(void)loadSettings;

-(BOOL)isEnabled;
-(BOOL)isDiscoverable;
-(int)getPort;
-(NSString*)getKey;
-(int)getDefaultBehaviour;
-(int)getRingerBehaviour;
-(int)getDndBehaviour;
-(BOOL)isAppEnabled:(NSString*)bundleId;
-(BOOL)isBlacklist;
-(BOOL)isWhitelist;
@end