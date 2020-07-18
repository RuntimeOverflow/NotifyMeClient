#import <ifaddrs.h>
#include <arpa/inet.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonCryptor.h>

@interface Utilities : NSObject
+(BOOL)isRingerMuted;
+(BOOL)isDndEnabled;

+(dispatch_queue_t)getProcessingQueue;

+(NSString*)encrypt:(NSString*)text withKey:(NSString*)key;
+(NSString*)decrypt:(NSString*)encoded withKey:(NSString*)key;

+(NSString*)calculateBroadcastAddress;

+(void)logError:(NSString*)error;
@end