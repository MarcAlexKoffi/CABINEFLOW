// This implementation is conditionally imported only on Flutter Web.
// ignore_for_file: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'package:cabine_flow/features/customer_order/data/acquisition/customer_acquisition_source_common.dart';

const String _storageKey = 'izytel_acquisition_source_code';

String? resolveCustomerAcquisitionSourceCode() {
  final Uri uri = Uri.base;
  final String? fromUrl = normalizeCustomerAcquisitionSourceCode(
    uri.queryParameters['src'] ?? uri.queryParameters['sourceCode'],
  );

  if (fromUrl != null) {
    html.window.localStorage[_storageKey] = fromUrl;
    return fromUrl;
  }

  return normalizeCustomerAcquisitionSourceCode(
    html.window.localStorage[_storageKey],
  );
}
