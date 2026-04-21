import 'models.dart';

abstract class GmailSource {
  Future<List<MessageSummary>> search(String query, {int max = 50});
  Future<Message> read(String id);
}
