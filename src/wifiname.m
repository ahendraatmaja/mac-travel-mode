// wifiname: print the name (SSID) of the Wi-Fi network an interface is connected to.
// macOS hides the SSID from scripts unless they have Location Services, but the system's
// dynamic store keeps a cached scan record of the current network that still carries it.
// Best effort: exits 1 when the name can't be read. Usage: wifiname [en0]
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *iface = argc > 1 ? @(argv[1]) : @"en0";
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
                @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    id obj = [NSKeyedUnarchiver unarchiveObjectWithData:record];
#pragma clang diagnostic pop
                    if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"SSID_STR"] isKindOfClass:[NSString class]]) {
                        ssid = obj[@"SSID_STR"];
                    }
                } @catch (NSException *e) { ssid = nil; }
            }
        }
        if (ssid.length == 0) return 1;
        printf("%s\n", ssid.UTF8String);
        return 0;
    }
}
