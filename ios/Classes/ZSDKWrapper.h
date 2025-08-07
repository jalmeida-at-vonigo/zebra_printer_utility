#import <Foundation/Foundation.h>

@class ZebraPrinter;
@class ZebraPrinterConnection;
@class ZebraPrinterFactory;
@class TcpPrinterConnection;

@class SGD;

@interface ZSDKWrapper : NSObject

#pragma mark - Discovery

+ (NSArray *)discoverLocalPrintersWithTimeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverSubnetPrintersWithRange:(NSString *)subnetRange timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverDirectedBroadcastWithIp:(NSString *)ipAddress timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverMulticastWithHops:(NSInteger)hops timeout:(NSInteger)timeout error:(NSError **)error;

#pragma mark - Connection

+ (id)connectToPrinter:(NSString *)address port:(NSInteger)port isBluetoothConnection:(BOOL)isBluetooth;
+ (void)disconnect:(id)connection;
+ (BOOL)isConnected:(id)connection;
+ (BOOL)sendData:(NSData *)data toConnection:(id)connection;

#pragma mark - Printer Operations

+ (id)getPrinter:(id)connection;

#pragma mark - Printer Status Detection

+ (id)getPrinterStatus:(id)connection;
+ (NSString *)getAlerts:(id)connection;
+ (NSString *)getMediaType:(id)connection;
+ (NSString *)getPrintMode:(id)connection;
+ (NSDictionary *)getDetailedPrinterStatus:(id)connection;

#pragma mark - Settings

+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection;
+ (BOOL)setSetting:(NSString *)setting value:(NSString *)value onConnection:(id)connection;
+ (NSString *)readResponse:(id)connection;
+ (id)getPrinterInstance:(id)connection;

@end