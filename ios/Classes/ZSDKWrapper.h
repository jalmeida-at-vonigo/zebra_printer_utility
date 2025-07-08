#import <Foundation/Foundation.h>

@class ZebraPrinter;
@class ZebraPrinterConnection;
@class ZebraPrinterFactory;
@class TcpPrinterConnection;
@class NetworkDiscoverer;
@class DiscoveredPrinter;
@class DiscoveredPrinterNetwork;
@class SGD;

@interface ZSDKWrapper : NSObject

#pragma mark - Discovery

+ (void)startNetworkDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error;
+ (void)startMfiBluetoothDiscovery:(void (^)(NSArray *))success error:(void (^)(NSString *))error;
+ (void)stopDiscovery;

#pragma mark - Connection

+ (id)connectToPrinter:(NSString *)address isBluetoothConnection:(BOOL)isBluetooth;
+ (void)disconnect:(id)connection;
+ (BOOL)isConnected:(id)connection;
+ (BOOL)sendData:(NSData *)data toConnection:(id)connection;

#pragma mark - Printer Operations

+ (id)getPrinter:(id)connection;

#pragma mark - Printer Status Detection

+ (NSDictionary *)getPrinterStatus:(id)connection;

+ (NSDictionary *)getDetailedPrinterStatus:(id)connection;

#pragma mark - Settings

+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection;
+ (BOOL)setSetting:(NSString *)setting value:(NSString *)value onConnection:(id)connection;
+ (NSString *)sendAndReadResponse:(NSString *)data toConnection:(id)connection withTimeout:(NSInteger)timeout;

#pragma mark - Printer Language

+ (NSString *)getPrinterLanguage:(id)connection;
+ (id)getPrinterInstance:(id)connection;
+ (id)getPrinterInstanceWithLanguage:(id)connection language:(NSString *)language;

@end