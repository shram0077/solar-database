import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class InvoicePrintDebt extends StatefulWidget {
  final String htmlContent;

  const InvoicePrintDebt({super.key, required this.htmlContent});

  @override
  State<InvoicePrintDebt> createState() => _InvoicePrintDebtState();
}

class _InvoicePrintDebtState extends State<InvoicePrintDebt> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("پڕینت / Print"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () async {
              if (webViewController != null) {
                await webViewController!.evaluateJavascript(
                  source: "window.print();",
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              webViewController?.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: widget.htmlContent),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                // Automatically open print dialog on first load
                await controller.evaluateJavascript(source: "window.print();");
              },
              onLoadError: (controller, url, code, message) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Load error: $message')));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.print),
        onPressed: () async {
          if (webViewController != null) {
            await webViewController!.evaluateJavascript(
              source: "window.print();",
            );
          }
        },
      ),
    );
  }
}
