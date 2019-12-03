import 'dart:async';

import 'package:flutter/services.dart';

class PrintUtil {
  static const MethodChannel _channel = const MethodChannel('print_util');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static congigPrintIP(String IP) {
    // 判断ip是否合法
    bool isValid = PrintUtil.isValidIP(IP);
    if (!isValid) return;

    final Map<String, String> params = {"IP": IP};
    _channel.invokeMethod('congigPrintIP', params);
  }

  static print(String printContent, {String IP}) {
    if (printContent.length == 0) return;
    // 判断ip是否合法
    bool isValid = PrintUtil.isValidIP(IP);
    if (!isValid && IP.length > 0) return;

    final Map<String, String> params = {"IP": IP, "content": printContent};
    _channel.invokeMethod('print', params);
  }


  static bool isValidIP(String IPText) {
    // 1 首先检查字符串的长度 最短应该是0.0.0.0 7位 最长 000.000.000.000 15位
    if (IPText.length < 7 || IPText.length > 15) return false;

    // 2 尝试按.符号进行拆分     拆分结果应该是4段
    List<String> arr = IPText.split(".");
    if (arr.length != 4) return false;

    // 3 查看拆分到的每一个子字符串，应该都是纯数字
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < arr[i].length; j++) {
        String temp = arr[i].substring(j, j);
        int value = int.parse(temp);
        if (!(value > 0 && value < 9)) return false; //如果某个字符不是数字就返回false
      }
    }

    // 4 对拆分结果转成整数 判断 应该是0到255之间的整数
    for (int i = 0; i < 4; i++) {
      int temp = int.parse(arr[i]);
      if (temp < 0 || temp > 255) return false; //如果某个数字不是0到255之间的数 就返回false
    }

    return true;
  }
}
