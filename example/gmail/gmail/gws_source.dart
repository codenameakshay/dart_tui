import '../gws/runner.dart';
import 'models.dart';
import 'source.dart';

class GwsGmailSource implements GmailSource {
  const GwsGmailSource();

  @override
  Future<List<MessageSummary>> search(String query, {int max = 50}) async {
    final out = await runGws([
      'gmail',
      '+triage',
      '--query',
      query,
      '--max',
      '$max',
      '--format',
      'json',
      '--labels',
    ]);
    final data = decodeJsonObject(out);
    final messages = (data['messages'] as List?) ?? const [];
    return messages
        .whereType<Map<String, dynamic>>()
        .map(MessageSummary.fromJson)
        .toList();
  }

  @override
  Future<Message> read(String id) async {
    final out = await runGws([
      'gmail',
      '+read',
      '--id',
      id,
      '--headers',
      '--format',
      'json',
    ]);
    return Message.fromJson(decodeJsonObject(out));
  }
}
