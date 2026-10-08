import 'package:flutter/foundation.dart';

/// Сигнал «данные на сервере изменились».
///
/// Репозитории подают его после каждой успешной записи. Списки помечаются
/// устаревшими, открытая карточка перечитывается, справочники для форм
/// обновляются.
class DataChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}
