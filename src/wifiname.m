// wifiname: Wi-Fi helper for travel-mode, used only to show the network's name in the window.
//
//   wifiname [en0]   print the name (SSID) of the network the interface is on
//
// macOS hides the SSID from scripts unless they have Location Services, but the system's dynamic
// store keeps a cached scan record of the current network that still carries it. Names with
// control characters are refused, so they can never reach a terminal.
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

static BOOL clean(NSString *s) {
    return s.length > 0 && s.length <= 64 &&
        [s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
}

static int current_name(NSString *iface) {
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("travel-mode"), NULL, NULL);
    if (!store) return 1;
    NSString *key = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", iface];
    NSDictionary *state = CFBridgingRelease(SCDynamicStoreCopyValue(store, (__bridge CFStringRef)key));
    CFRelease(store);
    if (![state isKindOfClass:[NSDictionary class]]) return 1;

    NSString *ssid = state[@"SSID_STR"];
    if (![ssid isKindOfClass:[NSString class]] || ssid.length == 0) {
        ssid = nil;
        NSData *record = state[@"CachedScanRecord"];
        if ([record isKindOfClass:[NSData class]]) {
            NSSet *allowed = [NSSet setWithObjects:NSDictionary.class, NSArray.class, NSString.class,
                              NSNumber.class, NSData.class, NSDate.class, nil];
            id obj = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowed fromData:record error:NULL];
            if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"SSID_STR"] isKindOfClass:[NSString class]]) {
                ssid = obj[@"SSID_STR"];
            }
        }
    }
    if (!clean(ssid)) return 1;
    printf("%s\n", ssid.UTF8String);
    return 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        return current_name(argc > 1 ? @(argv[1]) : @"en0");
    }
}
