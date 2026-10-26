import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../models.dart';
import '../store.dart';
import '../utils.dart';

class ReportExportScreen extends StatefulWidget {
  const ReportExportScreen({super.key, required this.year});
  final int year;

  @override
  State<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends State<ReportExportScreen> {
  final AppStore store = AppStore.instance;
  final GlobalKey _reportKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final context = _reportKey.currentContext;
    if (context == null) return null;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _capture();
      if (png == null) throw Exception('报表尚未准备好');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/星空记账-年度报表-${widget.year}.png');
      await file.writeAsBytes(png, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], subject: '星空记账年度报表');
    } catch (e) {
      if (mounted) _toast('导出图片失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _capture();
      if (png == null) throw Exception('报表尚未准备好');
      final image = pw.MemoryImage(png);
      final decoded = await decodeImageFromList(png);
      final width = 595.0;
      final ratio = decoded.height / decoded.width;
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, width * ratio),
          margin: const pw.EdgeInsets.all(0),
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/星空记账-年度报表-${widget.year}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], subject: '星空记账年度报表');
    } catch (e) {
      if (mounted) _toast('导出 PDF 失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final months = store.monthlyTotalsForYear(widget.year);
        final counts = store.monthlyCountsForYear(widget.year);
        final total = store.totalsForYear(widget.year);
        final cats = store.categoryTotalsForYear(widget.year, TxnType.expense);
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.year}年报表'),
            actions: [
              IconButton(
                onPressed: _busy ? null : _shareImage,
                tooltip: '导出图片',
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton(
                onPressed: _busy ? null : _sharePdf,
                tooltip: '导出 PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 30),
            children: [
              RepaintBoundary(
                key: _reportKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2355),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('✦', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 18)),
                          ),
                          const SizedBox(width: 9),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('星空记账', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                              Text('年度报表', style: TextStyle(fontSize: 10, color: Colors.black45)),
                            ],
                          ),
                          const Spacer(),
                          Text('${widget.year}年', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _sum('支出', formatMoney(total.expense)),
                            _sum('收入', formatMoney(total.income)),
                            _sum('结余', formatMoney(total.balance)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('月度明细', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(flex: 12, child: _head('月份')),
                          Expanded(flex: 18, child: _head('收入', TextAlign.right)),
                          Expanded(flex: 18, child: _head('支出', TextAlign.right)),
                          Expanded(flex: 18, child: _head('结余', TextAlign.right)),
                          Expanded(flex: 9, child: _head('笔数', TextAlign.right)),
                        ],
                      ),
                      const Divider(height: 1),
                      ...List.generate(12, (i) {
                        final m = months[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 12, child: Text('${i + 1}月', style: const TextStyle(fontSize: 10, color: Colors.black87))),
                              Expanded(flex: 18, child: Text(formatMoney(m.income, symbol: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5, color: Colors.black87))),
                              Expanded(flex: 18, child: Text(formatMoney(m.expense, symbol: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5, color: Colors.black87))),
                              Expanded(flex: 18, child: Text(formatMoney(m.balance, symbol: false), textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: m.balance < 0 ? Colors.red : Colors.black87))),
                              Expanded(flex: 9, child: Text('${counts[i]}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9.5, color: Colors.black45))),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      const Text('支出排行', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 5),
                      ...List.generate(cats.length > 8 ? 8 : cats.length, (i) {
                        final c = cats[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(width: 18, child: Text('${i + 1}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: i < 3 ? const Color(0xFFC08A2E) : Colors.black38))),
                              Text(c.category.icon, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(c.category.name, style: const TextStyle(fontSize: 10.5, color: Colors.black87))),
                              Text(formatMoney(c.value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Text('生成时间：${fullDateTitle(dateKey(DateTime.now()))}',
                          style: const TextStyle(fontSize: 8.5, color: Colors.black38)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _shareImage,
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: const Text('导出图片'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _sharePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                      label: const Text('导出 PDF'),
                    ),
                  ),
                ],
              ),
              if (_busy) const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sum(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _head(String text, [TextAlign align = TextAlign.left]) {
    return Text(text, textAlign: align, style: const TextStyle(fontSize: 8.5, color: Colors.black45));
  }
}
