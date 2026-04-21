class MessageSummary {
  const MessageSummary({
    required this.id,
    required this.from,
    required this.subject,
    required this.date,
    this.labels = const [],
  });

  final String id;
  final String from;
  final String subject;
  final String date;
  final List<String> labels;

  factory MessageSummary.fromJson(Map<String, dynamic> json) => MessageSummary(
        id: json['id'] as String? ?? '',
        from: json['from'] as String? ?? '(unknown)',
        subject: json['subject'] as String? ?? '(no subject)',
        date: json['date'] as String? ?? '',
        labels: (json['labels'] as List?)?.cast<String>() ?? const [],
      );
}

class EmailAddress {
  const EmailAddress({this.name, required this.email});
  final String? name;
  final String email;

  factory EmailAddress.fromJson(Map<String, dynamic> json) => EmailAddress(
        name: json['name'] as String?,
        email: json['email'] as String? ?? '',
      );

  String get display {
    if (name != null && name!.isNotEmpty) return '$name <$email>';
    return email;
  }
}

class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    required this.cc,
    required this.subject,
    required this.date,
    required this.bodyText,
  });

  final String id;
  final String threadId;
  final EmailAddress from;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final String subject;
  final String date;
  final String bodyText;

  factory Message.fromJson(Map<String, dynamic> json) {
    List<EmailAddress> parseList(dynamic v) {
      if (v is! List) return const [];
      return v
          .whereType<Map<String, dynamic>>()
          .map(EmailAddress.fromJson)
          .toList();
    }

    return Message(
      id: json['message_id'] as String? ?? '',
      threadId: json['thread_id'] as String? ?? '',
      from: json['from'] is Map<String, dynamic>
          ? EmailAddress.fromJson(json['from'] as Map<String, dynamic>)
          : const EmailAddress(email: ''),
      to: parseList(json['to']),
      cc: parseList(json['cc']),
      subject: json['subject'] as String? ?? '(no subject)',
      date: json['date'] as String? ?? '',
      bodyText: json['body_text'] as String? ?? '',
    );
  }
}
