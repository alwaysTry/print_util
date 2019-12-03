//
//  PrintUtilManager.h
//  Runner
//
//  Created by HLL on 2019/12/2.
//  Copyright © 2019 The Chromium Authors. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PrintUtilManager : NSObject

@property(nonatomic, readonly, copy) NSString *currentIP;

+ (PrintUtilManager *)manager;

- (void)configWithIP:(NSString *)IP;

- (void)print:(NSString *)printContent;

@end

NS_ASSUME_NONNULL_END
