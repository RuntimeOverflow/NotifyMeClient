#import "Utilities.h"
#import "substrate.h"

@interface DNDState : NSObject
-(BOOL)isActive;
@end

@interface DNDNotificationsService : NSObject{
	DNDState* _currentState;
}
@end

@interface SpringBoard : UIApplication{
	DNDNotificationsService* _dndNotificationsService;
}

@property int ringerSwitchState;
@end

@implementation Utilities
static dispatch_queue_t processingQueue;

//Simple method for getting the ringer state
+(BOOL)isRingerMuted{
	return !(BOOL)((SpringBoard*)[UIApplication sharedApplication]).ringerSwitchState;
}

//Simple method for finding out, if DND is enabled
+(BOOL)isDndEnabled{
	DNDNotificationsService* service = MSHookIvar<DNDNotificationsService*>(((SpringBoard*)[UIApplication sharedApplication]), "_dndNotificationsService");
	
	return [((DNDState*)[service valueForKey:@"_currentState"]) isActive];
}

//Returns the queue, which is used to send messages asynchronously
+(dispatch_queue_t)getProcessingQueue{
	//If the queue does not exist yet, create a new one with default priority
	if(!processingQueue){
		processingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	}
	
	return processingQueue;
}

//Encrypt a plain text with AES using the passed key (key first gets hashed with SHA-256)
+(NSString*)encrypt:(NSString*)text withKey:(NSString*)key{
	NSMutableData* textData = [[NSMutableData alloc] initWithData:[text dataUsingEncoding:NSUTF8StringEncoding]];
	
	//SHA-256 hash for the key
	uint8_t digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256([key dataUsingEncoding:NSUTF8StringEncoding].bytes, [key dataUsingEncoding:NSUTF8StringEncoding].length, digest);
	
	//Calculating result length
	int padding = textData.length % kCCBlockSizeAES128;
	int blockLength = 0;
	blockLength = textData.length + (kCCBlockSizeAES128 - padding);
	
	//AES encrypt data
	NSMutableData* result = [NSMutableData dataWithLength:blockLength];
	size_t length = 0;
	CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding | kCCOptionECBMode, digest, kCCKeySizeAES256, NULL, textData.mutableBytes, textData.length, result.mutableBytes, result.length, &length);
	
	return [result base64EncodedStringWithOptions:0];
}

//Decode an AES encrypted text with the passed key (key first gets hashed with SHA-256)
+(NSString*)decrypt:(NSString*)encoded withKey:(NSString*)key{
	NSMutableData* encodedData = [[NSMutableData alloc] initWithBase64EncodedString:encoded options:0];
	
	//SHA-256 hash for the key
	uint8_t digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256([key dataUsingEncoding:NSUTF8StringEncoding].bytes, [key dataUsingEncoding:NSUTF8StringEncoding].length, digest);
	
	//AES decrypt data
	NSMutableData* result = [NSMutableData dataWithLength:encodedData.length];
	size_t length = 0;
	CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding | kCCOptionECBMode, digest, kCCKeySizeAES256, NULL, encodedData.mutableBytes, encodedData.length, result.mutableBytes, result.length, &length);
	
	return [[NSString alloc] initWithBytes:result.mutableBytes length:length encoding:NSUTF8StringEncoding];
}

//Calculates the broadcast address (This code is copied from the internet. I have no idea what is going on here, but it works)
+(NSString*)calculateBroadcastAddress{
	NSString* broadcastAddr = NULL;
	struct ifaddrs *interfaces = NULL;
	struct ifaddrs *temp_addr = NULL;
	int success = 0;
	
	success = getifaddrs(&interfaces);
	
	if (success == 0) {
		temp_addr = interfaces;
		
		while(temp_addr != NULL) {
			if(temp_addr->ifa_addr->sa_family == AF_INET) {
				if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
					broadcastAddr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)];
				}
			}
			
			temp_addr = temp_addr->ifa_next;
		}
	}
	
	freeifaddrs(interfaces);
	return broadcastAddr;
}

//Util method for creating an error alert (on the main queue)
+(void)logError:(NSString*)error{
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"NotifyMe Error" message:error preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
		[alert addAction:dismissAction];
		[[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
	});
	
	#pragma clang diagnostic pop
}
@end