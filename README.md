# LoveHub 💕

App couple cho người yêu xa — theo dõi streak, nuôi pet, lưu kỷ niệm, trò chuyện cùng AI.

## Features

| Feature | Mô tả |
|---------|-------|
| **Auth** | Đăng nhập/đăng ký Firebase Email |
| **Couple** | Kết nối 2 người yêu qua couple code |
| **Streak** | Check-in hàng ngày, recovery tokens, streak history |
| **Pet** | Nuôi mèo virtual (HP, LP, level, missions) |
| **Memory** | Lưu kỷ niệm với ảnh, thể loại, ngày đặc biệt |
| **Mood** | Check-in mood hàng ngày, xem mood chart |
| **Saving Jar** | Tiết kiệm cho mục tiêu chung |
| **AI Chat** | Trò chuyện với Groq AI (context-aware, 20 câu/ngày) |
| **Notifications** | Push notification qua OneSignal |

## Tech Stack

- **Flutter** 3.x, **Dart** 3.x
- **Riverpod** 2.x — State management
- **go_router** — Navigation
- **Firebase** Auth + Firestore (Spark plan)
- **Groq AI** — AI Chat (OpenAI-compatible API)
- **Cloudinary** — Upload ảnh memory
- **OneSignal** — Push notification
- **WorkManager** — Background refresh (Android)

## Architecture

```
lib/
├── core/           # Constants, errors, theme, utils
├── features/       # Feature modules (auth, couple, streak, pet...)
├── services/       # Cloudinary, OneSignal, notifications
├── config/        # Routes, theme, router
└── main.dart
```

Mỗi feature tuân theo **Clean Architecture**:
```
domain/     → Entities, Repository interfaces, UseCases
data/       → Repository implementations, Data sources
presentation/ → Screens, Providers (Riverpod), Widgets
```

## Setup

### 1. Firebase
- Tạo project tại [Firebase Console](https://console.firebase.google.com)
- Download `google-services.json` → `android/app/`
- Enable **Authentication** (Email/Password)
- Create **Firestore Database**

### 2. API Keys
Tạo `lib/config/api_config.dart`:
```dart
class ApiConfig {
  static const String groqApiKey = 'YOUR_GROQ_API_KEY';
  static const String cloudinaryCloudName = 'df3jqgrvk';
  static const String cloudinaryUploadPreset = 'lovehub_unsigned';
  static const String oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID';
  static const String oneSignalRestKey = 'YOUR_ONESIGNAL_REST_KEY';
  static const String cloudflareWorkerUrl = 'YOUR_CLOUDFLARE_WORKER_URL';
}
```

### 3. Run
```bash
flutter pub get
flutter run
```

## Business Logic

### Streak
- Check-in deadline: 23:59 hàng ngày
- Max recovery tokens: 4 (earn thêm mỗi 15 ngày liên tiếp)
- At-risk warning: 21:00 nếu chưa check-in

### Pet
- Max HP: 100, Max Level: 10
- HP decay: -5 HP/ngày không check-in
- Feed: 20 LP → +30 HP
- Level up: level × 100 LP cần

### Love Points
- Check-in: +10 | Diary: +20 | Mood: +5
- Both positive mood bonus: +15
- 7-day streak bonus: +50

## License

MIT License
