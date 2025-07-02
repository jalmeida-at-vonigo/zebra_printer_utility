#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations to avoid exposing ZSDK types in the header
@class ZebraPrinter;
@class ZebraPrinterConnection;
@class NetworkDiscoverer;
@class MfiBtPrinterConnection;
@class TcpPrinterConnection;
@class DiscoveredPrinter;
@class DiscoveredPrinterNetwork;
@class PrinterStatus;
@class SGD;

@interface ZSDKWrapper : NSObject

// Discovery
+ (void)startNetworkDiscovery:(void (^)(NSArray *printers))success
                        error:(void (^)(NSString *error))error;

+ (void)startBluetoothDiscovery:(void (^)(NSArray *printers))success
                          error:(void (^)(NSString *error))error;

+ (void)stopDiscovery;

// Connection
+ (nullable id)connectToPrinter:(NSString *)address isBluetoothConnection:(BOOL)isBluetooth;
+ (void)disconnect:(id)connection;
+ (BOOL)isConnected:(nullable id)connection;

// Printing
+ (BOOL)sendData:(NSData *)data toConnection:(id)connection;

// Settings
+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection;
+ (BOOL)setSetting:(NSString *)setting value:(NSString *)value onConnection:(id)connection;

// Add printer language detection
+ (NSString *)getPrinterLanguage:(id)connection;
+ (id)getPrinterInstance:(id)connection;
+ (id)getPrinterInstanceWithLanguage:(id)connection language:(NSString *)language;

@end

NS_ASSUME_NONNULL_END