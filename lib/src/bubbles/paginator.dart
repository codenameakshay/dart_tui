import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

final class PaginatorModel extends TeaModel {
  PaginatorModel({
    required this.page,
    required this.totalPages,
    this.labelBuilder,
  }) : assert(totalPages > 0, 'totalPages must be > 0');

  final int page;
  final int totalPages;
  final String Function(int page, int totalPages)? labelBuilder;

  int get safePage => page.clamp(0, totalPages - 1);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'left':
      case 'h':
      case 'pgup':
        return (
          PaginatorModel(
            page: safePage > 0 ? safePage - 1 : 0,
            totalPages: totalPages,
            labelBuilder: labelBuilder,
          ),
          null,
        );
      case 'right':
      case 'l':
      case 'pgdown':
        return (
          PaginatorModel(
            page: safePage < totalPages - 1 ? safePage + 1 : totalPages - 1,
            totalPages: totalPages,
            labelBuilder: labelBuilder,
          ),
          null,
        );
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    final p = safePage;
    final label =
        labelBuilder?.call(p, totalPages) ?? 'Page ${p + 1}/$totalPages';
    return newView(label);
  }
}
