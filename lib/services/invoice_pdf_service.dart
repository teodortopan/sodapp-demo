import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'platform_file_helper.dart';

/// Generates PDF invoices (Factura C) compliant with AFIP/ARCA requirements.
class InvoicePdfService {
  /// Generate a Factura C PDF and save it to the app's documents directory.
  /// Returns the file path of the generated PDF.
  static Future<String> generatePdf({
    // Emisor (seller) info
    required String razonSocial,
    required String cuit,
    required String domicilio,
    required String condicionIva, // e.g. "Monotributista"
    // Invoice info
    required int ptoVta,
    required int cbteNro,
    required String fecha, // YYYY-MM-DD
    required String cae,
    required String caeFchVto,
    required double importeTotal,
    // Receptor (buyer) info
    required String receptorNombre,
    required int receptorDocTipo,
    required String receptorDocNro,
    // Line items: [{nombre, cantidad, precioUnit, subtotal}]
    required List<Map<String, dynamic>> items,
    // QR URL
    required String qrUrl,
    // Comprobante type
    int cbteTipo = 11,
  }) async {
    final pdf = pw.Document();
    final fechaFormatted = _formatDate(fecha);
    final caeFchVtoFormatted = _formatDate(caeFchVto);
    final cbteLetra = _cbteLetra(cbteTipo);
    final cbteNombre = _cbteNombre(cbteTipo);
    final ptoVtaStr = ptoVta.toString().padLeft(4, '0');
    final cbteNroStr = cbteNro.toString().padLeft(8, '0');

    final docTipoStr = _docTipoNombre(receptorDocTipo);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          top: 100,
          left: 30,
          right: 30,
          bottom: 30,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(
                razonSocial: razonSocial,
                cbteLetra: cbteLetra,
                cbteNombre: cbteNombre,
                ptoVtaStr: ptoVtaStr,
                cbteNroStr: cbteNroStr,
                fechaFormatted: fechaFormatted,
                cuit: cuit,
              ),
              pw.SizedBox(height: 8),

              // Emisor info
              _buildEmisorInfo(
                domicilio: domicilio,
                condicionIva: condicionIva,
              ),
              pw.SizedBox(height: 8),

              // Receptor info
              _buildReceptorInfo(
                nombre: receptorNombre,
                docTipo: docTipoStr,
                docNro: receptorDocNro,
              ),
              pw.SizedBox(height: 12),

              // Items table
              _buildItemsTable(items),
              pw.SizedBox(height: 12),

              // Total
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text(
                    'TOTAL: \$ ${importeTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.Spacer(),

              // CAE info + QR
              _buildFooter(
                cae: cae,
                caeFchVto: caeFchVtoFormatted,
                qrUrl: qrUrl,
              ),
            ],
          );
        },
      ),
    );

    // Save PDF via platform helper (filesystem on native, in-memory on web)
    final fileName = 'factura_${cbteLetra}_${ptoVtaStr}_$cbteNroStr.pdf';
    final pdfBytes = await pdf.save();
    final filePath = await PlatformFileHelper.instance.savePdf(
      fileName,
      pdfBytes,
    );

    return filePath;
  }

  static pw.Widget _buildHeader({
    required String razonSocial,
    required String cbteLetra,
    required String cbteNombre,
    required String ptoVtaStr,
    required String cbteNroStr,
    required String fechaFormatted,
    required String cuit,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: business name
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    razonSocial,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Center: letter
          pw.Container(
            width: 50,
            height: 50,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
            alignment: pw.Alignment.center,
            child: pw.Text(
              cbteLetra,
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
          ),
          // Right: invoice number & date
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    cbteNombre,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Punto de Venta: $ptoVtaStr  Comp. Nro: $cbteNroStr',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Fecha de Emisión: $fechaFormatted',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'CUIT: $cuit',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmisorInfo({
    required String domicilio,
    required String condicionIva,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Domicilio Comercial: $domicilio',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Condición frente al IVA: $condicionIva',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceptorInfo({
    required String nombre,
    required String docTipo,
    required String docNro,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Receptor: $nombre', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text('$docTipo: $docNro', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text(
            'Condición frente al IVA: Consumidor Final',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableCell('Descripción', bold: true),
            _tableCell('Cantidad', bold: true, align: pw.Alignment.center),
            _tableCell(
              'Precio Unit.',
              bold: true,
              align: pw.Alignment.centerRight,
            ),
            _tableCell('Subtotal', bold: true, align: pw.Alignment.centerRight),
          ],
        ),
        // Items
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _tableCell(item['nombre']?.toString() ?? ''),
              _tableCell(
                item['cantidad']?.toString() ?? '0',
                align: pw.Alignment.center,
              ),
              _tableCell(
                '\$ ${(item['precioUnit'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                align: pw.Alignment.centerRight,
              ),
              _tableCell(
                '\$ ${(item['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                align: pw.Alignment.centerRight,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter({
    required String cae,
    required String caeFchVto,
    required String qrUrl,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // QR code
          pw.BarcodeWidget(
            data: qrUrl,
            barcode: pw.Barcode.qrCode(),
            width: 80,
            height: 80,
          ),
          // CAE info
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'CAE: $cae',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Fecha Vto. CAE: $caeFchVto',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format YYYY-MM-DD to DD/MM/YYYY for display.
  static String _formatDate(String isoDate) {
    if (isoDate.length != 10) return isoDate;
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  static String _cbteLetra(int cbteTipo) {
    switch (cbteTipo) {
      case 11:
      case 12:
      case 13:
        return 'C';
      case 1:
      case 2:
      case 3:
        return 'A';
      case 6:
      case 7:
      case 8:
        return 'B';
      default:
        return 'C';
    }
  }

  static String _cbteNombre(int cbteTipo) {
    switch (cbteTipo) {
      case 1:
      case 6:
      case 11:
        return 'FACTURA';
      case 2:
      case 7:
      case 12:
        return 'NOTA DE DÉBITO';
      case 3:
      case 8:
      case 13:
        return 'NOTA DE CRÉDITO';
      default:
        return 'COMPROBANTE';
    }
  }

  static String _docTipoNombre(int docTipo) {
    switch (docTipo) {
      case 80:
        return 'CUIT';
      case 86:
        return 'CUIL';
      case 96:
        return 'DNI';
      case 99:
        return 'Consumidor Final';
      default:
        return 'Doc. Tipo $docTipo';
    }
  }
}
