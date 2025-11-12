import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:fruit_shop/services/user_data_api.dart';

class AdminInvoicePreviewPage extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const AdminInvoicePreviewPage({super.key, required this.invoice});

  @override
  State<AdminInvoicePreviewPage> createState() =>
      _AdminInvoicePreviewPageState();
}

class _AdminInvoicePreviewPageState extends State<AdminInvoicePreviewPage> {
  bool _isLoading = false;
  Uint8List? _lastPdfBytes;
  bool _pdfFontAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkPdfFontAvailable();
  }

  Future<void> _checkPdfFontAvailable() async {
    try {
      // try local assets first
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      if (mounted) setState(() => _pdfFontAvailable = true);
      return;
    } catch (_) {
      if (mounted) setState(() => _pdfFontAvailable = false);
    }
  }

  // Helpers available to all methods in this class
  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final items = (widget.invoice['items'] as List<dynamic>?) ?? [];

    // parsing performed using class helpers _parseDouble/_parseInt

    // Try load logo bytes if provided in invoice (asset path)
    Uint8List? logoBytes;
    try {
      final logoPath = widget.invoice['logo']?.toString();
      if (logoPath != null && logoPath.isNotEmpty) {
        final bd = await rootBundle.load(logoPath);
        logoBytes = bd.buffer.asUint8List();
      }
    } catch (_) {}

    // Load fonts (prefer local assets under assets/fonts/). If loading fails,
    // fall back to fetching Noto Sans from Google Fonts at runtime using
    // PdfGoogleFonts (requires network access). This ensures currency symbols
    // like '₹' render correctly in the generated PDF.
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      final regularData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      regularFont = pw.Font.ttf(regularData);
    } catch (_) {
      regularFont = null;
    }
    try {
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {
      boldFont = null;
    }

    // Prefer local asset fonts only (NotoSans-Regular/Bold under assets/fonts/).
    // If Bold isn't present, fall back to Regular for bold text.
    boldFont ??= regularFont;
    // mark availability for UI warnings
    _pdfFontAvailable = regularFont != null;

    final businessName =
        widget.invoice['businessName']?.toString() ?? 'My Shop';
    final createdAt =
        widget.invoice['createdAt']?.toString() ??
        DateTime.now().toIso8601String();
    final note = widget.invoice['note']?.toString() ?? '';

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 80, height: 80),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Invoice: ${widget.invoice['id'] ?? ''}',
                    style: pw.TextStyle(font: regularFont),
                  ),
                  pw.Text(
                    '₹${(widget.invoice['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                    style: pw.TextStyle(font: regularFont),
                  ),
                  pw.Text(
                    'Date: ${createdAt.split('T').first}',
                    style: pw.TextStyle(font: regularFont),
                  ),
                  if (note.isNotEmpty) pw.SizedBox(height: 6),
                  if (note.isNotEmpty)
                    pw.Text(
                      'Note: $note',
                      style: pw.TextStyle(font: regularFont),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Item', 'Qty', 'Price', 'Total'],
            data: List<List<String>>.generate(items.length, (i) {
              final it = items[i] as Map<String, dynamic>;
              final name = it['name']?.toString() ?? '';
              final price = _parseDouble(it['price'] ?? 0);
              // determine qty label and total depending on measure/unit
              String qtyLabel;
              double lineTotal;
              if (it.containsKey('measure') && (it['measure'] != null)) {
                final measure = _parseDouble(it['measure']);
                final unit = (it['unit'] ?? '').toString();
                if (unit == 'g') {
                  qtyLabel = '${measure.toStringAsFixed(0)} g';
                  lineTotal = price * (measure / 1000.0);
                } else if (unit == 'kg' || unit == 'L') {
                  qtyLabel = '${measure.toString()} $unit';
                  lineTotal = price * measure;
                } else {
                  // unknown unit, fallback to measure value
                  qtyLabel = '${measure.toString()} $unit';
                  lineTotal = price * measure;
                }
              } else {
                final qtyInt = _parseInt(it['qty'] ?? 1);
                qtyLabel = qtyInt.toString();
                lineTotal = price * qtyInt;
              }

              return [
                (i + 1).toString(),
                name,
                qtyLabel,
                '₹${price.toStringAsFixed(2)}',
                '₹${lineTotal.toStringAsFixed(2)}',
              ];
            }),
            headerStyle: pw.TextStyle(
              font: boldFont,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: pw.TextStyle(font: regularFont),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey600),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subtotal:',
                      style: pw.TextStyle(font: regularFont),
                    ),
                    pw.Text(
                      '₹${(widget.invoice['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                      style: pw.TextStyle(font: regularFont),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax:', style: pw.TextStyle(font: regularFont)),
                    pw.Text(
                      '₹${(widget.invoice['tax'] ?? 0.0).toStringAsFixed(2)}',
                      style: pw.TextStyle(font: regularFont),
                    ),
                    pw.Text(
                      '₹${(widget.invoice['total'] ?? 0.0).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₹${(widget.invoice['total'] ?? 0.0).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? fontWarningWidget = !_pdfFontAvailable
        ? Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Warning: PDF font not available - ₹ may not render correctly. Add assets/fonts/NotoSans-*.ttf or enable network for PdfGoogleFonts.',
              style: const TextStyle(color: Colors.red),
            ),
          )
        : null;
    final items = (widget.invoice['items'] as List<dynamic>?) ?? [];
    final subtotal = (widget.invoice['subtotal'] ?? 0.0);
    final tax = (widget.invoice['tax'] ?? 0.0);
    final total = (widget.invoice['total'] ?? 0.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fontWarningWidget != null) fontWarningWidget,
            Text(
              'Invoice ID: ${widget.invoice['id']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final it = items[i] as Map<String, dynamic>;
                  final name = it['name']?.toString() ?? '';
                  final price = _parseDouble(it['price'] ?? 0);
                  String subtitle;
                  String trailing;
                  if (it.containsKey('measure') && (it['measure'] != null)) {
                    final measure = _parseDouble(it['measure']);
                    final unit = (it['unit'] ?? '').toString();
                    if (unit == 'g') {
                      subtitle =
                          '₹${price.toStringAsFixed(2)} / kg x ${measure.toStringAsFixed(0)} g';
                      trailing =
                          '₹${(price * (measure / 1000.0)).toStringAsFixed(2)}';
                    } else {
                      subtitle =
                          '₹${price.toStringAsFixed(2)} / $unit x ${measure.toString()} $unit';
                      trailing = '₹${(price * measure).toStringAsFixed(2)}';
                    }
                  } else {
                    final qty = _parseInt(it['qty'] ?? 1);
                    subtitle = '₹${price.toStringAsFixed(2)} x $qty';
                    trailing = '₹${(price * qty).toStringAsFixed(2)}';
                  }

                  return ListTile(
                    title: Text(name),
                    subtitle: Text(subtitle),
                    trailing: Text(trailing),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('₹${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Tax'), Text('₹${tax.toStringAsFixed(2)}')],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            try {
                              // run the native print/layout
                              await Printing.layoutPdf(
                                onLayout: (format) => _generatePdf(format),
                              );

                              // after printing/layout completes, persist sale to backend
                              if (mounted) setState(() => _isLoading = true);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Saving sale...')),
                              );
                              try {
                                final id = await UserDataApi.createSale(
                                  widget.invoice,
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sale saved${id != null ? ': $id' : ''}',
                                    ),
                                  ),
                                );
                                if (mounted) navigator.pop(true);
                              } catch (se) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Saving sale failed: $se'),
                                  ),
                                );
                                // keep preview open so admin can retry saving/sharing
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Print failed: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                    child: _isLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Saving...',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : const Text('Print'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            setState(() => _isLoading = true);
                            try {
                              final bytes = await _generatePdf(
                                PdfPageFormat.a4,
                              );
                              _lastPdfBytes = bytes;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Saved'),
                                  duration: Duration(milliseconds: 1400),
                                ),
                              );
                              await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) {
                                    return AlertDialog(
                                      title: const Text('Invoice saved'),
                                      content: const Text(
                                        'The PDF was generated successfully.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () async {
                                            // close the dialog first
                                            navigator.pop();
                                            if (_lastPdfBytes != null) {
                                              try {
                                                await Printing.sharePdf(
                                                  bytes: _lastPdfBytes!,
                                                  filename:
                                                      'invoice_${widget.invoice['id'] ?? 'invoice'}.pdf',
                                                );
                                                // after sharing completes, close the preview and signal success
                                                navigator.pop(true);
                                              } catch (e) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Share failed: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Open'),
                                        ),
                                        TextButton(
                                          onPressed: () => navigator.pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
