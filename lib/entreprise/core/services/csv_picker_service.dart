import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PickedCsv {
  const PickedCsv(this.name, this.content);

  final String name;
  final String content;
}

/// Sélection d'un fichier CSV via le navigateur (Flutter Web uniquement).
class CsvPickerService {
  Future<PickedCsv?> pickCsv() {
    final completer = Completer<PickedCsv?>();

    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.csv,text/csv';

    input.addEventListener(
      'change',
      ((web.Event _) {
        final files = input.files;
        if (files == null || files.length == 0) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final file = files.item(0)!;
        file.text().toDart.then((text) {
          if (!completer.isCompleted) {
            completer.complete(PickedCsv(file.name, text.toDart));
          }
        }).catchError((Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        });
      }).toJS,
    );

    input.addEventListener(
      'cancel',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
    );

    input.click();
    return completer.future;
  }
}