// wifiname: Wi-Fi helper for travel-mode.
//
//   wifiname [en0]                print the name (SSID) of the network the interface is on
//   wifiname --check en0 <name>   is a network called <name> in range, and is it password-protected?
//                                 prints secure (exit 0), open (exit 3), absent (exit 4); error = exit 1
//
// macOS hides the SSID from scripts unless they have Location Services, but the system's dynamic
// store keeps a cached scan record of the current network that still carries it. A scan for one
// given name also works without Location Services (the results are filtered by name; their own
// names stay hidden), and it reports each match's security. Names with control characters are
// refused, so they can never reach a terminal or the log.
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreWLAN/CoreWLAN.h>

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

static int check(NSString *iface, NSString *name) {
    if (!clean(name)) return 1;
    CWInterface *wifi = [[CWWiFiClient sharedWiFiClient] interfaceWithName:iface];
    if (!wifi) return 1;
    NSError *err = nil;
    NSSet<CWNetwork *> *nets = [wifi scanForNetworksWithName:name includeHidden:NO error:&err];
    if (!nets) return 1;
    if (nets.count == 0) { printf("absent\n"); return 4; }
    for (CWNetwork *n in nets) {
        BOOL personal = [n supportsSecurity:kCWSecurityWPAPersonal] || [n supportsSecurity:kCWSecurityWPAPersonalMixed] ||
                        [n supportsSecurity:kCWSecurityWPA2Personal] || [n supportsSecurity:kCWSecurityPersonal] ||
                        [n supportsSecurity:kCWSecurityWPA3Personal] || [n supportsSecurity:kCWSecurityWPA3Transition];
        BOOL open = [n supportsSecurity:kCWSecurityNone] || [n supportsSecurity:kCWSecurityOWE] ||
                    [n supportsSecurity:kCWSecurityOWETransition] || [n supportsSecurity:kCWSecurityWEP] ||
                    [n supportsSecurity:kCWSecurityDynamicWEP];
        // An iPhone hotspot always uses a password. Anything else with the same name is a lookalike.
        if (open || !personal) { printf("open\n"); return 3; }
    }
    printf("secure\n");
    return 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc >= 2 && strcmp(argv[1], "--check") == 0) {
            if (argc != 4) return 1;
            return check(@(argv[2]), @(argv[3]));
        }
        return current_name(argc > 1 ? @(argv[1]) : @"en0");
    }
}
