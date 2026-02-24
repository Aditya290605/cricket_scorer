import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackService {
  static const String _feedbackEmail = 'a2c.studios.india@gmail.com';
  static const String _emailSubject = 'Cricket App – User Feedback';

  /// Returns a map with 'model' and 'osVersion' keys.
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return {
          'model': '${android.brand} ${android.model}',
          'osVersion':
              'Android ${android.version.release} (SDK ${android.version.sdkInt})',
        };
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return {
          'model': '${ios.name} ${ios.model}',
          'osVersion': '${ios.systemName} ${ios.systemVersion}',
        };
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    return {'model': 'Unknown', 'osVersion': 'Unknown'};
  }

  /// Returns a map with 'appVersion' and 'buildNumber' keys.
  static Future<Map<String, String>> getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      debugPrint('Error getting app info: $e');
      return {'appVersion': 'Unknown', 'buildNumber': 'Unknown'};
    }
  }

  /// Sends feedback by launching the native email client via mailto: URI.
  ///
  /// Returns `true` if the email client was launched successfully, `false` otherwise.
  static Future<bool> sendFeedback({
    required String userName,
    required String category,
    required String description,
    String? screenshotPath,
  }) async {
    try {
      final deviceInfo = await getDeviceInfo();
      final appInfo = await getAppInfo();
      final timestamp = DateTime.now().toIso8601String();

      final body = StringBuffer()
        ..writeln('--- User Feedback ---')
        ..writeln()
        ..writeln('User Name: $userName')
        ..writeln('Category: $category')
        ..writeln()
        ..writeln('Feedback:')
        ..writeln(description)
        ..writeln()
        ..writeln('--- Device & App Info ---')
        ..writeln('App Version: ${appInfo['appVersion']}')
        ..writeln('Build Number: ${appInfo['buildNumber']}')
        ..writeln('Device Model: ${deviceInfo['model']}')
        ..writeln('OS Version: ${deviceInfo['osVersion']}')
        ..writeln('Timestamp: $timestamp');

      if (screenshotPath != null) {
        body.writeln();
        body.writeln('Note: User selected a screenshot to attach.');
        body.writeln(
            'Please ask the user to manually attach it from their gallery.');
      }

      final mailtoUri = Uri(
        scheme: 'mailto',
        path: _feedbackEmail,
        queryParameters: {
          'subject': _emailSubject,
          'body': body.toString(),
        },
      );

      if (await canLaunchUrl(mailtoUri)) {
        return await launchUrl(mailtoUri);
      } else {
        // Fallback: try launching without canLaunchUrl check
        return await launchUrl(mailtoUri);
      }
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      return false;
    }
  }
}
