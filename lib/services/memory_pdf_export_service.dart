import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../features/diary/domain/entities/memory.dart';

/// Builds a styled PDF containing all [memories] for [year],
/// then opens the system share/save sheet.
class MemoryPdfExportService {
  const MemoryPdfExportService._();

  /// Main entry point.
  /// [memories] should already be filtered for [year] and sorted oldest→newest.
  /// [userName] / [partnerName] are optional – used on the cover page.
  static Future<void> exportAndShare({
    required int year,
    required List<Memory> memories,
    String? userName,
    String? partnerName,
  }) async {
   try {
    debugPrint('[PDF EXPORT] Starting export for year=$year, ${memories.length} memories');
    // ── Load Unicode fonts ─────────────────────────────────────────────────
    debugPrint('[PDF EXPORT] Loading NotoSans fonts...');
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    debugPrint('[PDF EXPORT] NotoSans fonts loaded OK');

    // Try loading an emoji font; if it fails (too large / network issue),
    // we'll strip emojis from text instead of crashing.
    pw.Font? emojiFont;
    try {
      debugPrint('[PDF EXPORT] Loading NotoColorEmoji font...');
      emojiFont = await PdfGoogleFonts.notoColorEmoji();
      debugPrint('[PDF EXPORT] NotoColorEmoji loaded OK');
    } catch (e, st) {
      debugPrint('[PDF EXPORT] Emoji font failed to load (will strip emojis): $e');
      debugPrint('[PDF EXPORT] Emoji font stacktrace: $st');
    }

    final fontFallback = <pw.Font>[
      if (emojiFont != null) emojiFont,
    ];

    // Helper: sanitize text if emoji font is not available.
    String sanitize(String text) {
      if (emojiFont != null) return text;
      return _stripEmojis(text);
    }

    // Build a document-level theme so every widget inherits the Unicode font.
    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: bold, // no separate bold-italic variant; use bold
      fontFallback: fontFallback,
    );

    final pdf = pw.Document(
      title: 'LoveHub Memories $year',
      author: 'LoveHub',
      theme: theme,
    );

    // ── Pre-download all images ────────────────────────────────────────────
    final imageCache = <String, Uint8List>{};
    for (final memory in memories) {
      for (final url in memory.photoUrls) {
        if (url.isNotEmpty && !imageCache.containsKey(url)) {
          try {
            final response = await http.get(Uri.parse(url)).timeout(
                  const Duration(seconds: 10),
                );
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              imageCache[url] = response.bodyBytes;
            } else {
              debugPrint('[PDF EXPORT] Image download non-200: status=${response.statusCode} url=$url');
            }
          } catch (e, st) {
            debugPrint('[PDF EXPORT] Image download failed for url=$url: $e');
            debugPrint('[PDF EXPORT] Image download stacktrace: $st');
          }
        }
      }
    }

    // ── Build cover page ───────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  sanitize('💕'),
                  style: pw.TextStyle(
                    fontSize: 48,
                    fontFallback: fontFallback,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'LoveHub',
                  style: pw.TextStyle(
                    fontSize: 36,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#E91E8C'),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  sanitize('Memories $year'),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#C2185B'),
                  ),
                ),
                if (_coupleNames(userName, partnerName) != null) ...[
                  pw.SizedBox(height: 20),
                  pw.Text(
                    sanitize(_coupleNames(userName, partnerName)!),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                pw.SizedBox(height: 12),
                pw.Text(
                  '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // ── Build memory pages ─────────────────────────────────────────────────
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#C2185B'),
      fontFallback: fontFallback,
    );
    final dateStyle = pw.TextStyle(
      fontSize: 11,
      color: PdfColors.grey600,
      fontStyle: pw.FontStyle.italic,
      fontFallback: fontFallback,
    );
    final titleStyle = pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey800,
      fontFallback: fontFallback,
    );
    final bodyStyle = pw.TextStyle(
      fontSize: 12,
      color: PdfColors.grey700,
      lineSpacing: 4,
      fontFallback: fontFallback,
    );
    final categoryStyle = pw.TextStyle(
      fontSize: 10,
      color: PdfColors.grey500,
      fontStyle: pw.FontStyle.italic,
      fontFallback: fontFallback,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(sanitize('LoveHub — Memories $year'), style: headerStyle),
              pw.Text(
                'Page ${context.pageNumber}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                  fontFallback: fontFallback,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey400,
              fontFallback: fontFallback,
            ),
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (var i = 0; i < memories.length; i++) {
            final m = memories[i];

            // Separator between memories (not before the first one)
            if (i > 0) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(
                pw.Divider(color: PdfColor.fromHex('#E0D0E8'), thickness: 0.5),
              );
              widgets.add(pw.SizedBox(height: 8));
            }

            // Date
            widgets.add(pw.Text(sanitize(m.formattedDate), style: dateStyle));
            widgets.add(pw.SizedBox(height: 4));

            // Title + category
            widgets.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(child: pw.Text(sanitize(m.title), style: titleStyle)),
                  pw.Text(sanitize(m.category), style: categoryStyle),
                ],
              ),
            );

            // Mood
            if (m.mood != null && m.mood!.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 2));
              widgets.add(
                pw.Text(sanitize('Mood: ${m.mood}'), style: categoryStyle),
              );
            }

            widgets.add(pw.SizedBox(height: 6));

            // Story / content
            if (m.story != null && m.story!.isNotEmpty) {
              widgets.add(pw.Text(sanitize(m.story!), style: bodyStyle));
              widgets.add(pw.SizedBox(height: 8));
            }

            // Photos
            // A4 content width = 595.28 - 40*2 = 515.28
            const double contentWidth = 515.28;
            for (final url in m.photoUrls) {
              final imgBytes = imageCache[url];
              if (imgBytes == null || imgBytes.isEmpty) continue;
              try {
                final image = pw.MemoryImage(imgBytes);
                final imgW = image.width?.toDouble() ?? 0;
                final imgH = image.height?.toDouble() ?? 0;

                // Guard: skip if dimensions are invalid
                if (imgW <= 0 || imgH <= 0 || imgW.isNaN || imgH.isNaN || imgW.isInfinite || imgH.isInfinite) {
                  debugPrint('[PDF EXPORT] Skipping image with invalid dimensions (${imgW}x$imgH): $url');
                  widgets.add(pw.Text('[image unavailable]', style: categoryStyle));
                  widgets.add(pw.SizedBox(height: 4));
                  continue;
                }

                // Compute explicit finite height from aspect ratio
                final aspectRatio = imgW / imgH;
                if (aspectRatio <= 0 || aspectRatio.isNaN || aspectRatio.isInfinite) {
                  debugPrint('[PDF EXPORT] Skipping image with bad aspect ratio ($aspectRatio): $url');
                  widgets.add(pw.Text('[image unavailable]', style: categoryStyle));
                  widgets.add(pw.SizedBox(height: 4));
                  continue;
                }

                final displayWidth = contentWidth;
                double displayHeight = displayWidth / aspectRatio;

                // [BUG_7] Cap image height to prevent "Widget won't fit into
                // the page as its height (1145) exceed page height (761)".
                // A4 page is 841.89pt tall with 40pt margins → content ~761pt.
                // Reserve space for header/footer (~60pt) → safe cap ~700pt.
                const double maxImageHeight = 700.0;
                if (displayHeight > maxImageHeight) {
                  debugPrint('[PDF EXPORT] Capping image height from '
                      '${displayHeight.toStringAsFixed(1)}pt to '
                      '${maxImageHeight.toStringAsFixed(1)}pt (aspect=$aspectRatio)');
                  displayHeight = maxImageHeight;
                }

                // Use plain Image (no ClipRRect) to avoid NaN in drawRRect
                widgets.add(
                  pw.Image(
                    image,
                    width: displayWidth,
                    height: displayHeight,
                    fit: pw.BoxFit.contain,
                  ),
                );
                widgets.add(pw.SizedBox(height: 8));
              } catch (e, st) {
                debugPrint('[PDF EXPORT] Failed to embed image url=$url: $e');
                debugPrint('[PDF EXPORT] Image embed stacktrace: $st');
                // Skip this image, continue with next
              }
            }
          }

          return widgets;
        },
      ),
    );

    // ── Share / save ───────────────────────────────────────────────────────
    debugPrint('[PDF EXPORT] Saving PDF bytes...');
    final bytes = await pdf.save();
    debugPrint('[PDF EXPORT] PDF saved (${bytes.length} bytes). Opening share sheet...');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'LoveHub_Memories_$year.pdf',
    );
    debugPrint('[PDF EXPORT] Share sheet opened successfully');
   } catch (e, st) {
    debugPrint('[PDF EXPORT] *** TOP-LEVEL ERROR ***: $e');
    debugPrint('[PDF EXPORT] *** TOP-LEVEL STACKTRACE ***: $st');
    rethrow;
   }
  }

  /// Returns a formatted couple names string, or null if both are empty.
  static String? _coupleNames(String? a, String? b) {
    final hasA = a != null && a.isNotEmpty;
    final hasB = b != null && b.isNotEmpty;
    if (hasA && hasB) return '$a & $b';
    if (hasA) return a;
    if (hasB) return b;
    return null;
  }

  /// Removes emoji characters from [text] so the PDF renderer doesn't choke
  /// when the emoji font failed to load. Keeps all Latin, Vietnamese, CJK,
  /// punctuation, and standard Unicode text intact.
  static String _stripEmojis(String text) {
    // Matches most emoji ranges: emoticons, symbols, dingbats, skin tones,
    // variation selectors, ZWJ sequences, regional indicators, etc.
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]'  // Emoticons
      r'|[\u{1F300}-\u{1F5FF}]' // Misc Symbols & Pictographs
      r'|[\u{1F680}-\u{1F6FF}]' // Transport & Map
      r'|[\u{1F1E0}-\u{1F1FF}]' // Flags (regional indicators)
      r'|[\u{2600}-\u{26FF}]'   // Misc symbols (☀ ♻ etc.)
      r'|[\u{2700}-\u{27BF}]'   // Dingbats
      r'|[\u{FE00}-\u{FE0F}]'   // Variation Selectors
      r'|[\u{1F900}-\u{1F9FF}]' // Supplemental Symbols
      r'|[\u{1FA00}-\u{1FA6F}]' // Chess Symbols
      r'|[\u{1FA70}-\u{1FAFF}]' // Symbols Extended-A
      r'|[\u{200D}]'            // Zero Width Joiner
      r'|[\u{20E3}]'            // Combining Enclosing Keycap
      r'|[\u{FE0F}]'            // Variation Selector-16
      r'|[\u{E0020}-\u{E007F}]' // Tags
      r'|[\u{231A}-\u{231B}]'
      r'|[\u{23E9}-\u{23F3}]'
      r'|[\u{23F8}-\u{23FA}]'
      r'|[\u{25AA}-\u{25AB}]'
      r'|[\u{25B6}]'
      r'|[\u{25C0}]'
      r'|[\u{25FB}-\u{25FE}]'
      r'|[\u{2614}-\u{2615}]'
      r'|[\u{2648}-\u{2653}]'
      r'|[\u{267F}]'
      r'|[\u{2693}]'
      r'|[\u{26A1}]'
      r'|[\u{26AA}-\u{26AB}]'
      r'|[\u{26BD}-\u{26BE}]'
      r'|[\u{26C4}-\u{26C5}]'
      r'|[\u{26CE}]'
      r'|[\u{26D4}]'
      r'|[\u{26EA}]'
      r'|[\u{26F2}-\u{26F3}]'
      r'|[\u{26F5}]'
      r'|[\u{26FA}]'
      r'|[\u{26FD}]'
      r'|[\u{2702}]'
      r'|[\u{2705}]'
      r'|[\u{2708}-\u{270D}]'
      r'|[\u{270F}]'
      r'|[\u{2712}]'
      r'|[\u{2714}]'
      r'|[\u{2716}]'
      r'|[\u{271D}]'
      r'|[\u{2721}]'
      r'|[\u{2728}]'
      r'|[\u{2733}-\u{2734}]'
      r'|[\u{2744}]'
      r'|[\u{2747}]'
      r'|[\u{274C}]'
      r'|[\u{274E}]'
      r'|[\u{2753}-\u{2755}]'
      r'|[\u{2757}]'
      r'|[\u{2763}-\u{2764}]'
      r'|[\u{2795}-\u{2797}]'
      r'|[\u{27A1}]'
      r'|[\u{27B0}]'
      r'|[\u{2934}-\u{2935}]'
      r'|[\u{2B05}-\u{2B07}]'
      r'|[\u{2B1B}-\u{2B1C}]'
      r'|[\u{2B50}]'
      r'|[\u{2B55}]'
      r'|[\u{3030}]'
      r'|[\u{303D}]'
      r'|[\u{3297}]'
      r'|[\u{3299}]',
      unicode: true,
    );
    return text.replaceAll(emojiRegex, '').replaceAll(RegExp(r'  +'), ' ').trim();
  }
}
