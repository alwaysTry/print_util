//
//  PrintUtilManager.m
//  Runner
//
//  Created by HLL on 2019/12/2.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

#import "PrintUtilManager.h"
#import "Printer.h"

@interface PrintUtilManager ()
@property (nonatomic, copy) NSString *IP;
@property (nonatomic, copy) NSString *printContent;
@end

@implementation PrintUtilManager

+ (PrintUtilManager *)manager {
    static PrintUtilManager *sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSString *)currentIP {
    return [PrintUtilManager manager].IP;
};

- (void)configWithIP:(NSString *)IP {
    [PrintUtilManager manager].IP = IP;
}

- (void)print:(NSString *)printContent {
    [Printer printWithContent:printContent];
}

@end
