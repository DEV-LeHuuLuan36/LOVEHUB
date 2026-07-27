abstract final class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String couple(String coupleId) => 'couples/$coupleId';
  static String streak(String coupleId) => 'streaks/$coupleId';
  static String pet(String coupleId) => 'pets/$coupleId';
  static String diaries(String coupleId) => 'diaries/$coupleId';
  static String moods(String coupleId) => 'moods/$coupleId';
  static String savingJars(String coupleId) => 'savingJars/$coupleId';
  static String aiChat(String coupleId) => 'aiChats/$coupleId';
  static String aiConversations(String coupleId) =>
      'aiChats/$coupleId/conversations';
  static String aiConversation(String coupleId, String conversationId) =>
      'aiChats/$coupleId/conversations/$conversationId';
  static String aiConversationMessages(
    String coupleId,
    String conversationId,
  ) =>
      'aiChats/$coupleId/conversations/$conversationId/messages';
}
