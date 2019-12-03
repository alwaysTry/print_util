#import "PrintUtilPlugin.h"
#import <print_util/print_util-Swift.h>
#import "PrintUtilManager.h"

@implementation PrintUtilPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"com.duolaidian.print"
binaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSString *content;
    NSString *IP;
    NSString *paperWidth = @"80";
    
    if ([@"congigPrintIP" isEqualToString:call.method]) {
        IP = call.arguments[@"IP"];
        [[PrintUtilManager manager] configWithIP:IP];
        
    } else if ([@"print" isEqualToString:call.method]) {
        content = call.arguments[@"content"];
        IP = call.arguments[@"IP"];
        if (!IP) {
            IP = [PrintUtilManager manager].currentIP;
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:IP forKey:@"printer_ip_adress"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        paperWidth = call.arguments[@"paperWidth"];
        if (!paperWidth) {
            paperWidth = @"80";
        }

        [[PrintUtilManager manager] print:content];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
