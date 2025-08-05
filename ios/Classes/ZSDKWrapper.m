#import "ZSDKWrapper.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterConnection.h"
#import "ZebraPrinterFactory.h"
#import "TcpPrinterConnection.h"
#import "MfiBtPrinterConnection.h"

#import "SGD.h"
#import "PrinterStatus.h"
#import "PrinterStatusMessages.h"

@implementation ZSDKWrapper

#pragma mark - Discovery



#pragma mark - Connection

+ (id)connectToPrinter:(NSString *)address port:(NSInteger)port isBluetoothConnection:(BOOL)isBluetooth {
    id<ZebraPrinterConnection,NSObject> connection = nil;
    
    if (isBluetooth) {
        // MFi Bluetooth connection
        connection = [[MfiBtPrinterConnection alloc] initWithSerialNumber:address];
    } else {
        // Network connection with parsed address and port
        connection = [[TcpPrinterConnection alloc] initWithAddress:address andWithPort:port];
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

+ (NSString *)readResponse:(id)connection {
    if (!connection) return nil;

    @try {
        NSError *readError = nil;
        NSData *responseData = [connection read:&readError];
        
        if (responseData && !readError) {
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            return response;
        }
    } @catch (NSException *exception) {
        NSLog(@"Failed to read response: %@", exception);
    }
    
    return nil;
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



#pragma mark - Printer Status Detection

+ (id)getPrinterStatus:(id)connection {
    if (!connection) return nil;
    
    @try {
        id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:nil];
        if (!printer) return nil;
        
        NSError *error = nil;
        PrinterStatus *status = [printer getCurrentStatus:&error];
        
        return error ? nil : status;
    } @catch (NSException *exception) {
        NSLog(@"Failed to get printer status: %@", exception);
        return nil;
    }
}

+ (NSString *)getAlerts:(id)connection {
    if (!connection) return nil;
    return [SGD GET:@"alerts.status" withPrinterConnection:connection error:nil];
}

+ (NSString *)getMediaType:(id)connection {
    if (!connection) return nil;
    return [SGD GET:@"media.type" withPrinterConnection:connection error:nil];
}

+ (NSString *)getPrintMode:(id)connection {
    if (!connection) return nil;
    return [SGD GET:@"print.tone" withPrinterConnection:connection error:nil];
}

@end 