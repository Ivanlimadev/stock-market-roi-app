import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilha texto + imagem (baixa para temp se necessário).
/// Se o download falhar, cai para share só com texto.
Future<void> shareWithImage({
  required BuildContext context,
  required String text,
  required String imageUrl,
  required String filename,
}) async {
  final size   = MediaQuery.sizeOf(context);
  final origin = Rect.fromLTWH(0, 0, size.width, size.height);

  try {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');

    if (!file.existsSync()) {
      await Dio().download(imageUrl, file.path);
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    await Share.share(text, sharePositionOrigin: origin);
  }
}

/// Share simples sem imagem.
Future<void> shareText(BuildContext context, String text) async {
  final size = MediaQuery.sizeOf(context);
  await Share.share(
    text,
    sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height),
  );
}
