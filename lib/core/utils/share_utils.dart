import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Retorna o Rect do botão na tela (para ancorar o share sheet no iOS).
Rect _buttonRect(BuildContext btnCtx) {
  final box = btnCtx.findRenderObject() as RenderBox?;
  if (box == null) return const Rect.fromLTWH(0, 40, 44, 44);
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Compartilha texto + imagem (baixa para temp se necessário).
/// [btnCtx] deve ser o BuildContext do próprio botão (use Builder).
Future<void> shareWithImage({
  required BuildContext btnCtx,
  required String text,
  required String imageUrl,
  required String filename,
}) async {
  final origin = _buttonRect(btnCtx);
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
Future<void> shareText(BuildContext btnCtx, String text) async {
  await Share.share(text, sharePositionOrigin: _buttonRect(btnCtx));
}
