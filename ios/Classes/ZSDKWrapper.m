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
                    NSString *printerAddress = nil;
                    NSString *printerName = nil;
                    
                    if ([printer isKindOfClass:[DiscoveredPrinterNetwork class]]) {
                        DiscoveredPrinterNetwork *networkPrinter = (DiscoveredPrinterNetwork *)printer;
                        printerAddress = networkPrinter.address;
                        printerName = networkPrinter.dnsName ?: networkPrinter.address;
                        
                        if (printerAddress && printerAddress.length > 0) {
                            info[@"address"] = printerAddress;
                            info[@"port"] = @(networkPrinter.port);
                            info[@"name"] = printerName ?: @"Unknown";
                            info[@"isWifi"] = @YES;
                            info[@"isBluetooth"] = @NO;
                            info[@"connectionType"] = @"Network";
                            
                            // Add Zebra branding information
                            info[@"brand"] = @"Zebra";
                            info[@"displayName"] = [NSString stringWithFormat:@"Zebra Printer - %@", printerName ?: @"Unknown"];
                            
                            // Try to get printer model information via SGD
                            @try {
                                TcpPrinterConnection *tempConnection = [[TcpPrinterConnection alloc] initWithAddress:printerAddress andWithPort:networkPrinter.port];
                                if ([tempConnection open]) {
                                    NSString *model = [SGD GET:@"appl.name" withPrinterConnection:tempConnection error:nil];
                                    if (model && model.length > 0) {
                                        info[@"model"] = model;
                                        info[@"displayName"] = [NSString stringWithFormat:@"Zebra %@ - %@", model, printerName ?: @"Unknown"];
                                    }
                                    [tempConnection close];
                                }
                            } @catch (NSException *exception) {
                                // Ignore errors when trying to get model info
                            }
                        }
                        
                    } else if ([printer isKindOfClass:[DiscoveredPrinter class]]) {
                        DiscoveredPrinter *discoveredPrinter = (DiscoveredPrinter *)printer;
                        printerAddress = discoveredPrinter.address;
                        printerName = discoveredPrinter.address;
                        
                        if (printerAddress && printerAddress.length > 0) {
                            info[@"address"] = printerAddress;
                            info[@"name"] = printerName ?: @"Unknown";
                            info[@"isWifi"] = @YES;
                            info[@"isBluetooth"] = @NO;
                            info[@"connectionType"] = @"Network";
                            
                            // Add Zebra branding information
                            info[@"brand"] = @"Zebra";
                            info[@"displayName"] = [NSString stringWithFormat:@"Zebra Printer - %@", printerName ?: @"Unknown"];
                        }
                    }
                    
                    // Only add printer if it has a valid address
                    if (printerAddress && printerAddress.length > 0) {
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
            
            // Find Zebra Bluetooth Accessories using External Accessory framework
            EAAccessoryManager *accessoryManager = [EAAccessoryManager sharedAccessoryManager];
            NSArray *connectedAccessories = [accessoryManager connectedAccessories];
            
            for (EAAccessory *accessory in connectedAccessories) {
                // Check if this is a Zebra printer (has the Zebra protocol)
                if ([accessory.protocolStrings indexOfObject:@"com.zebra.rawport"] != NSNotFound) {
                    NSString *serialNumber = accessory.serialNumber;
                    NSString *name = accessory.name;
                    
                    // Only add printer if it has a valid serial number
                    if (serialNumber && serialNumber.length > 0) {
                        NSMutableDictionary *info = [NSMutableDictionary dictionary];
                        info[@"Address"] = serialNumber;
                        info[@"Name"] = name ?: @"Zebra Printer";
                        info[@"model"] = accessory.modelNumber ?: @"Unknown Model";
                        info[@"manufacturer"] = accessory.manufacturer ?: @"Zebra";
                        info[@"firmwareRevision"] = accessory.firmwareRevision ?: @"";
                        info[@"hardwareRevision"] = accessory.hardwareRevision ?: @"";
                        info[@"Status"] = @"Connected";
                        info[@"IsWifi"] = @NO;
                        info[@"isBluetooth"] = @YES;
                        info[@"connectionType"] = @"MFi Bluetooth";
                        
                        // Add Zebra branding information
                        info[@"brand"] = @"Zebra";
                        info[@"displayName"] = [NSString stringWithFormat:@"%@ %@", name ?: @"Zebra Printer", accessory.modelNumber ?: @""];
                        
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
        // Network connection
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
        
        // Send the data
        BOOL success = [printerConnection write:data error:&error];
        
        if (success && !error) {
            // For CPCL data, ensure complete transmission
            // Check if data contains CPCL commands (starts with "!" or contains CPCL markers)
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (dataString && ([dataString hasPrefix:@"!"] || [dataString containsString:@"! 0"])) {
                // Add a small delay to ensure CPCL data is fully transmitted
                // This prevents the connection from closing before all data is sent
                [NSThread sleepForTimeInterval:0.1];
                
                // If the data doesn't end with ETX, the connection might need explicit flushing
                // The ZSDK doesn't provide a flush method, but we can ensure the write completes
                // by checking connection status
                if ([printerConnection isConnected]) {
                    // Connection is still good, data should be transmitted
                    return YES;
                }
            }
            return YES;
        }
        
        return NO;
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
        
        // Read the response
        NSMutableData *responseData = [NSMutableData data];
        NSInteger maxTimeout = timeout > 0 ? timeout : 5000; // Default 5 seconds
        NSInteger timeToWait = 100; // Wait 100ms between reads
        
        // Set connection timeouts
        if ([connection respondsToSelector:@selector(setMaxTimeoutForRead:)]) {
            [connection setMaxTimeoutForRead:maxTimeout];
        }
        if ([connection respondsToSelector:@selector(setTimeToWaitForMoreData:)]) {
            [connection setTimeToWaitForMoreData:timeToWait];
        }
        
        // Read response
        NSError *readError = nil;
        NSData *readData = [connection read:&readError];
        
        if (readData && !readError) {
            [responseData appendData:readData];
            
            // Continue reading while data is available
            while (readData && readData.length > 0) {
                readData = [connection read:&readError];
                if (readData && !readError) {
                    [responseData appendData:readData];
                } else {
                    break;
                }
            }
        }
        
        if (responseData.length > 0) {
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
        // Try to get the language without creating a printer instance first
        NSError *error = nil;
        NSString *deviceLanguages = [SGD GET:@"device.languages" withPrinterConnection:connection error:&error];
        
        if (!error && deviceLanguages) {
            NSString *lowerLanguages = [deviceLanguages lowercaseString];
            if ([lowerLanguages containsString:@"zpl"]) {
                return @"ZPL";
            } else if ([lowerLanguages containsString:@"cpcl"] || [lowerLanguages containsString:@"line_print"]) {
                return @"CPCL";
            }
        }
        
        // Only fall back to factory method if we couldn't determine from device.languages
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
        
        // Get human-readable status messages
        PrinterStatusMessages *statusMessages = [[PrinterStatusMessages alloc] initWithPrinterStatus:status];
        NSArray *messages = [statusMessages getStatusMessage];
        NSString *statusDescription = @"";
        
        if (status.isReadyToPrint) {
            statusDescription = @"Ready to print";
        } else if (messages && messages.count > 0) {
            statusDescription = [messages componentsJoinedByString:@"; "];
        } else {
            statusDescription = @"Unknown status";
        }
        
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
            @"statusDescription": statusDescription,
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

+ (BOOL)waitForPrintCompletion:(id)connection timeout:(NSInteger)timeoutSeconds {
    if (!connection) return NO;
    
    NSDate *startTime = [NSDate date];
    NSInteger timeoutMs = timeoutSeconds * 1000;
    NSInteger checkIntervalMs = 500; // Check every 500ms
    
    while ([[NSDate date] timeIntervalSinceDate:startTime] * 1000 < timeoutMs) {
        @try {
            NSDictionary *status = [self getPrinterStatus:connection];
            
            // Check if there are any blocking issues
            BOOL isHeadOpen = [status[@"isHeadOpen"] boolValue];
            BOOL isPaperOut = [status[@"isPaperOut"] boolValue];
            BOOL isPaused = [status[@"isPaused"] boolValue];
            BOOL isRibbonOut = [status[@"isRibbonOut"] boolValue];
            BOOL isPartialFormatInProgress = [status[@"isPartialFormatInProgress"] boolValue];
            
            // If there are hardware issues, return NO (print failed)
            if (isHeadOpen || isPaperOut || isRibbonOut) {
                return NO;
            }
            
            // If printer is paused, wait for it to resume
            if (isPaused) {
                [NSThread sleepForTimeInterval:checkIntervalMs / 1000.0];
                continue;
            }
            
            // For ZPL printers, check if partial format is in progress
            if (isPartialFormatInProgress) {
                [NSThread sleepForTimeInterval:checkIntervalMs / 1000.0];
                continue;
            }
            
            // Check if ready to print (indicating previous job completed)
            BOOL isReadyToPrint = [status[@"isReadyToPrint"] boolValue];
            if (isReadyToPrint) {
                return YES;
            }
            
            // Wait before next check
            [NSThread sleepForTimeInterval:checkIntervalMs / 1000.0];
            
        } @catch (NSException *exception) {
            NSLog(@"Error checking print completion: %@", [exception reason]);
            return NO;
        }
    }
    
    // Timeout reached
    return NO;
}

+ (NSDictionary *)getDetailedPrinterStatus:(id)connection {
    NSDictionary *basicStatus = [self getPrinterStatus:connection];
    
    if (!connection) {
        return @{
            @"basicStatus": basicStatus,
            @"canPrint": @NO,
            @"blockingIssues": @[],
            @"recommendations": @[@"Check printer connection"]
        };
    }
    
    @try {
        // Get additional SGD settings for more detailed status
        NSString *alerts = [SGD GET:@"alerts.status" withPrinterConnection:connection error:nil];
        NSString *mediaType = [SGD GET:@"media.type" withPrinterConnection:connection error:nil];
        NSString *printMode = [SGD GET:@"print.tone" withPrinterConnection:connection error:nil];
        
        // Analyze status and provide recommendations
        NSMutableArray *blockingIssues = [NSMutableArray array];
        NSMutableArray *recommendations = [NSMutableArray array];
        BOOL canPrint = YES;
        
        // Check basic status issues
        if ([basicStatus[@"isHeadOpen"] boolValue]) {
            [blockingIssues addObject:@"Printer head is open"];
            [recommendations addObject:@"Close the printer head/lid and try again"];
            canPrint = NO;
        }
        
        if ([basicStatus[@"isPaperOut"] boolValue]) {
            [blockingIssues addObject:@"Out of paper/media"];
            [recommendations addObject:@"Load paper/media and try again"];
            canPrint = NO;
        }
        
        if ([basicStatus[@"isRibbonOut"] boolValue]) {
            [blockingIssues addObject:@"Out of ribbon"];
            [recommendations addObject:@"Replace ribbon and try again"];
            canPrint = NO;
        }
        
        if ([basicStatus[@"isPaused"] boolValue]) {
            [blockingIssues addObject:@"Printer is paused"];
            [recommendations addObject:@"Press the pause button on the printer to resume"];
            canPrint = NO;
        }
        
        if ([basicStatus[@"isHeadCold"] boolValue]) {
            [blockingIssues addObject:@"Print head is cold"];
            [recommendations addObject:@"Wait for print head to warm up"];
            canPrint = NO;
        }
        
        if ([basicStatus[@"isHeadTooHot"] boolValue]) {
            [blockingIssues addObject:@"Print head is too hot"];
            [recommendations addObject:@"Wait for print head to cool down"];
            canPrint = NO;
        }
        
        // Check if ready to print
        if ([basicStatus[@"isReadyToPrint"] boolValue] && blockingIssues.count == 0) {
            [recommendations addObject:@"Printer is ready to print"];
        }
        
        return @{
            @"basicStatus": basicStatus,
            @"alerts": alerts ?: @"",
            @"mediaType": mediaType ?: @"",
            @"printMode": printMode ?: @"",
            @"canPrint": @(canPrint),
            @"blockingIssues": blockingIssues,
            @"recommendations": recommendations
        };
        
    } @catch (NSException *exception) {
        return @{
            @"basicStatus": basicStatus,
            @"canPrint": @NO,
            @"blockingIssues": @[@"Status check failed"],
            @"recommendations": @[@"Check printer connection and try again"]
        };
    }
}

@end 