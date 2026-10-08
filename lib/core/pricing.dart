import '../models/appointment.dart';
import '../models/club_card.dart';

/// Правила стоимости работ — те же, что в серверном хуке
/// (pocketbase/pb_hooks/autoservice_lib.js). Здесь они нужны, чтобы
/// показать расчёт в форме до отправки; окончательную сумму считает сервер.
class Pricing {
  const Pricing._();

  /// Скидка не больше этого процента, как бы ни складывались условия.
  static const maxDiscount = 15;

  /// Скидка клиента на дату записи: большая из персональной и скидки
  /// по клубной карте, если карта действует в этот день; не больше 15 %.
  static ({int percent, DiscountSource source}) discount({
    required int personal,
    ClubCard? card,
    required DateTime date,
  }) {
    final byCard = card != null && card.isValidAt(date)
        ? card.level.discount
        : 0;
    final percent = [personal, byCard].reduce((a, b) => a > b ? a : b);
    final capped = percent > maxDiscount ? maxDiscount : percent;
    final source = capped == 0
        ? DiscountSource.none
        : byCard >= personal
        ? DiscountSource.card
        : DiscountSource.personal;
    return (percent: capped, source: source);
  }

  /// К оплате: сумма минус скидка, с округлением до рубля.
  static int total(int subtotal, int percent) =>
      (subtotal * (100 - percent) / 100).round();
}
