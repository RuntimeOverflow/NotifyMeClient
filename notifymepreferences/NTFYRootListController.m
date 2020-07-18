#include "NTFYRootListController.h"

@implementation NTFYRootListController
-(NSArray*)specifiers{
	if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

	return _specifiers;
}

-(void)loadView{
    [super loadView];
	
	//Dismiss keyboard on drag
    ((UITableView *)[self table]).keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

//Send a notification when the preferences were modified to apply the changes immediately
-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
	[super setPreferenceValue:value specifier:specifier];
	
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.runtimeoverflow.notifyme.UpdateSettings"), NULL, NULL, TRUE);
}
@end
