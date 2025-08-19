import 'package:intl/intl.dart';
import 'package:solar_database/screens/sales/add_sell_screen.dart'; // Assuming SaleItem is here

String generateInvoiceHtml({
  required String customerName,
  required String customerPhone,
  required String customerAddress,
  required List<SaleItem> items,
  required String paymentCurrency,
  required double discountAmountUSD,
  required double discountAmountIQD,
  required double paidAmountUSD,
  required double paidAmountIQD,
  required double totalPriceUSD,
  required double totalPriceIQD,
  required double balanceUSD,
  required double balanceIQD,
  required double iqdToUsdRate,
  required double discountPercent,
  required int warrantyMonths,
  required double warrantyPriceUSD,
  required double warrantyPriceIQD,
  required String logoUrl,
  required List<String> brandLogos,
  required String invoiceNumber,
  required DateTime invoiceDate,
}) {
  final iqdFormat = NumberFormat("#,##0", "en_US");
  final dateFormat = DateFormat('yyyy-MM-dd');

  final currencyDisplayName = paymentCurrency == 'IQD'
      ? 'دیناری عێراقی'
      : 'دۆلاری ئەمریکی';
  final currencySymbol = paymentCurrency == 'IQD' ? 'د.ع' : '\$';

  final formattedTotalPrice = paymentCurrency == 'USD'
      ? totalPriceUSD.toStringAsFixed(2)
      : iqdFormat.format(totalPriceIQD);
  final formattedDiscount = paymentCurrency == 'USD'
      ? discountAmountUSD.toStringAsFixed(2)
      : iqdFormat.format(discountAmountIQD);
  final formattedPaid = paymentCurrency == 'USD'
      ? paidAmountUSD.toStringAsFixed(2)
      : iqdFormat.format(paidAmountIQD);
  final formattedBalance = paymentCurrency == 'USD'
      ? balanceUSD.toStringAsFixed(2)
      : iqdFormat.format(balanceIQD);

  // Build table rows dynamically with 4 columns
  final rows = StringBuffer();
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final priceToShow = paymentCurrency == 'USD'
        ? item.price.toStringAsFixed(2)
        : iqdFormat.format(item.price * iqdToUsdRate);
    final subtotalToShow = paymentCurrency == 'USD'
        ? item.subtotal.toStringAsFixed(2)
        : iqdFormat.format(item.subtotal * iqdToUsdRate);

    rows.write('''
      <tr>
        <td class="item-name">${i + 1}. ${item.name}, ${item.model}</td>
        <td>${item.qty}</td>
        <td style="direction:ltr">$priceToShow $currencySymbol</td>
        <td style="direction:ltr">$subtotalToShow $currencySymbol</td>
      </tr>
    ''');
  }

  return """<!DOCTYPE html>
<html dir="rtl" lang="ckb">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>پسوڵەی فرۆشتن - $invoiceNumber</title>
    <style>
      @font-face {
        font-family: "K24";
        src: url("assets/fonts/K24KurdishBold-Bold.ttf") format("truetype");
        font-weight: normal;
        font-style: normal;
      }
      :root {
        --primary-color: #045c20;
        --light-primary-bg: #e6f4ea;
        --text-color: #333;
        --border-color: #dce5dd;
        --white-color: #fff;
        --page-bg-color: #f4f4f4;
        --header-bg-color: #f8f9fa;
        --footer-bg-color: #e0e0e0;
      }
      * {
        box-sizing: border-box;
        font-family: "K24", sans-serif;
      }
      body {
        font-family: "K24", sans-serif;
        margin: 0;
        padding: 0;
        background: var(--page-bg-color);
        color: var(--text-color);
        -webkit-print-color-adjust: exact;
        color-adjust: exact;
      }
      .invoice-container {
        max-width: 210mm;
        min-height: 297mm;
        margin: 20px auto;
        padding: 10mm;
        background: var(--white-color);
        box-shadow: 0 0 15px rgba(0, 0, 0, 0.07);
        display: flex;
        flex-direction: column;
      }
      header.page-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 20px;
        border-bottom: 3px solid var(--primary-color);
        padding-bottom: 15px;
      }
      .company-details {
        text-align: right;
        flex: 1;
      }
      /* English header */
      .english-header {
        text-align: left;
        flex: 1;
        direction: ltr;
        font-family: "K24", sans-serif;
      }
      .english-header h1 {
        font-size: 24px;
        color: var(--primary-color);
        margin: 0;
      }
      .english-header p {
        margin: 5px 0;
        font-size: 14px;
      }
      .company-name {
        font-weight: bold;
        font-size: 28px;
        color: var(--primary-color);
        margin: 0;
      }
      .company-slogan {
        font-size: 15px;
        margin: 5px 0 15px 0;
        color: #555;
      }
      .company-address {
        font-size: 14px;
        max-width: 250px;
      }
      .logo-container {
        flex-shrink: 0;
        text-align: center;
      }
      .main-logo {
        max-width: 155px;
        height: auto;
      }
      .contact-details {
        text-align: left;
        flex: 1;
      }
      .contact-details p {
        font-size: 14px;
        color: var(--primary-color);
        background: var(--light-primary-bg);
        padding: 5px 10px;
        border-radius: 6px;
        margin: 0 0 5px 0;
        direction: ltr;
        text-align: center;
        font-weight: bold;
      }
      .invoice-title {
        text-align: center;
        margin: 25px 0;
      }
      .invoice-title h1 {
        display: inline-block;
        margin: 0;
        font-size: 26px;
        font-weight: bold;
        color: var(--primary-color);
        padding: 8px 30px;
        border-bottom: 2px solid var(--border-color);
        border-top: 2px solid var(--border-color);
      }
      .customer-info {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 12px 20px;
        padding: 15px;
        border: 1px solid var(--border-color);
        border-radius: 8px;
        background: var(--header-bg-color);
        margin-bottom: 25px;
      }
      .info-item {
        display: grid;
        grid-template-columns: 100px 1fr;
        align-items: baseline;
        gap: 15px;
        font-size: 14px;
      }
      .info-item .label {
        font-weight: bold;
        color: #555;
      }
      .info-item .value {
        font-weight: bold;
      }
      table.items-table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 25px;
        font-size: 14px;
        border-radius: 8px;
        overflow: hidden;
      }
      .items-table th,
      .items-table td {
        border: 1px solid var(--border-color);
        padding: 12px;
        text-align: center;
      }
      .items-table thead tr {
        background: var(--primary-color);
        color: var(--white-color);
        font-size: 15px;
      }
      .items-table tbody tr:nth-child(even) {
        background: var(--header-bg-color);
      }
      .items-table tbody tr:hover {
        background: var(--light-primary-bg);
      }
      .items-table .item-name {
        text-align: right;
        width: 50%;
      }
      .invoice-summary {
        display: flex;
        flex-wrap: wrap;
        gap: 20px;
        margin-top: 20px;
        padding-top: 20px;
        border-top: 1px dashed var(--border-color);
      }
      .summary-notes {
        flex: 2 1 55%;
      }
      .summary-notes p {
        margin-top: 0;
        font-size: 13px;
        color: #666;
      }
      .summary-totals {
        flex: 1 1 40%;
        border: 1px solid var(--border-color);
        border-radius: 8px;
        overflow: hidden;
        background: var(--white-color);
      }
      .totals-row {
        display: flex;
        justify-content: space-between;
        padding: 12px;
        font-size: 14px;
        border-bottom: 1px solid var(--border-color);
      }
      .totals-row:last-child {
        border-bottom: none;
      }
      .totals-row .label {
        color: #333;
      }
      .totals-row .value {
        font-weight: bold;
        color: var(--text-color);
        direction: ltr;
      }
      .totals-row.final-total {
        background: var(--primary-color);
        color: var(--white-color);
        font-size: 16px;
        font-weight: bold;
      }
      .totals-row.final-total .value,
      .totals-row.final-total .label {
        color: var(--white-color);
      }
      .guarantee-section {
        display: flex;
        gap: 15px;
        margin-top: 15px;
      }
      .guarantee-box {
        flex: 1;
        border: 1px solid var(--border-color);
        border-radius: 8px;
        padding: 10px;
        text-align: center;
      }
      .guarantee-box h3 {
        margin: 0 0 10px 0;
        font-size: 14px;
        color: var(--primary-color);
        border-bottom: 1px solid var(--border-color);
        padding-bottom: 8px;
      }
      .guarantee-fill-area {
        min-height: 80px;
      }
      .page-footer {
        text-align: center;
        padding-top: 20px;
        margin-top: 30px;
        font-size: 13px;
        border-top: 1px solid var(--border-color);
        color: #777;
        background: var(--footer-bg-color);
        position: fixed;
        bottom: 0;
        width: 100%;
      }
      .footer-logos {
        display: flex;
        flex-wrap: wrap;
        justify-content: center;
        align-items: center;
        gap: 25px;
        margin-top: 15px;
      }
      .footer-logos img {
        max-height: 35px;
        max-width: 90px;
        object-fit: contain;
        filter: grayscale(1);
        opacity: 0.6;
        transition: filter 0.3s, opacity 0.3s;
      }
      .footer-logos img:hover {
        filter: grayscale(0);
        opacity: 1;
      }
      @media print {
        @page {
          size: A4;
          margin: 0;
        }
        body {
          background: var(--white-color);
        }
        .invoice-container {
          box-shadow: none;
          margin: 0;
          max-width: 100%;
          min-height: 297mm;
          padding: 15mm;
        }
        .page-footer {
          position: fixed;
          bottom: 10mm;
          left: 15mm;
          right: 15mm;
          width: calc(100% - 30mm);
          margin-top: 0;
        }
        .footer-logos img {
          filter: grayscale(1);
          opacity: 0.7;
        }
      }
      /* Arabic header styles */
      .arabic-header {
        font-family: "K24", sans-serif;
        text-align: right;
        flex: 1;
      }
      .arabic-header h1 {
        font-size: 24px;
        color: var(--primary-color);
        margin: 0;
      }
      .arabic-header p {
        margin: 5px 0;
        font-size: 14px;
      }

      .phone-numbers {
        display: flex;
        flex-direction: column;
        justify-content: flex-end;
        margin-top: 10px;
        gap: 5px;
        font-weight: bold;
      }
      .phone-numbers p {
        margin: 0;
      }
      .english-header .phone-numbers {
        justify-content: flex-start;
        align-items: flex-start;
        font-weight: bold;
      }
      .arabic-header .phone-numbers {
        justify-content: flex-end;
        align-items: flex-end;
      }
    </style>
  </head>
  <body>
    <div class="invoice-container">
      <header class="page-header">
        <div class="company-details">
          <div class="arabic-header">
            <h1>کۆدین ئینێرجی</h1>
            <p>بۆ دەستکەوتنی پێداویستییەکانی وزەی خۆر بە تاک / کۆ</p>
            <p>ناونیشان: هەڵەبجەی تازە - بازاڕی ‌هەڵەبجەیەکان</p>
          </div>
          <div class="phone-numbers">
            <p>5070 105 0772 - 1515 238 0770</p>
          </div>
        </div>
        <div class="logo-container">
          <img src="$logoUrl" class="main-logo" a alt="Company Logo" />
        </div>
        <div class="english-header">
          <h1>Codin Energy</h1>
          <p>For wholesale and retail solar energy needs</p>
          <p>Address: New Halabja - Halabja Bazaar</p>
          <div class="phone-numbers">
            <p>0750 107 2007 - 0750 103 6435</p>
          </div>
        </div>
      </header>

      <main>
        <section class="invoice-title">
          <h1>پسوڵەی فرۆشتن</h1>
        </section>

        <section class="customer-info">
          <div class="info-item">
            <span class="label">ناوی کڕیار:</span
            ><span class="value">$customerName</span>
          </div>
          <div class="info-item">
            <span class="label">ژمارەی وەسڵ:</span
            ><span class="value">#$invoiceNumber</span>
          </div>
          <div class="info-item">
            <span class="label">ژمارەی تەلەفۆن:</span
            ><span class="value" style="direction: ltr; text-align: right"
              >$customerPhone</span
            >
          </div>
          <div class="info-item">
            <span class="label">رێکەوت:</span
            ><span class="value">${dateFormat.format(invoiceDate)}</span>
          </div>
          <div class="info-item">
            <span class="label">ناونیشان:</span
            ><span class="value">$customerAddress</span>
          </div>
          <div class="info-item">
            <span class="label">جۆری دراو:</span
            ><span class="value">$currencyDisplayName ($currencySymbol)</span>
          </div>
        </section>

        <section class="table-container">
          <table class="items-table">
            <thead>
              <tr>
                <th class="item-name">کاڵا</th>
                <th>دانە</th>
                <th>نرخی تاک</th>
                <th>کۆی گشتی</th>
              </tr>
            </thead>
            <tbody>
              $rows
            </tbody>
          </table>
        </section>

        <section class="invoice-summary">
          <div class="summary-notes">
            <p>
              <strong>تێبینی:</strong> سوپاس بۆ متمانەتان! تکایە پسوڵەکە بپارێزن
              بۆ مەبەستی گەرەنتی.
            </p>
            ${warrantyMonths > 0 ? '''
            <div class="guarantee-section">
              <div class="guarantee-box">
                <h3>واژۆی فرۆشیار</h3>
                <div class="guarantee-fill-area"></div>
              </div>
              <div class="guarantee-box">
                <h3>واژۆی کڕیار</h3>
                <div class="guarantee-fill-area"></div>
              </div>
            </div>
            ''' : ''}
          </div>

          <div class="summary-totals">
            <div class="totals-row">
              <span class="label">کۆی گشتی:</span
              ><span class="value">$formattedTotalPrice $currencySymbol</span>
            </div>
            <div class="totals-row">
              <span class="label">داشکاندن ($discountPercent%):</span
              ><span class="value">$formattedDiscount $currencySymbol</span>
            </div>
            <div class="totals-row">
              <span class="label">پارەی وەرگیراو:</span
              ><span class="value">$formattedPaid $currencySymbol</span>
            </div>
            ${warrantyMonths > 0 ? '''
            <div class="totals-row">
              <span class="label">ماوەی گەرەنتی:</span
              ><span class="value">$warrantyMonths مانگ</span>
            </div>
            <div class="totals-row">
              <span class="label">نرخی گەرەنتی:</span
              ><span class="value"
                >${paymentCurrency == 'USD' ? warrantyPriceUSD.toStringAsFixed(2) : iqdFormat.format(warrantyPriceIQD)} $currencySymbol</span
              >
            </div>
            ''' : ''}
            <div class="totals-row final-total">
              <span class="label">کۆی ماوە:</span
              ><span class="value">$formattedBalance $currencySymbol</span>
            </div>
          </div>
        </section>
      </main>
    </div>
  </body>
</html>

""";
}
