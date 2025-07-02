#import "ZSDKWrapper.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterConnection.h"
#import "ZebraPrinterFactory.h"
#import "TcpPrinterConnection.h"
#import "MfiBtPrinterConnection.h"
#import "NetworkDiscoverer.h"
#import "DiscoveredPrinter.h"
#import "DiscoveredPrinterNetwork.h"
#import "SGD.h"
#import <ExternalAccessory/ExternalAccessory.h>

@implementation ZSDKWrapper

#pragma mark - Discovery

+ (void)startNetworkDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error {
    // Ensure we're already on a background thread to prevent blocking
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSError *discoveryError = nil;
            // Use a shorter timeout to prevent freezing
            NSArray *printers = [NetworkDiscoverer localBroadcastWithTimeout:2 error:&discoveryError];
            
            if (discoveryError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    error([discoveryError localizedDescription]);
                });
            } else {
                NSMutableArray *printerInfo = [NSMutableArray array];
                for (id printer in printers) {
                    NSMutableDictionary *info = [NSMutableDictionary dictionary];
                    
                    if ([printer isKindOfClass:[DiscoveredPrinterNetwork class]]) {
                        DiscoveredPrinterNetwork *networkPrinter = (DiscoveredPrinterNetwork *)printer;
                        info[@"address"] = networkPrinter.address ?: @"";
                        info[@"port"] = @(networkPrinter.port);
                        info[@"name"] = networkPrinter.dnsName ?: networkPrinter.address ?: @"Unknown";
                        info[@"isWifi"] = @YES;
                    } else if ([printer isKindOfClass:[DiscoveredPrinter class]]) {
                        DiscoveredPrinter *discoveredPrinter = (DiscoveredPrinter *)printer;
                        info[@"address"] = discoveredPrinter.address ?: @"";
                        info[@"name"] = discoveredPrinter.address ?: @"Unknown";
                        info[@"isWifi"] = @YES;
                    }
                    
                    [printerInfo addObject:info];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(printerInfo);
                });
            }
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                error([exception reason]);
            });
        }
    });
}

+ (void)startBluetoothDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // Use EAAccessoryManager to find connected Bluetooth accessories
            EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
            NSArray *connectedAccessories = [accessoryManager connectedAccessories];
            
            NSMutableArray *printerInfo = [NSMutableArray array];
            
            for (EAAccessory *accessory in connectedAccessories) {
                NSMutableDictionary *info = [NSMutableDictionary dictionary];
                info[@"address"] = accessory.serialNumber ?: @"";
                info[@"name"] = accessory.name ?: accessory.serialNumber ?: @"Unknown Printer";
                info[@"isBluetooth"] = @YES;
                
                [printerInfo addObject:info];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                success(printerInfo);
            });
        } @catch (NSException *exception) {
            dispatch_async(dispatch_get_main_queue(), ^{
                error([exception reason]);
            });
        }
    });
}

+ (void)stopDiscovery {
    // NetworkDiscoverer doesn't have a stop method in the static API
    // Discovery stops automatically when the method returns
}

#pragma mark - Connection

+ (id)connectToPrinter:(NSString *)address isBluetoothConnection:(BOOL)isBluetooth {
    id<ZebraPrinterConnection,NSObject> connection = nil;
    
    if (isBluetooth) {
        connection = [[MfiBtPrinterConnection alloc] initWithSerialNumber:address];
    } else {
        // Default port for Zebra printers
        NSInteger port = 9100;
        
        // Check if address contains port
        NSArray *parts = [address componentsSeparatedByString:@":"];
        NSString *ipAddress = address;
        if (parts.count == 2) {
            ipAddress = parts[0];
            port = [parts[1] integerValue];
        }
        
        connection = [[TcpPrinterConnection alloc] initWithAddress:ipAddress andWithPort:port];
    }
    
    if (connection && [connection open]) {
        return connection;
    }
    
    return nil;
}

+ (void)disconnect:(id)connection {
    if (connection && [connection conformsToProtocol:@protocol(ZebraPrinterConnection)]) {
        id<ZebraPrinterConnection,NSObject> printerConnection = connection;
        [printerConnection close];
    }
}

+ (BOOL)isConnected:(id)connection {
    if (connection && [connection conformsToProtocol:@protocol(ZebraPrinterConnection)]) {
        id<ZebraPrinterConnection,NSObject> printerConnection = connection;
        return [printerConnection isConnected];
    }
    return NO;
}

+ (BOOL)sendData:(NSData *)data toConnection:(id)connection {
    if (!connection || !data) return NO;
    
    if ([connection conformsToProtocol:@protocol(ZebraPrinterConnection)]) {
        id<ZebraPrinterConnection,NSObject> printerConnection = connection;
        NSError *error = nil;
        BOOL success = [printerConnection write:data error:&error];
        return success && !error;
    }
    
    return NO;
}

#pragma mark - Printer Operations

+ (id)getPrinter:(id)connection {
    @try {
        return [ZebraPrinterFactory getInstance:connection error:nil];
    } @catch (NSException *exception) {
        return nil;
    }
}

#pragma mark - Settings

+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection {
    if (!connection || !setting) return nil;
    
    @try {
        NSError *error = nil;
        id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:&error];
        
        if (error || !printer) {
            return nil;
        }
        
        // Use SGD class to get the value
        NSString *value = [SGD GET:setting withPrinterConnection:connection error:&error];
        
        return error ? nil : value;
    } @catch (NSException *exception) {
        return nil;
    }
}

+ (BOOL)setSetting:(NSString *)setting value:(NSString *)value onConnection:(id)connection {
    if (!connection || !setting || !value) return NO;
    
    @try {
        NSError *error = nil;
        id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:&error];
        
        if (error || !printer) {
            return NO;
        }
        
        // Use SGD class to set the value
        BOOL success = [SGD SET:setting withValue:value andWithPrinterConnection:connection error:&error];
        
        return success && !error;
    } @catch (NSException *exception) {
        return NO;
    }
}

+ (NSString *)getPrinterLanguage:(id)connection {
    if (!connection) return @"UNKNOWN";
    
    @try {
        id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:nil];
        if (printer) {
            PrinterLanguage language = [printer getPrinterControlLanguage];
            if (language == PRINTER_LANGUAGE_ZPL) {
                return @"ZPL";
            } else if (language == PRINTER_LANGUAGE_CPCL) {
                return @"CPCL";
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Failed to get printer language: %@", exception);
    }
    
    return @"UNKNOWN";
}

+ (id)getPrinterInstance:(id)connection {
    if (!connection) return nil;
    
    @try {
        NSError *error = nil;
        id printer = [ZebraPrinterFactory getInstance:connection error:&error];
        if (error) {
            NSLog(@"Error getting printer instance: %@", error);
            return nil;
        }
        return printer;
    } @catch (NSException *exception) {
        NSLog(@"Exception getting printer instance: %@", exception);
        return nil;
    }
}

+ (BOOL)setPrinterLanguage:(NSString *)language onConnection:(id)connection {
    if (!connection || !language) return NO;
    
    @try {
        // Use SGD to set the printer language
        // device.languages can be set to "zpl", "cpcl", or "line_print"
        NSString *languageValue = [language lowercaseString];
        
        NSError *error = nil;
        return [SGD SET:@"device.languages" withValue:languageValue andWithPrinterConnection:connection error:&error];
    } @catch (NSException *exception) {
        NSLog(@"Failed to set printer language: %@", exception);
        return NO;
    }
}

@end 