//
//  HLPrinter.h
//  HLBluetoothDemo
//
//  Created by Harvey on 16/5/3.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class HLLPrintItemModel;

@interface Printer : NSObject

/*
 * 打印数据
 */
+ (void)printWithContent:(NSString *)text;

/*
 * 通过一个PrinterModel来连接网络打印机并且打印
 */
+ (void)printWithPrintModelArr:(NSArray *_Nullable)printArr;

//+ (NSData *)printTagContent:(NSString*)content;

@end
