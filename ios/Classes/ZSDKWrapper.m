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
#import "PrinterStatus.h"
#import "PrinterStatusMessages.h"
#import <ExternalAccessory/ExternalAccessory.h>

@implementation ZSDKWrapper

#pragma mark - Discovery

+ (void)startNetworkDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSError *discoveryError = nil;
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
                        if (networkPrinter.address && networkPrinter.address.length > 0) {
                            info[@"address"] = networkPrinter.address;
                            info[@"port"] = @(networkPrinter.port);
                            info[@"name"] = networkPrinter.dnsName ?: networkPrinter.address;
                            info[@"isWifi"] = @YES;
                            info[@"isBluetooth"] = @NO;
                        }
                    } else if ([printer isKindOfClass:[DiscoveredPrinter class]]) {
                        DiscoveredPrinter *discoveredPrinter = (DiscoveredPrinter *)printer;
                        if (discoveredPrinter.address && discoveredPrinter.address.length > 0) {
                            info[@"address"] = discoveredPrinter.address;
                            info[@"name"] = discoveredPrinter.address;
                            info[@"isWifi"] = @YES;
                            info[@"isBluetooth"] = @NO;
                        }
                    }
                    
                    if (info[@"address"]) {
                        [printerInfo addObject:info];
                    }
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

+ (void)startMfiBluetoothDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSMutableArray *printerInfo = [NSMutableArray array];
            
            EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
            NSArray *connectedAccessories = [accessoryManager connectedAccessories];
            
            for (EAAccessory *accessory in connectedAccessories) {
                // Check if this is a Zebra printer
                if ([accessory.protocolStrings indexOfObject:@"com.zebra.rawport"] != NSNotFound) {
                    if (accessory.serialNumber && accessory.serialNumber.length > 0) {
                        NSMutableDictionary *info = [NSMutableDictionary dictionary];
                        info[@"Address"] = accessory.serialNumber;
                        info[@"Name"] = accessory.name ?: @"Zebra Printer";
                        info[@"model"] = accessory.modelNumber ?: @"";
                        info[@"manufacturer"] = accessory.manufacturer ?: @"";
                        info[@"firmwareRevision"] = accessory.firmwareRevision ?: @"";
                        info[@"hardwareRevision"] = accessory.hardwareRevision ?: @"";
                        info[@"IsWifi"] = @NO;
                        info[@"isBluetooth"] = @YES;
                        
                        [printerInfo addObject:info];
                    }
                }
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
        // MFi Bluetooth connection
        connection = [[MfiBtPrinterConnection alloc] initWithSerialNumber:address];
    } else {
        // Network connection - expect address in format "ip:port"
        NSInteger port = 9100; // Default port
        NSString *ipAddress = address;
        
        // Simple port extraction if present
        NSArray *parts = [address componentsSeparatedByString:@":"];
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
        
        // Send the data
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

+ (NSString *)sendAndReadResponse:(NSString *)data toConnection:(id)connection withTimeout:(NSInteger)timeout {
    if (!connection || !data) return nil;
    
    @try {
        // Send the data
        NSData *dataBytes = [data dataUsingEncoding:NSUTF8StringEncoding];
        NSError *sendError = nil;
        BOOL sent = [connection write:dataBytes error:&sendError];
        
        if (!sent || sendError) {
            NSLog(@"Failed to send data: %@", sendError);
            return nil;
        }
        
        // Set connection timeout
        if ([connection respondsToSelector:@selector(setMaxTimeoutForRead:)]) {
            [connection setMaxTimeoutForRead:timeout > 0 ? timeout : 5000];
        }
        
        // Read response
        NSError *readError = nil;
        NSData *responseData = [connection read:&readError];
        
        if (responseData && !readError) {
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            return response;
        }
        
    } @catch (NSException *exception) {
        NSLog(@"Failed to send and read response: %@", exception);
    }
    
    return nil;
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

+ (id)getPrinterInstanceWithLanguage:(id)connection language:(NSString *)language {
    if (!connection) return nil;
    
    @try {
        PrinterLanguage printerLanguage = PRINTER_LANGUAGE_ZPL;
        if ([language isEqualToString:@"CPCL"]) {
            printerLanguage = PRINTER_LANGUAGE_CPCL;
        }
        
        // Use the method that doesn't send getvar commands
        id printer = [ZebraPrinterFactory getInstance:connection withPrinterLanguage:printerLanguage];
        return printer;
    } @catch (NSException *exception) {
        NSLog(@"Exception getting printer instance with language: %@", exception);
        return nil;
    }
}

#pragma mark - Printer Status Detection

+ (NSDictionary *)getPrinterStatus:(id)connection {
    if (!connection) {
        return @{
            @"isReadyToPrint": @NO,
            @"isHeadOpen": @NO,
            @"isPaperOut": @NO,
            @"isPaused": @NO,
            @"isRibbonOut": @NO,
            @"error": @"No connection"
        };
    }
    
    @try {
        id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:nil];
        if (!printer) {
            return @{
                @"isReadyToPrint": @NO,
                @"isHeadOpen": @NO,
                @"isPaperOut": @NO,
                @"isPaused": @NO,
                @"isRibbonOut": @NO,
                @"error": @"Failed to get printer instance"
            };
        }
        
        NSError *error = nil;
        PrinterStatus *status = [printer getCurrentStatus:&error];
        
        if (error) {
            return @{
                @"isReadyToPrint": @NO,
                @"isHeadOpen": @NO,
                @"isPaperOut": @NO,
                @"isPaused": @NO,
                @"isRibbonOut": @NO,
                @"error": [error localizedDescription]
            };
        }
        
        // Return raw status data
        return @{
            @"isReadyToPrint": @(status.isReadyToPrint),
            @"isHeadOpen": @(status.isHeadOpen),
            @"isPaperOut": @(status.isPaperOut),
            @"isPaused": @(status.isPaused),
            @"isRibbonOut": @(status.isRibbonOut),
            @"isHeadCold": @(status.isHeadCold),
            @"isHeadTooHot": @(status.isHeadTooHot),
            @"isReceiveBufferFull": @(status.isReceiveBufferFull),
            @"isPartialFormatInProgress": @(status.isPartialFormatInProgress),
            @"labelLengthInDots": @(status.labelLengthInDots),
            @"numberOfFormatsInReceiveBuffer": @(status.numberOfFormatsInReceiveBuffer),
            @"labelsRemainingInBatch": @(status.labelsRemainingInBatch),
            @"error": @""
        };
        
    } @catch (NSException *exception) {
        return @{
            @"isReadyToPrint": @NO,
            @"isHeadOpen": @NO,
            @"isPaperOut": @NO,
            @"isPaused": @NO,
            @"isRibbonOut": @NO,
            @"error": [exception reason]
        };
    }
}

+ (NSDictionary *)getDetailedPrinterStatus:(id)connection {
    NSDictionary *basicStatus = [self getPrinterStatus:connection];
    
    if (!connection) {
        return basicStatus;
    }
    
    @try {
        // Get additional SGD settings
        NSString *alerts = [SGD GET:@"alerts.status" withPrinterConnection:connection error:nil];
        NSString *mediaType = [SGD GET:@"media.type" withPrinterConnection:connection error:nil];
        NSString *printMode = [SGD GET:@"print.tone" withPrinterConnection:connection error:nil];
        
        return @{
            @"basicStatus": basicStatus,
            @"alerts": alerts ?: @"",
            @"mediaType": mediaType ?: @"",
            @"printMode": printMode ?: @""
        };
        
    } @catch (NSException *exception) {
        return basicStatus;
    }
}

@end 