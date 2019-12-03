//
//  HLPrinter.m
//  HLBluetoothDemo
//
//  Created by Harvey on 16/5/3.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import "Printer.h"

#import "UIImage+Bitmap.h"
#import "GCDAsyncSocket/GCDAsyncSocket.h"

#define kMargin 20
#define kPadding 2
#define kWidth 320

typedef NS_ENUM(NSInteger, HLPrinterStyle) {
    HLPrinterStyleDefault,
    HLPrinterStyleCustom
};

/** 文字对齐方式 */
typedef NS_ENUM(NSInteger, HLTextAlignment) {
    HLTextAlignmentLeft = 0x00,
    HLTextAlignmentCenter = 0x01,
    HLTextAlignmentRight = 0x02
};

@interface Printer ()
/** 将要打印的排版后的数据 */
@property (strong, nonatomic) NSMutableData *printerData;
@property (strong, nonatomic) GCDAsyncSocket *socketer;
@end

static NSInteger PrinterPagerWidth = 80; //打印机纸张宽度

@implementation Printer

+ (instancetype)sharedInstance {
    static Printer *sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (GCDAsyncSocket *)socketer {
    if (!_socketer) {
        _socketer = [[GCDAsyncSocket alloc] init];
    }
    return _socketer;
}

/*
 * 设置打印机纸张宽度
 */
+ (void)setPrinterPagerWidth:(NSInteger) width {
    PrinterPagerWidth = width;
}

/*
 * 获取打印机纸张宽度
 */
+ (NSInteger)printerPagerWidth {
    return PrinterPagerWidth;
}

/*
 * 设置打印机数据格式
 */
+ (Printer *)setPrinterWithContent:(NSString *)text {
    if (!text) {
        return nil;
    }

    NSString *prtString = [text stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSArray *strSet = [text componentsSeparatedByString:@"\n"];
    if (prtString) {
        strSet = [prtString componentsSeparatedByString:@"\n"];
    }
    Printer *printer = [[Printer alloc] init];
    
    for (NSString *str in strSet) {
        if ([str containsString:@"<QR-CODE>"]) {
            NSMutableString *mutableStr = [NSMutableString stringWithString:str];
            NSString *subString = [mutableStr substringFromIndex:@"<QR-CODE>".length];

            [printer appendQRCodeWithInfo:subString];
            [printer appendText:@"\n" alignment:HLTextAlignmentLeft];
        } else {
            [printer appendText:str alignment:HLTextAlignmentLeft];
        }
    }
    [printer appendText:@"\n\n" alignment:HLTextAlignmentLeft];
    [printer appendCut];
    return printer;
}

- (UIImage *)createNonInterpolatedUIImageFormCIImage:(CIImage *)image withSize:(CGFloat)size {
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    // create a bitmap image that we'll draw into a bitmap context at the desired size;
    size_t width = CGRectGetWidth(extent) * scale;
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    // Create an image with the contents of our bitmap
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    // Cleanup
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    return [UIImage imageWithCGImage:scaledImage];
}

- (CIImage *)createQRForString:(NSString *)qrString {
    // Need to convert the string to a UTF-8 encoded NSData object
    NSData *stringData = [qrString dataUsingEncoding:NSUTF8StringEncoding];
    // Create the filter
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    // Set the message content and error-correction level
    [qrFilter setValue:stringData forKey:@"inputMessage"];
    [qrFilter setValue:@"M" forKey:@"inputCorrectionLevel"];
    // Send the image back
    return qrFilter.outputImage;
}

+ (Printer *)setPrinterForOpenMoneyBox {
    Printer *printer = [[Printer alloc] init];
    [printer setOpenMoneyBox];
    return printer;
}

/*
 * 设置打印机数据格式并打印数据
 */
+ (void)printWithContent:(NSString *)text {
    if (!text || !text.length) {
        return ;
    }
    [Printer printText:text];
}

+ (void)printText:(NSString *)text {
    NSString *netPrinterIP = [[NSUserDefaults standardUserDefaults] objectForKey:@"printer_ip_adress"];
    if (netPrinterIP && netPrinterIP.length > 0) {
        // 链接
        NSError *error;
        [[Printer sharedInstance].socketer connectToHost:netPrinterIP onPort:9100 error:&error];
        if (!error) {
            // 准备好带格式的打印数据
            Printer *printer = [Printer setPrinterWithContent:text];
            NSData *data = [printer getFinalData];
            for (int i = 0; i < [data length]; i += 20) {
                if ((i + 20) < [data length]) {
                    NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, 20];
                    NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
                    [[Printer sharedInstance].socketer writeData:subData withTimeout:3 tag:0];
                    usleep(20 * 1000);
                } else {
                    NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
                    NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
                    [[Printer sharedInstance].socketer writeData:subData withTimeout:3 tag:0];
                    usleep(20 * 1000);
                }
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[Printer sharedInstance].socketer disconnect];
            });
        }
    }
}

+ (NSArray *)cloudPrintTagWithContents:(NSArray *)array1 printSize:(CGSize)size{
    
    NSMutableArray *printContents = [NSMutableArray arrayWithArray:array1];
    
    __block NSInteger index = NSNotFound;
    [printContents enumerateObjectsUsingBlock:^(NSString*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<LABELSIZE-[\\d]*-[\\d]*>" options:NSRegularExpressionCaseInsensitive error:&error];
        NSTextCheckingResult *result = [regex firstMatchInString:obj options:0 range:NSMakeRange(0, [obj length])];
        if (result) {
            *stop = YES;
            index = idx;
        }
    }];
    if (index != NSNotFound) {
        [printContents removeObjectAtIndex:index];
    }
    
    NSString *string = [printContents componentsJoinedByString:@"@"];
    NSArray *array = [string componentsSeparatedByString:@"<HLLFONT-PAPERCUT>"];
    NSMutableArray *arr = [NSMutableArray array];
    [array enumerateObjectsUsingBlock:^(NSString *str, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray *array = [str componentsSeparatedByString:@"@"];
        NSMutableArray *a = [NSMutableArray arrayWithArray:array];
        if ([a.firstObject isEqualToString:@""] ) {
            [a removeObject:a.firstObject];
        }
        if ([a.lastObject isEqualToString:@""] ) {
            [a removeObject:a.lastObject];
        }
        [arr addObject:a];
    }];
    CGFloat width = size.width;
    CGFloat height = size.height;
    NSMutableArray *cloudPrintArrays = [NSMutableArray array];
    [arr enumerateObjectsUsingBlock:^(NSArray *printArray, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableString *printerTagStr = [NSMutableString string];
        NSString *size = [NSString stringWithFormat:@"SIZE %.0f mm,%.0f mm\n\r",width,height];//@"SIZE 38 mm,29 mm\n\r";
        NSString *cap = @"GAP 2 mm,0 mm\n\r";
        NSString *direction = @"DIRECTION 1,0\n\r";
        NSString *reference = @"REFERENCE 0,0\n\r";
        NSString *set = @"SET TEAR 1\n\r";
        NSString *cls = @"CLS\n\r";
        [printerTagStr appendString:size];
        [printerTagStr appendString:cap];
        [printerTagStr appendString:direction];
        [printerTagStr appendString:reference];
        [printerTagStr appendString:set];
        [printerTagStr appendString:cls];
        NSInteger tagY = 5;
        for (NSString *str in printArray) {
            NSString *subString;
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<HLLFONT-[\\d]-[\\d]-[\\d]>" options:NSRegularExpressionCaseInsensitive error:&error];
            NSTextCheckingResult *result = [regex firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
            NSString *s = [str substringWithRange:result.range];
            NSInteger printFont = [self PrintFontWithHLLTag:s];
            subString = [[str componentsSeparatedByString:s] lastObject];
            NSString *tagSubStr = [NSString stringWithFormat:@"TEXT 5,%ld,\"TSS24.BF2\",0,%ld,%ld,\"%@\"\n\r",(long)tagY,(long)printFont,(long)printFont,subString];
            [printerTagStr appendString:tagSubStr];
            tagY += 25*printFont;
        }
        NSString *print = @"PRINT 1,1\n\r";
        NSString *sound = @"SOUND 2,100\n\r";
        [printerTagStr appendString:print];
        [printerTagStr appendString:sound];
        
        [cloudPrintArrays addObject:printerTagStr];
    }];
    return cloudPrintArrays;
    
}

+ (NSInteger)PrintFontWithHLLTag:(NSString *)tag {
    if ([tag containsString:@"1-"]) {
        return 1;
    }else if ([tag containsString:@"2-"]) {
        return 2;
    }
    return 1;
}

+ (NSData*)printTagContent:(NSString*)content{
    //测试标签打印机
    NSMutableString *printerTagStr = [NSMutableString string];
    NSString *size = @"SIZE 38 mm,29 mm\n\r";
    NSString *cap = @"GAP 2 mm,0 mm\n\r";
    NSString *direction = @"DIRECTION 1,0\n\r";
    NSString *reference = @"REFERENCE 0,0\n\r";
    NSString *set = @"SET TEAR 1\n\r";
    NSString *cls = @"CLS\n\r";
    [printerTagStr appendString:size];
    [printerTagStr appendString:cap];
    [printerTagStr appendString:direction];
    [printerTagStr appendString:reference];
    [printerTagStr appendString:set];
    [printerTagStr appendString:cls];
    long tagY = 5;
    NSArray * printArray = [content componentsSeparatedByString:@"\n"];
    for (NSString *str in printArray) {
        NSString *tagSubStr = [NSString stringWithFormat:@"TEXT 5,%ld,\"TSS24.BF2\",0,%d,%d,\"%@\"\n\r",tagY,1,1,str];
        [printerTagStr appendString:tagSubStr];
        tagY += 25;
    }
    
    NSString *print = @"PRINT 1,1\n\r";
    NSString *sound = @"SOUND 2,100\n\r";
    [printerTagStr appendString:print];
    [printerTagStr appendString:sound];
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data =[printerTagStr dataUsingEncoding:enc];

    return data;
}

+ (void)printWithPrintModelArr:(NSArray *_Nullable)currentPrintArr {
//    if ([allPrtModel.printerName containsString:@"BIAOQIAN-3"]) {
//        currentPrtModel.paperSize = CGSizeMake(58, 38);
//        currentPrtModel.isTagPrinter = YES;
//        [self printWithNetTAGPrinter:currentPrtModel];
//    } else if ([allPrtModel.printerName containsString:@"BIAOQIAN"]) {
//        currentPrtModel.paperSize = CGSizeMake(38, 29);
//        currentPrtModel.isTagPrinter = YES;
//        [self printWithNetTAGPrinter:currentPrtModel];
//    } else {
//        [self printWithNetPrinter:currentPrtModel];
//    }
}

- (instancetype)init {
    if (self = [super init]) {
        [self defaultSetting];
    }
    return self;
}

- (void)defaultSetting
{
    _printerData = [[NSMutableData alloc] init];
    
    // 1.初始化打印机
    Byte initBytes[] = {0x1B,0x40};
    [_printerData appendBytes:initBytes length:sizeof(initBytes)];
    // 2.设置行间距为1/6英寸，约34个点
    // 另一种设置行间距的方法看这个 @link{-setLineSpace:}
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
    // 3.设置字体:标准0x00，压缩0x01;
    Byte fontBytes[] = {0x1B,0x4D,0x00};
    [_printerData appendBytes:fontBytes length:sizeof(fontBytes)];
    
}

#pragma mark - -------------基本操作----------------
/**
 *  换行
 */
- (void)appendNewLine
{
    Byte nextRowBytes[] = {0x0A};
    [_printerData appendBytes:nextRowBytes length:sizeof(nextRowBytes)];
}

/**
 *  回车
 */
- (void)appendReturn
{
    Byte returnBytes[] = {0x0D};
    [_printerData appendBytes:returnBytes length:sizeof(returnBytes)];
}

/**
 *  设置对齐方式
 *
 *  @param alignment 对齐方式：居左、居中、居右
 */
- (void)setAlignment:(HLTextAlignment)alignment
{
    Byte alignBytes[] = {0x1B,0x61,alignment};
    [_printerData appendBytes:alignBytes length:sizeof(alignBytes)];
}

/**
 *  设置字体大小
 *
 *  @param fontSize 字号
 */
- (void)setFontSize:(NSInteger)fontSize
{
    Byte fontSizeBytes[] = {0x1D,0x21,fontSize};
    [_printerData appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

/**
 *  添加文字，不换行
 *
 *  @param text 文字内容
 */
- (void)setText:(NSString *)text
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [text dataUsingEncoding:enc];
    [_printerData appendData:data];
}

/**
 *  添加切纸
 */
- (void)appendCut {
    Byte cutBytes[] = {0x1B,0x69};
    [_printerData appendBytes:cutBytes length:sizeof(cutBytes)];
}

/**
 *  设置加粗
 */
- (void)setBold {
    Byte boldBytes[] = {0x1B,0x21,8};
    [_printerData appendBytes:boldBytes length:sizeof(boldBytes)];
}

/**
 *  取消加粗
 */
- (void)cancelBold {
    Byte boldBytes[] = {0x1B,0x21,0};
    [_printerData appendBytes:boldBytes length:sizeof(boldBytes)];
}

/**
 *  设置反白
 */
- (void)setAnti:(NSInteger)fontSize {
    Byte fontSizeBytes[] = {0x1D,0x42,fontSize};
    [_printerData appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

- (void)setOpenMoneyBox {
    Byte bytes[] = {27,112,0,50,50};
    [_printerData appendBytes:bytes length:sizeof(bytes)];
}

/**
 *  添加文字，不换行
 *
 *  @param text    文字内容
 *  @param maxChar 最多可以允许多少个字节,后面加...
 */
- (void)setText:(NSString *)text maxChar:(int)maxChar
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [text dataUsingEncoding:enc];
    if (data.length > maxChar) {
        data = [data subdataWithRange:NSMakeRange(0, maxChar)];
        text = [[NSString alloc] initWithData:data encoding:enc];
        if (!text) {
            data = [data subdataWithRange:NSMakeRange(0, maxChar - 1)];
            text = [[NSString alloc] initWithData:data encoding:enc];
        }
        text = [text stringByAppendingString:@"..."];
    }
    [self setText:text];
}

/**
 *  设置偏移文字
 *
 *  @param text 文字
 */
- (void)setOffsetText:(NSString *)text
{
    // 1.计算偏移量,因字体和字号不同，所以计算出来的宽度与实际宽度有误差(小字体与22字体计算值接近)
    NSDictionary *dict = @{NSFontAttributeName:[UIFont systemFontOfSize:22.0]};
    NSAttributedString *valueAttr = [[NSAttributedString alloc] initWithString:text attributes:dict];
    int valueWidth = valueAttr.size.width;
    
    // 2.设置偏移量
    [self setOffset:368 - valueWidth];
    
    // 3.设置文字
    [self setText:text];
}

/**
 *  设置偏移量
 *
 *  @param offset 偏移量
 */
- (void)setOffset:(NSInteger)offset
{
    NSInteger remainder = offset % 256;
    NSInteger consult = offset / 256;
    Byte spaceBytes2[] = {0x1B, 0x24, remainder, consult};
    [_printerData appendBytes:spaceBytes2 length:sizeof(spaceBytes2)];
}

/**
 *  设置行间距
 *
 *  @param points 多少个点
 */
- (void)setLineSpace:(NSInteger)points
{
    //最后一位，可选 0~255
    Byte lineSpace[] = {0x1B,0x33,60};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

/**
 *  设置二维码模块大小
 *
 *  @param size  1<= size <= 16,二维码的宽高相等
 */
- (void)setQRCodeSize:(NSInteger)size
{
    Byte QRSize [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x43,size};
    //    Byte QRSize [] = {29,40,107,3,0,49,67,size};
    [_printerData appendBytes:QRSize length:sizeof(QRSize)];
}

/**
 *  设置二维码的纠错等级
 *
 *  @param level 48 <= level <= 51
 */
- (void)setQRCodeErrorCorrection:(NSInteger)level
{
    Byte levelBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x45,level};
    //    Byte levelBytes [] = {29,40,107,3,0,49,69,level};
    [_printerData appendBytes:levelBytes length:sizeof(levelBytes)];
}

/**
 *  将二维码数据存储到符号存储区
 * [范围]:  4≤(pL+pH×256)≤7092 (0≤pL≤255,0≤pH≤27)
 * cn=49
 * fn=80
 * m=48
 * k=(pL+pH×256)-3, k就是数据的长度
 *
 *  @param info 二维码数据
 */
- (void)setQRCodeInfo:(NSString *)info
{
    NSInteger kLength = info.length + 3;
    NSInteger pL = kLength % 256;
    NSInteger pH = kLength / 256;
    
    Byte dataBytes [] = {0x1D,0x28,0x6B,pL,pH,0x31,0x50,48};
    //    Byte dataBytes [] = {29,40,107,pL,pH,49,80,48};
    [_printerData appendBytes:dataBytes length:sizeof(dataBytes)];
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
    [_printerData appendData:infoData];
}

/**
 *  打印之前存储的二维码信息
 */
- (void)printStoredQRData
{
    Byte printBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x51,48};
    //    Byte printBytes [] = {29,40,107,3,0,49,81,48};
    [_printerData appendBytes:printBytes length:sizeof(printBytes)];
}

#pragma mark - ------------function method ----------------
#pragma mark  文字
- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment
{
    [self appendText:text alignment:alignment fontSize:0x00];
}

- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment fontSize:(NSInteger)fontSize
{
    if ([text hasPrefix:@"<HLLFONT-PAPERCUT>"]) {
        [self appendText:@"\n\n\n" alignment:HLTextAlignmentLeft];
        [self appendCut];
        return;
    }
    NSRange range = [text rangeOfString:@"^<HLLFONT-[0-9]-[0-9]-[0-9].{0,2}>" options:NSRegularExpressionSearch];
    // 1.文字对齐方式
    [self setAlignment:alignment];
    
    if (range.location != NSNotFound) {
        NSInteger textWidth = [text substringFromIndex:9].integerValue - 1;
        NSInteger textHeight = [text substringFromIndex:11].integerValue - 1;
        NSInteger textSize = textWidth * 16 + textHeight;
        
        // 2.设置字符打印方式
        if ([text substringFromIndex:13].integerValue == 2) {
            [self setAnti:textSize];
        } else if ([text substringFromIndex:13].integerValue == 1) {
            [self setBold];
        }
        [self setFontSize:textSize];
        // 3.设置标题内容
        [self setText:[text substringWithRange:NSMakeRange(range.length, text.length - range.length)]];
    } else {
        // 2.设置字体
        [self setFontSize:fontSize];
        // 3.设置标题内容
        [self setText:text];
    }
    [self cancelBold];
    // 4.换行
    [self appendNewLine];
    if (fontSize != 0x00) {
        [self appendNewLine];
    }
    
}

- (void)appendTitle:(NSString *)title value:(NSString *)value
{
    [self appendTitle:title value:value fontSize:0x00];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value fontSize:(NSInteger)fontSize
{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:title];
    // 4.设置实际值
    [self setOffsetText:value];
    // 5.换行
    [self appendNewLine];
    if (fontSize != 0x00) {
        [self appendNewLine];
    }
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset
{
    [self appendTitle:title value:value valueOffset:offset fontSize:0x00];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset fontSize:(NSInteger)fontSize
{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:title];
    // 4.设置内容偏移量
    [self setOffset:offset];
    // 5.设置实际值
    [self setText:value];
    // 6.换行
    [self appendNewLine];
    if (fontSize != 0x00) {
        [self appendNewLine];
    }
}

- (void)appendLeftText:(NSString *)left middleText:(NSString *)middle rightText:(NSString *)right isTitle:(BOOL)isTitle
{
    [self setAlignment:HLTextAlignmentLeft];
    [self setFontSize:0x00];
    NSInteger offset = 0;
    if (!isTitle) {
        offset = 10;
    }
    
    if (left) {
        [self setText:left maxChar:10];
    }
    
    if (middle) {
        [self setOffset:150 + offset];
        [self setText:middle];
    }
    
    if (right) {
        [self setOffset:300 + offset];
        [self setText:right];
    }
    
    [self appendNewLine];
    
}

#pragma mark 图片
- (void)appendImage:(UIImage *)image alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    if (!image) {
        return;
    }
    
    // 1.设置图片对齐方式
    [self setAlignment:alignment];
    
    // 2.设置图片
    UIImage *newImage = [image imageWithscaleMaxWidth:maxWidth+30];

    NSData *imageData = [newImage bitmapData];
    [_printerData appendData:imageData];
    
    // 3.换行
    [self appendNewLine];
    
    // 4.打印图片后，恢复文字的行间距
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

- (void)appendBarCodeWithInfo:(NSString *)info
{
    [self appendBarCodeWithInfo:info alignment:HLTextAlignmentCenter maxWidth:300];
}

- (void)appendBarCodeWithInfo:(NSString *)info alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    UIImage *barImage = [UIImage barCodeImageWithInfo:info];
    [self appendImage:barImage alignment:alignment maxWidth:maxWidth];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size
{
    [self appendQRCodeWithInfo:info size:size alignment:HLTextAlignmentCenter];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size alignment:(HLTextAlignment)alignment
{
    [self setAlignment:alignment];
    [self setQRCodeSize:size];
    [self setQRCodeErrorCorrection:48];
    [self setQRCodeInfo:info];
    [self printStoredQRData];
    [self appendNewLine];
}

- (void)appendQRCodeWithInfo:(NSString *)info
{
    [self appendQRCodeWithInfo:info centerImage:nil alignment:HLTextAlignmentCenter maxWidth:140];
}

- (void)appendQRCodeWithInfo:(NSString *)info centerImage:(UIImage *)centerImage alignment:(HLTextAlignment)alignment maxWidth:(CGFloat )maxWidth
{
    UIImage *QRImage = [UIImage qrCodeImageWithInfo:info centerImage:centerImage width:maxWidth];
    [self appendImage:QRImage alignment:alignment maxWidth:maxWidth];
}

#pragma mark 其他
- (void)appendSeperatorLine
{
    // 1.设置分割线居中
    [self setAlignment:HLTextAlignmentCenter];
    // 2.设置字号
    [self setFontSize:0x00];
    // 3.添加分割线
    NSString *line = @"- - - - - - - - - - - - - - - -";
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [line dataUsingEncoding:enc];
    [_printerData appendData:data];
    // 4.换行
    [self appendNewLine];
}

- (void)appendFooter:(NSString *)footerInfo
{
    [self appendSeperatorLine];
    if (!footerInfo) {
        footerInfo = @"谢谢惠顾，欢迎下次光临！";
    }
    [self appendText:footerInfo alignment:HLTextAlignmentCenter];
}

- (NSData *)getFinalData
{
    return _printerData;
}

@end
