import 'package:dart_tui/dart_tui.dart';

import '../gmail/models.dart';

class MessagesLoaded extends Msg {
  MessagesLoaded(this.query, this.messages, {this.targetPage});
  final String query;
  final List<MessageSummary> messages;
  final int? targetPage;
}

class MessageBodyLoaded extends Msg {
  MessageBodyLoaded(this.requestedId, this.message);
  final String requestedId;
  final Message message;
}

class LoadFailed extends Msg {
  LoadFailed(this.error, {this.duringBody = false, this.requestedId});
  final String error;
  final bool duringBody;
  final String? requestedId;
}
