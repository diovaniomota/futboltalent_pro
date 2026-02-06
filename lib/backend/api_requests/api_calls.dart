import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

/// Start Countries States Cities API Group Code

class CountriesStatesCitiesAPIGroup {
  static String getBaseUrl() =>
      'https://countries-states-and-cities.p.rapidapi.com';
  static Map<String, String> headers = {};
  static FindNearbyCitiesCall findNearbyCitiesCall = FindNearbyCitiesCall();
}

class FindNearbyCitiesCall {
  Future<ApiCallResponse> call({
    String? radius = '',
    String? city = '',
    String? xRapidAPIKey = '',
    String? xRapidAPIHost = '',
  }) async {
    final baseUrl = CountriesStatesCitiesAPIGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'findNearbyCities',
      apiUrl: '${baseUrl}/findNearbyCities',
      callType: ApiCallType.GET,
      headers: {
        'X-RapidAPI-Key': '${xRapidAPIKey}',
        'X-RapidAPI-Host': '${xRapidAPIHost}',
      },
      params: {
        'radius': radius,
        'city': city,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End Countries States Cities API Group Code

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}
