class GmailTab {
  const GmailTab(
      {required this.label, required this.query, required this.hotkey});
  final String label;
  final String query;
  final String hotkey;
}

const List<GmailTab> kTabs = [
  GmailTab(label: 'Inbox', query: 'in:inbox', hotkey: '1'),
  GmailTab(label: 'Unread', query: 'is:unread in:inbox', hotkey: '2'),
  GmailTab(label: 'Starred', query: 'is:starred', hotkey: '3'),
  GmailTab(label: 'Important', query: 'is:important', hotkey: '4'),
  GmailTab(label: 'Sent', query: 'in:sent', hotkey: '5'),
];

int tabIndexForQuery(String q) {
  for (var i = 0; i < kTabs.length; i++) {
    if (kTabs[i].query == q) return i;
  }
  return -1;
}
