import 'package:universal_platform/universal_platform.dart';

abstract class DesktopPlatform {

  static bool get isDesktop {
    return !(UniversalPlatform.isAndroid || UniversalPlatform.isIOS);
  }

}