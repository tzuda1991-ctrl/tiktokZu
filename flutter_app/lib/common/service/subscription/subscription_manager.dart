import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/const_res.dart';

bool isPurchaseConfig = false;
RxBool isSubscribe = false.obs;

class SubscriptionManager {
  static var shared = SubscriptionManager();
  List<Package> packages = [];
  List<Package> offering = [];

  Future<void> initPlatformState() async {
    try {
      PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        if (revenueCatAndroidApiKey.isNotEmpty &&
            !revenueCatAndroidApiKey.startsWith('your_')) {
          configuration = PurchasesConfiguration(revenueCatAndroidApiKey);
          Purchases.setLogLevel(LogLevel.debug);
          await Purchases.configure(configuration);
        }
      } else if (Platform.isIOS) {
        if (revenueCatAppleApiKey.isNotEmpty &&
            !revenueCatAppleApiKey.startsWith('your_')) {
          configuration = PurchasesConfiguration(revenueCatAppleApiKey);
          Purchases.setLogLevel(LogLevel.debug);
          await Purchases.configure(configuration);
        }
      }
      await checkIsConfigured();
      if (isPurchaseConfig) {
        await fetchOfferings();
      }
    } catch (e) {
      log('SubscriptionManager init error: $e');
    }
  }

  bool checkSubscription(CustomerInfo customerInfo) {
    if (customerInfo.latestExpirationDate == null ||
        customerInfo.latestExpirationDate!.isEmpty) {
      isSubscribe.value = false;
    } else {
      DateTime dt1 =
          DateTime.parse(customerInfo.latestExpirationDate ?? '').toLocal();
      DateTime dt2 = DateTime.now();

      int leftSecond = dt1.difference(dt2).inSeconds;
      log('⏱️ Expire Time : $dt1 == Current Time : $dt2 || Time Left: ${leftSecond > 0 ? leftSecond : 0} seconds');
      if (dt1.compareTo(dt2) < 0) {
        isSubscribe.value = false;
      }
      if (dt1.compareTo(dt2) > 0) {
        isSubscribe.value = true;
      }
    }

    log('🔔 Subscription Status : ${isSubscribe.value ? 'Active' : 'InActive'}');
    return isSubscribe.value;
  }

  Future<void> subscriptionListener() async {
    if (!isPurchaseConfig) return;
    try {
      Purchases.addCustomerInfoUpdateListener((customerInfo) async {
        int status = checkSubscription(customerInfo) ? 1 : 0;
        User? user = SessionManager.instance.getUser();
        if (user?.isVerify == status) {
          return;
        }
        UserService.instance.updateUserDetails(isVerify: status);
      });
    } catch (e) {
      log('RevenueCat Error : $e');
    }
  }

  Future<void> checkIsConfigured() async {
    try {
      isPurchaseConfig = await Purchases.isConfigured;
      log('isPurchaseConfig  :$isPurchaseConfig');
    } catch (e) {
      isPurchaseConfig = false;
    }
  }

  Future<LogInResult?> login(String appUserID) async {
    if (!isPurchaseConfig) return null;
    try {
      return await Purchases.logIn(appUserID);
    } catch (e) {
      log('RevenueCat login error: $e');
      return null;
    }
  }

  Future<(Offering?, String?)> fetchOfferings() async {
    if (!isPurchaseConfig) return (null, null);
    try {
      Offerings offerings = await Purchases.getOfferings();
      offering.addAll(offerings.current?.availablePackages
              .where((element) => element.packageType == PackageType.custom) ??
          []);
      packages.addAll(offerings.current?.availablePackages
              .where((element) => element.packageType != PackageType.custom) ??
          []);
      packages
          .sort((a, b) => b.storeProduct.price.compareTo(a.storeProduct.price));

      return (offerings.current, null);
    } catch (e) {
      log('Fetch Offering : $e');
      return (null, e.toString());
    }
  }

  Future<bool?> checkSubscriptionStatus() async {
    if (!isPurchaseConfig) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return checkSubscription(customerInfo);
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  Future<bool?> makePurchase(Package package) async {
    if (!isPurchaseConfig) return null;
    try {
      CustomerInfo customerInfo = (await Purchases.purchase(
              PurchaseParams.storeProduct(package.storeProduct)))
          .customerInfo;
      return checkSubscription(customerInfo);
    } catch (e) {
      log("makePurchase $e");
      return null;
    }
  }

  Future<CustomerInfo?> makePurchaseCustom(Package package) async {
    if (!isPurchaseConfig) return null;
    try {
      CustomerInfo info = (await Purchases.purchase(
              PurchaseParams.storeProduct(package.storeProduct)))
          .customerInfo;
      return info;
    } catch (e) {
      log("makePurchaseCustom: $e");
      return null;
    }
  }

  Future<bool?> restorePurchase() async {
    if (!isPurchaseConfig) return null;
    try {
      CustomerInfo restoredInfo = await Purchases.restorePurchases();
      return checkSubscription(restoredInfo);
    } catch (e) {
      log(e.toString());
      return null;
    }
  }
}
