import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackCheckoutScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _checkUrl(url);
          },
          onPageFinished: (String url) async {
            setState(() => _isLoading = false);
            _checkUrl(url);

            // Periodically check page content in case Paystack doesn't redirect the URL
            final content = await _controller.runJavaScriptReturningResult('document.body.innerText') as String;
            if (content.contains('Payment Successful') || content.contains('Successful')) {
              if (mounted) {
                Navigator.pop(context, true);
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _checkUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('trxref=') ||
        lowerUrl.contains('reference=') ||
        lowerUrl.contains('checkout/close') ||
        lowerUrl.contains('standard/close') ||
        lowerUrl.contains('callback')) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paystack Payment'),
        backgroundColor: const Color(0xFF6B3A82),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B3A82)),
            ),
        ],
      ),
    );
  }
}