/// Одна страница выборки и сведения обо всей выборке.
///
/// Структура совпадает с оболочкой ответа сервера: когда источник данных
/// сменится на API, экраны останутся прежними.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;

  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  int get totalPages => total == 0 ? 1 : (total / size).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  /// Номер первой и последней записи на странице — для подписи «11–20 из 34».
  int get firstIndex => total == 0 ? 0 : (page - 1) * size + 1;
  int get lastIndex => (page - 1) * size + items.length;

  /// Конструктор не const: пустой константный список с параметром типа `T`
  /// в Dart запрещён.
  PageResult.empty() : items = <T>[], page = 1, size = 10, total = 0;
}
