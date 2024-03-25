library flutter_paypal_checkout;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_paypal_payment/src/paypal_service.dart';

class PaypalCheckoutView extends StatefulWidget {
  final Function onSuccess, onCancel, onError;
  final String? note, clientId, secretKey;

  final Widget? loadingIndicator;
  final List? transactions;
  final bool? sandboxMode;
  const PaypalCheckoutView({
    Key? key,
    required this.onSuccess,
    required this.onError,
    required this.onCancel,
    required this.transactions,
    required this.clientId,
    required this.secretKey,
    this.sandboxMode = false,
    this.note = '',
    this.loadingIndicator,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PaypalCheckoutViewState();
  }
}

class PaypalCheckoutViewState extends State<PaypalCheckoutView> {
  String? checkoutUrl;
  String navUrl = '';
  String executeUrl = '';
  String tokenId = "";
  String accessToken = '';
  bool loading = true;
  bool pageloading = true;
  bool loadingError = false;
  late PaypalServices services;
  int pressed = 0;
  double progress = 0;
  final String returnURL = 'https://example.com/return';
  final String cancelURL = 'https://example.com/cancel';

  late InAppWebViewController webView;

  Map getTokenMap(String tokenId) {
    Map<String, dynamic> temp = {
      "token_id": tokenId,
    };
    return temp;
  }

  @override
  void initState() {
    services = PaypalServices(
      sandboxMode: widget.sandboxMode!,
      clientId: widget.clientId!,
      secretKey: widget.secretKey!,
    );

    super.initState();
    Future.delayed(Duration.zero, () async {
      try {
        Map getToken = await services.getAccessToken();

        if (getToken['token'] != null) {
          accessToken = getToken['token'];
          final dump = await services.getApprovalURL(accessToken);
          print(dump);
          checkoutUrl = dump["approvalUrl"];
          executeUrl = dump["executeUrl"];
          tokenId = dump["token_id"];
          setState(() {});
        } else {
          widget.onError("${getToken['message']}");
        }
      } catch (e) {
        widget.onError(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checkoutUrl != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Paypal Payment",
          ),
        ),
        body: Stack(
          children: <Widget>[
            InAppWebView(
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url;

                if (url.toString().contains(returnURL)) {
                  final body = getTokenMap(tokenId);
                  final res = await services.createPaypalPayment(
                    executeUrl: executeUrl,
                    payload: body,
                    accessToken: accessToken,
                  );
                  return NavigationActionPolicy.ALLOW;
                }
                if (url.toString().contains(cancelURL)) {
                  return NavigationActionPolicy.CANCEL;
                } else {
                  return NavigationActionPolicy.ALLOW;
                }
              },
              initialUrlRequest: URLRequest(url: Uri.parse(checkoutUrl!)),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  useShouldOverrideUrlLoading: true,
                ),
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                webView = controller;
              },
              onCloseWindow: (InAppWebViewController controller) {
                widget.onCancel();
              },
              onProgressChanged:
                  (InAppWebViewController controller, int progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
            ),
            progress < 1
                ? SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: progress,
                    ),
                  )
                : const SizedBox(),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Paypal Payment",
          ),
        ),
        body: Center(
            child:
                widget.loadingIndicator ?? const CircularProgressIndicator()),
      );
    }
  }

  void exceutePayment(Uri? url, BuildContext context) {
    final payerID = url!.queryParameters['PayerID'];
    if (payerID != null) {
      services.executePayment(executeUrl, payerID, accessToken).then(
        (id) {
          if (id['error'] == false) {
            widget.onSuccess(id);
          } else {
            widget.onError(id);
          }
        },
      );
    } else {
      widget.onError('Something went wront PayerID == null');
    }
  }
}
