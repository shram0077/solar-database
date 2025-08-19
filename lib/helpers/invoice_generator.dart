import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart';

Future<Uint8List> generateInvoicePdf(Map<String, dynamic> saleData) async {
  final pdf = pw.Document();

  // 1. Load your custom Arabic font
  final fontData = await rootBundle.load(
    'assets/fonts/K24KurdishBold-Bold.ttf',
  );
  final arabicFont = pw.Font.ttf(fontData);

  final NumberFormat currencyFormat = NumberFormat.currency(symbol: '\$');

  final String invoiceNumber = saleData['id']?.toString() ?? 'N/A';
  final DateTime saleDate = DateTime.parse(
    saleData['sale_date'] ?? DateTime.now().toIso8601String(),
  );
  final String customerName = saleData['customer_name'] ?? 'کڕیارێکی بەشداربوو';
  final String customerPhone = saleData['customer_phone'] ?? 'نەزانراو';
  final String customerAddress = saleData['customer_address'] ?? 'نەزانراو';
  final String itemName = saleData['item_name'] ?? 'نەزانراو';
  final int quantity = saleData['quantity'] ?? 0;
  final double sellingPrice = saleData['selling_price'] ?? 0.0;
  final double totalAmount = saleData['total_amount'] ?? 0.0;
  final double discountAmount =
      (saleData['total_amount'] * (saleData['discount'] ?? 0)) / 100;
  final double finalAmount = saleData['final_amount'] ?? 0.0;
  final String paymentMethod = saleData['payment_method'] ?? 'نەزانراو';
  final String notes = saleData['notes'] ?? '';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: arabicFont),
      textDirection: pw.TextDirection.rtl,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'پێشانگای ڕەئد',
                  style: pw.TextStyle(font: arabicFont, fontSize: 24),
                ),
                pw.BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data:
                      'پیشفاکتۆر: $invoiceNumber، بڕ: ${currencyFormat.format(finalAmount)}',
                  width: 80,
                  height: 80,
                ),
              ],
            ),
            pw.Divider(height: 20),

            // Company and Invoice Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'زانیاری کۆمپانیا:',
                      style: pw.TextStyle(font: arabicFont),
                    ),
                    pw.Text(
                      'پێشانگای تازە، بازاڕی هەڵەبجە',
                      style: pw.TextStyle(font: arabicFont),
                    ),
                    pw.Text(
                      'contact@solarcompany.com',
                      style: pw.TextStyle(font: arabicFont),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ژمارەی پیشفاکتۆر: $invoiceNumber',
                      style: pw.TextStyle(font: arabicFont),
                    ),
                    pw.Text(
                      'بەروار: ${DateFormat.yMMMd().format(saleDate)}',
                      style: pw.TextStyle(font: arabicFont),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Customer Info
            pw.Text('زانیاری کڕیار:', style: pw.TextStyle(font: arabicFont)),
            pw.Text(customerName, style: pw.TextStyle(font: arabicFont)),
            pw.Text(customerPhone, style: pw.TextStyle(font: arabicFont)),
            pw.Text(customerAddress, style: pw.TextStyle(font: arabicFont)),
            pw.SizedBox(height: 30),

            // Items Table
            pw.Table.fromTextArray(
              headers: ['ناوی کاڵا', 'ژمارە', 'نرخی دانە', 'کۆی گشتی'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
              cellStyle: pw.TextStyle(font: arabicFont),
              cellAlignment: pw.Alignment.centerRight,
              data: [
                [
                  itemName,
                  quantity.toString(),
                  currencyFormat.format(sellingPrice),
                  currencyFormat.format(totalAmount),
                ],
              ],
            ),
            pw.Divider(),

            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'کۆی گشتی: ',
                          style: pw.TextStyle(font: arabicFont),
                        ),
                        pw.Text(
                          currencyFormat.format(totalAmount),
                          style: pw.TextStyle(font: arabicFont),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text(
                          'داشکاندن: ',
                          style: pw.TextStyle(font: arabicFont),
                        ),
                        pw.Text(
                          '-${currencyFormat.format(discountAmount)}',
                          style: pw.TextStyle(font: arabicFont),
                        ),
                      ],
                    ),
                    pw.Divider(height: 5),
                    pw.Row(
                      children: [
                        pw.Text(
                          'کۆی دوا: ',
                          style: pw.TextStyle(fontSize: 16, font: arabicFont),
                        ),
                        pw.Text(
                          currencyFormat.format(finalAmount),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                            font: arabicFont,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Payment & Notes
            pw.Text(
              'شێوازی پارەدان: $paymentMethod',
              style: pw.TextStyle(font: arabicFont),
            ),
            if (notes.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('تێبینی:', style: pw.TextStyle(font: arabicFont)),
              pw.Text(notes, style: pw.TextStyle(font: arabicFont)),
            ],

            // Footer
            pw.Expanded(child: pw.Container()),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'سوپاس بۆ کڕینەکەت!',
                style: pw.TextStyle(font: arabicFont),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
