import 'dart:convert';

import 'package:dio/dio.dart';

import 'dart:async';
import 'dart:convert' as convert;

class PaypalServices {
  final String clientId, secretKey;

  final bool sandboxMode;
  PaypalServices({
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
  });

  getAccessToken() async {
    String baseUrl = sandboxMode
        ? "https://api-m.sandbox.paypal.com"
        : "https://api.paypal.com";

    try {
      var authToken = base64.encode(
        utf8.encode("$clientId:$secretKey"),
      );
      final response = await Dio()
          .post('$baseUrl/v1/oauth2/token?grant_type=client_credentials',
              options: Options(
                headers: {
                  'Authorization': 'Basic $authToken',
                  'Content-Type': 'application/x-www-form-urlencoded'
                },
              ));
      final body = response.data;
      return {
        'error': false,
        'message': "Success",
        'token': body["access_token"]
      };
    } on DioException {
      return {
        'error': true,
        'message': "Your PayPal credentials seems incorrect"
      };
    } catch (e) {
      return {
        'error': true,
        'message': "Unable to proceed, check your internet connection."
      };
    }
  }

  getApprovalURL(
    accessToken,
  ) async {
    String domain = sandboxMode
        ? "https://api-m.sandbox.paypal.com"
        : "https://api.paypal.com";

    try {
      final response = await Dio().post(
        '$domain/v1/billing-agreements/agreement-tokens',
        data: jsonEncode({
          "description": "Billing Agreement",
          "shipping_address": {
            "line1": "PO Box 9999",
            "city": "Walnut",
            "state": "California",
            "postal_code": "91789",
            "country_code": "US",
            "recipient_name": "John Doe"
          },
          "payer": {"payment_method": "Paypal"},
          "plan": {
            "type": "MERCHANT_INITIATED_BILLING",
            "merchant_preferences": {
              "return_url": "https://www.example.com",
              "cancel_url": "https://www.example.com",
              "notify_url": "https://www.example.com",
              "accepted_pymt_type": "INSTANT",
              "skip_shipping_address": false,
              "immutable_shipping_address": true
            }
          }
        }),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          },
        ),
      );

      final Map dump = response.data;
      print(dump);

      String tokenId = "";
      String executeUrl = "";
      String approvalUrl = "";
      if (dump.containsKey("token_id")) {
        tokenId = dump["token_id"];
        if (dump["links"] != null && dump["links"].length > 0) {
          List links = dump["links"];
          final item = links.firstWhere((o) => o["rel"] == "approval_url",
              orElse: () => null);
          if (item != null) {
            approvalUrl = item["href"];
          }
          final item1 =
              links.firstWhere((o) => o["rel"] == "self", orElse: () => null);
          if (item1 != null) {
            executeUrl = item1["href"];
          }
          return {
            "token_id": tokenId,
            "executeUrl": executeUrl,
            "approvalUrl": approvalUrl
          };
        }
      }
      return {};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Payment Failed.",
        'data': e.response?.data,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createBID(
    String approvalUrl,
    Map payload,
    String accessToken,
  ) async {
    final response = await Dio().get(
      approvalUrl,
      data: payload,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
      ),
    );

    final body = response.data;
    return body;
  }

  Future<Map> createPaypalPayment({
    String executeUrl = "",
    String accessToken = "",
    Map payload = const {},
  }) async {
    try {
      final response = await Dio().post(
        executeUrl,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          },
        ),
      );

      final body = response.data;
      print(body);
      if (body["links"] != null && body["links"].length > 0) {
        List links = body["links"];

        String executeUrl = "";
        String approvalUrl = "";
        final item =
            links.firstWhere((o) => o["rel"] == "self", orElse: () => null);
        if (item != null) {
          approvalUrl = item["href"];
        }
        final item1 =
            links.firstWhere((o) => o["rel"] == "execute", orElse: () => null);
        if (item1 != null) {
          executeUrl = item1["href"];
        }
        print(executeUrl);
        print("+++++++++");
        print(approvalUrl);
        return {"executeUrl": executeUrl, "approvalUrl": approvalUrl};
      }
      return {};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Payment Failed.",
        'data': e.response?.data,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<Map> executePayment(
    url,
    payerId,
    accessToken,
  ) async {
    try {
      final response = await Dio().post(url,
          data: convert.jsonEncode({"payer_id": payerId}),
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json'
            },
          ));

      final body = response.data;
      return {'error': false, 'message': "Success", 'data': body};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': "Payment Failed.",
        'data': e.response?.data,
      };
    } catch (e) {
      return {'error': true, 'message': e, 'exception': true, 'data': null};
    }
  }
}

