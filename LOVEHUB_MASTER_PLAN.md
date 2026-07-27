# 💕 LoveHub — Master Project Plan

> **Version:** 2.0 | **Last Updated:** 2026-06-09  
> **Stack:** Flutter 3.x · Firebase · Gemini AI · MoMo API · Android Native (Kotlin)  
> **Workflow:** Cursor IDE → Android Studio (test) → APK deploy

---

## 📋 MỤC LỤC

1. [Tổng quan dự án](#1-tổng-quan-dự-án)
2. [Tính năng chi tiết](#2-tính-năng-chi-tiết)
3. [Tech Stack & Dependencies](#3-tech-stack--dependencies)
4. [Kiến trúc & Cấu trúc thư mục](#4-kiến-trúc--cấu-trúc-thư-mục)
5. [Setup môi trường Cursor IDE](#5-setup-môi-trường-cursor-ide)
6. [Cursor Rules & AI Config](#6-cursor-rules--ai-config)
7. [UI Design Workflow — Google Stitch + MCP](#7-ui-design-workflow--google-stitch--mcp)
8. [Roadmap triển khai theo Phase](#8-roadmap-triển-khai-theo-phase)
9. [Firebase Security Rules](#9-firebase-security-rules)
10. [Testing Strategy](#10-testing-strategy)
11. [Mẫu viết CV](#11-mẫu-viết-cv)

---



## 1. TỔNG QUAN DỰ ÁN

**LoveHub** là ứng dụng Android kết nối real-time cho các cặp đôi, tích hợp AI trợ lý, gamification nuôi thú cưng, quản lý tài chính chung qua MoMo, và hệ thống streak/checkin hàng ngày.

### Đối tượng người dùng

- Cặp đôi yêu nhau (2 người, 2 thiết bị Android)
- Độ tuổi 18-30, quen dùng smartphone



### Luồng kết nối 2 máy

```
User A đăng ký → nhận mã LOVE-XXXX → gửi cho User B
User B nhập mã → Firestore link 2 tài khoản
→ Mọi dữ liệu sync real-time qua Firestore snapshots()
→ Trạng thái Online/Offline qua Firebase RTDB Presence
```

---



## 2. TÍNH NĂNG CHI TIẾT



### 🔴 Nhóm 1 — Core Connection


| Tính năng            | Mô tả kỹ thuật                                          | Priority |
| -------------------- | ------------------------------------------------------- | -------- |
| Ghép đôi bằng mã     | Firestore write/read mã LOVE-XXXX                       | P0       |
| Online Presence      | Firebase RTDB `onDisconnect()` + `onValue()`            | P0       |
| "Đang nhìn màn hình" | RTDB presence + timestamp so sánh                       | P1       |
| Offline Persistence  | `FirebaseFirestore.instance.settings` enablePersistence | P0       |


---



### 🟠 Nhóm 2 — Bộ đếm thời gian & Cột mốc


| Tính năng             | Mô tả kỹ thuật                                                    | Priority |
| --------------------- | ----------------------------------------------------------------- | -------- |
| Đồng hồ đếm giây      | `Stream.periodic` + `ValueNotifier`, tối ưu battery               | P0       |
| Milestone tự động     | Tính toán: 100 ngày, 200 ngày, 1 năm, Valentine (14/2), sinh nhật | P0       |
| Nhắc nhở trước 3 ngày | `WorkManager` schedule notification khi app tắt                   | P1       |
| Milestone custom      | User tự thêm: "Lần đầu gặp", "Lần đầu hôn"...                     | P2       |


---



### 🟡 Nhóm 3 — Android Showcase (CV "Ăn Tiền")


| Tính năng               | Mô tả kỹ thuật                                          | Priority |
| ----------------------- | ------------------------------------------------------- | -------- |
| Home Screen Widget 2x2  | `home_widget` package + Kotlin `AppWidgetProvider`      | P0       |
| Home Screen Widget 4x2  | Ảnh cặp đôi + số ngày + countdown                       | P1       |
| Persistent Notification | `FlutterForegroundTask` hoặc native `ForegroundService` | P0       |
| Widget cập nhật         | `WorkManager` 15 phút/lần với battery constraint        | P0       |


---



### 🟢 Nhóm 4 — Memory & Love Map


| Tính năng        | Mô tả kỹ thuật                                               | Priority |
| ---------------- | ------------------------------------------------------------ | -------- |
| Nhật ký chung    | Firestore collection `diaries/`, real-time sync              | P0       |
| Đính kèm ảnh     | `image_picker` + `flutter_image_compress` + Firebase Storage | P1       |
| Love Map         | Google Maps API + custom heart marker icon                   | P1       |
| Timeline kỷ niệm | Scroll dọc theo năm, lazy load                               | P2       |


---



### 🔵 Nhóm 5 — Streak & Checkin (TikTok-style)



#### Logic Streak hoàn chỉnh:

```
Trạng thái streak:
- ACTIVE: cả 2 checkin trong 24h
- AT_RISK: chỉ 1 người checkin (còn 6h)
- BROKEN: cả 2 không checkin → streak = 0

Recovery Token:
- Mỗi tuần duy trì streak đủ 7 ngày → +1 Recovery Token
- Tối đa tích lũy: 4 tokens
- Dùng 1 token → khôi phục streak bị gãy trong vòng 48h
- Token KHÔNG stack quá 4 (dùng hết mới tích tiếp)
- Hiển thị: "🛡️ 3/4 tokens"
```


| Tính năng                  | Mô tả kỹ thuật                                   |
| -------------------------- | ------------------------------------------------ |
| Checkin hàng ngày          | Firestore `checkins/{coupleId}/{date}/{userId}`  |
| Streak counter             | Cloud Function trigger khi cả 2 checkin          |
| Recovery Token logic       | Cloud Function chạy mỗi cuối tuần (Sunday 23:59) |
| FCM nhắc checkin           | Cloud Scheduler 21h mỗi tối nếu chưa checkin     |
| Animation streak vỡ        | Rive/Lottie "trái tim vỡ" + haptic feedback      |
| Animation streak milestone | Lottie confetti khi đạt 7, 30, 100 ngày streak   |


---



### 💜 Nhóm 6 — Gamification (Nuôi thú cưng ảo)



#### Hệ thống điểm Love Points:

```
Nguồn kiếm điểm:
- Checkin hàng ngày: +10 LP mỗi người
- Thêm kỷ niệm vào nhật ký: +20 LP
- Gửi mood: +5 LP
- Mood cả 2 cùng positive: +15 LP bonus
- Duy trì streak 7 ngày: +50 LP bonus
- Hoàn thành nhiệm vụ tuần: +30 LP

Thú cưng (3 loại: 🐱 Mèo / 🐻 Gấu / 🐶 Chó):
- Level 1 → 10: mỗi level cần LP theo công thức: level * 100 LP
- HP (0-100): giảm 5 HP/ngày nếu không checkin
- HP = 0 → thú cưng "buồn" (animation sad)
- Cho ăn: dùng 20 LP → +30 HP
- Unlock skin: đạt 100 ngày yêu nhau, 1 năm, v.v.
```


| Tính năng            | Mô tả kỹ thuật                                       |
| -------------------- | ---------------------------------------------------- |
| Thú cưng animation   | Rive state machine: idle/happy/sad/levelup           |
| Firestore game state | Transaction để tránh race condition khi 2 máy update |
| Nhiệm vụ tuần        | Cloud Function reset nhiệm vụ mỗi thứ 2 00:00        |
| Unlock skin          | Firestore `pets/{coupleId}/unlockedSkins`            |


---



### 🟡 Nhóm 7 — Mood Sync


| Tính năng               | Mô tả kỹ thuật                            |
| ----------------------- | ----------------------------------------- |
| Mood hàng ngày          | 5 emoji: 😊😐😔😡🥰, lưu Firestore        |
| Cloud Scheduler nhắc    | Cloud Functions + FCM lúc 21h mỗi tối     |
| Hiện mood partner       | Real-time listener trên màn hình home     |
| Lịch sử mood            | Chart 7 ngày gần nhất (fl_chart)          |
| Mood bonus cho thú cưng | Cloud Function kiểm tra 2 người cùng mood |


---



### 🟠 Nhóm 8 — Tài chính & MoMo



#### Heo đất chung (Saving Jar):

```
Cấu trúc Firestore:
savingJars/{coupleId}/jars/{jarId}:
  - name: "Du lịch Đà Lạt"
  - targetAmount: 5000000
  - currentAmount: 1500000
  - contributions: [{userId, amount, timestamp, note}]
  - momoLinked: boolean

transactions/{coupleId}/history/{txId}:
  - type: "deposit" | "withdraw"
  - amount: number
  - userId: string
  - source: "manual" | "momo"
  - timestamp: Timestamp
```


| Tính năng            | Mô tả kỹ thuật                                           |
| -------------------- | -------------------------------------------------------- |
| Tạo heo đất          | Firestore create + set target                            |
| Đóng tiền thủ công   | Firestore transaction atomic update                      |
| Đóng tiền qua MoMo   | MoMo Open API → deeplink → callback deeplink về app      |
| Rút tiền             | Log withdrawal, cập nhật balance                         |
| Chia đôi chi tiêu    | Tính toán: ai đang nợ ai, tổng đã đóng từng người        |
| Biểu đồ chi tiêu     | fl_chart, phân loại: ăn uống / đi chơi / quà tặng / khác |
| Progress bar heo đất | Animated progress, confetti khi đạt 100%                 |




#### MoMo Integration Flow:

```
App → MoMo SDK deeplink (orderId, amount, description)
→ User xác nhận trong MoMo app
→ MoMo redirect về app via deeplink scheme: lovehub://payment/callback
→ App kiểm tra IPN signature
→ Cập nhật Firestore transaction
```

---



### 🤖 Nhóm 9 — AI Features



#### AI Date Planner:

```
Prompt Template gửi Gemini:
"Bạn là trợ lý hẹn hò cho cặp đôi tại [thành phố].
Context: Họ đã yêu nhau [X] ngày, thường đến [địa điểm A, B].
Sở thích: [danh sách từ history].
Budget: [amount] VND. Thời gian: tối nay từ [giờ].
Hãy lên lịch trình chi tiết theo format:
⏰ [giờ] — [địa điểm] — [mô tả ngắn] — [giá ước tính]"

Streaming: Gemini stream → Flutter StreamBuilder → typewriter effect
Fallback: Nếu API error → hiện 3 gợi ý offline từ local JSON
```



#### AI Relationship Coach:

```
Context inject tự động:
- Ngày kỷ niệm sắp đến (trong 7 ngày)
- Mood 7 ngày gần nhất của 2 người
- Streak hiện tại
- Địa điểm hay đến (từ Love Map)

Use cases:
- "Gợi ý quà sinh nhật cho [partner name] budget 500k"
- "Cả 2 tui mood xấu 3 ngày liên tiếp, làm gì để vui hơn?"
- "Ngày mai kỷ niệm 100 ngày, tui nên làm gì?"
```

---



## 3. TECH STACK & DEPENDENCIES



### pubspec.yaml (đầy đủ)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management & Architecture
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^13.2.0

  # Firebase
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.3
  cloud_firestore: ^5.2.1
  firebase_storage: ^12.1.2
  firebase_database: ^11.1.0  # RTDB cho Presence
  firebase_messaging: ^15.1.0
  cloud_functions: ^5.0.4

  # AI
  google_generative_ai: ^0.4.3

  # Android Native Integration
  home_widget: ^0.6.0
  flutter_foreground_task: ^8.8.0
  workmanager: ^0.5.2

  # Maps & Location
  google_maps_flutter: ^2.7.0
  geolocator: ^12.0.0

  # Media
  image_picker: ^1.1.2
  flutter_image_compress: ^2.3.0
  cached_network_image: ^3.4.1

  # Animation ⭐ KEY PACKAGES
  rive: ^0.13.6               # Thú cưng interactive animation
  lottie: ^3.1.2              # Confetti, streak break, loading
  flutter_animate: ^4.5.0     # Micro-animations toàn app
  shimmer: ^3.0.0             # Loading skeleton

  # Charts & UI
  fl_chart: ^0.68.0
  flutter_svg: ^2.0.10+1

  # Payment
  momo_payment: ^1.0.0        # hoặc url_launcher cho deeplink

  # Utils
  intl: ^0.19.0
  shared_preferences: ^2.3.1
  connectivity_plus: ^6.0.3
  package_info_plus: ^8.1.0
  uuid: ^4.4.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_riverpod_lint: ^2.3.10
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11
  mockito: ^5.4.4
  flutter_lints: ^4.0.0
```

---



## 4. KIẾN TRÚC & CẤU TRÚC THƯ MỤC



### Clean Architecture — 3 Layers

```
Presentation Layer  →  Domain Layer  →  Data Layer
(UI/Widgets/Providers)  (UseCases/Entities)  (Repositories/Firebase)
```



### Cấu trúc thư mục đầy đủ

```
lovehub/
├── android/
│   └── app/src/main/kotlin/com/lovehub/
│       ├── MainActivity.kt
│       ├── LoveWidgetProvider.kt      ← Home Screen Widget
│       └── LoveForegroundService.kt  ← Persistent Notification
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── firestore_paths.dart
│   │   ├── errors/
│   │   │   ├── failures.dart
│   │   │   └── exceptions.dart
│   │   ├── router/
│   │   │   └── app_router.dart        ← go_router
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   └── app_typography.dart
│   │   └── utils/
│   │       ├── date_utils.dart
│   │       └── validators.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── providers/auth_provider.dart
│   │   ├── couple/
│   │   │   ├── data/
│   │   │   │   ├── couple_repository_impl.dart
│   │   │   │   └── presence_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/couple_entity.dart
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── home_screen.dart
│   │   │       ├── linking_screen.dart
│   │   │       └── providers/
│   │   ├── milestone/
│   │   ├── diary/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── diary_screen.dart
│   │   │       ├── love_map_screen.dart
│   │   │       └── add_memory_screen.dart
│   │   ├── streak/
│   │   │   ├── data/
│   │   │   │   └── streak_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/streak_entity.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── checkin_usecase.dart
│   │   │   │       └── use_recovery_token_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── streak_screen.dart
│   │   │       └── providers/streak_provider.dart
│   │   ├── gamification/
│   │   │   ├── data/
│   │   │   │   └── pet_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── entities/pet_entity.dart
│   │   │   └── presentation/
│   │   │       ├── pet_screen.dart
│   │   │       └── providers/pet_provider.dart
│   │   ├── mood/
│   │   ├── finance/
│   │   │   ├── data/
│   │   │   │   ├── saving_jar_repository_impl.dart
│   │   │   │   └── momo_repository_impl.dart
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── finance_screen.dart
│   │   │       ├── saving_jar_screen.dart
│   │   │       └── providers/
│   │   └── ai/
│   │       ├── data/
│   │       │   └── gemini_repository_impl.dart
│   │       ├── domain/
│   │       └── presentation/
│   │           ├── date_planner_screen.dart
│   │           ├── ai_coach_screen.dart
│   │           └── providers/ai_provider.dart
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── loading_widget.dart
│   │   │   ├── error_widget.dart
│   │   │   └── animated_counter.dart
│   │   └── extensions/
│   │       ├── datetime_extension.dart
│   │       └── string_extension.dart
│   └── services/
│       ├── notification_service.dart
│       └── widget_service.dart        ← Giao tiếp với Android Widget
├── assets/
│   ├── animations/
│   │   ├── pet_cat.riv               ← Rive file thú cưng
│   │   ├── heart_break.json          ← Lottie streak vỡ
│   │   ├── confetti.json             ← Lottie milestone
│   │   └── loading_love.json
│   ├── images/
│   └── fonts/
├── functions/                         ← Firebase Cloud Functions
│   ├── index.js
│   ├── streak/
│   │   ├── checkStreakDaily.js
│   │   └── grantRecoveryToken.js
│   ├── gamification/
│   │   └── updatePetHP.js
│   ├── mood/
│   │   └── sendMoodReminder.js
│   └── notifications/
│       └── sendPushNotification.js
├── .cursor/
│   ├── rules/
│   │   ├── flutter.mdc
│   │   ├── firebase.mdc
│   │   ├── architecture.mdc
│   │   └── testing.mdc
│   └── skills/
│       ├── riverpod_patterns.md
│       └── firebase_patterns.md
├── .cursorrules                       ← Root cursor rules
└── LOVEHUB_MASTER_PLAN.md            ← File này
```

---



## 5. SETUP MÔI TRƯỜNG CURSOR IDE



### Bước 1 — Cài đặt công cụ

```bash
# 1. Flutter SDK (nếu chưa có)
# Download từ flutter.dev, thêm vào PATH

# 2. Tạo project Flutter mới
flutter create lovehub --org com.lovehub --platforms android

# 3. Cài Firebase CLI
npm install -g firebase-tools
firebase login
firebase init  # chọn: Firestore, Functions, Storage, Hosting (optional)

# 4. FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure

# 5. Verify setup
flutter doctor
flutter pub get
```



### Bước 2 — Mở trong Cursor

```
1. Mở Cursor → Open Folder → chọn thư mục lovehub/
2. Cursor sẽ tự detect .cursorrules
3. Copy rules từ Section 6 vào .cursor/rules/
4. Cài extension: Flutter (Dart-Code), Firebase Explorer (optional)
```



### Bước 3 — Setup Android Studio để test

```
1. Mở Android Studio → Open → chọn thư mục android/ trong project
2. Sync Gradle
3. Tạo AVD: Pixel 8 / API 34 (Android 14)
4. Khi muốn test từ Cursor:
   flutter run -d <device_id>
   # Hoặc mở Android Studio → Run
```

---



## 6. CURSOR RULES & AI CONFIG



### File: `.cursorrules` (root)

```yaml
# LoveHub Flutter Project Rules
# Ref: github.com/evanca/flutter-ai-rules + custom

project:
  name: LoveHub
  type: Flutter Android App
  architecture: Clean Architecture (3 layers)
  state_management: Riverpod
  navigation: go_router

code_style:
  - Luôn dùng StatelessWidget + ConsumerWidget (Riverpod), tránh StatefulWidget trừ khi cần AnimationController
  - Tất cả Provider đặt trong features/{feature}/presentation/providers/
  - Repository interface trong domain/, implementation trong data/
  - UseCase mỗi class một method call()
  - Không đặt business logic trong Widget
  - Dùng const constructor khi có thể (performance)
  - Naming: snake_case cho files, PascalCase cho classes, camelCase cho variables

firebase:
  - Luôn handle Stream errors với .handleError()
  - Offline persistence phải được enable trong main.dart
  - Security Rules: KHÔNG dùng allow read, write: if true
  - Luôn dùng Firestore batch/transaction khi update nhiều document

android_native:
  - Widget update phải dùng WorkManager với constraints (network + battery)
  - Foreground Service phải có proper notification channel
  - Kotlin code đặt trong android/app/src/main/kotlin/

testing:
  - Mỗi UseCase phải có unit test tương ứng
  - Repository mock bằng Mockito
  - Widget test cho màn hình chính

ai_behavior:
  - Khi tạo file mới, luôn follow cấu trúc thư mục trong LOVEHUB_MASTER_PLAN.md
  - Khi viết Firestore query, luôn check Security Rules compatibility
  - Không hardcode API keys — dùng .env hoặc firebase_options.dart
  - Khi thêm package mới, kiểm tra compatibility với Flutter 3.x
```



### File: `.cursor/rules/flutter.mdc`

```
---
description: Flutter widget patterns và Clean Architecture cho LoveHub
globs: **/*.dart
alwaysApply: true
---

# Flutter Rules — LoveHub

## Widget Rules
- StatelessWidget + ConsumerWidget là default
- StatefulWidget chỉ dùng khi cần: AnimationController, TextEditingController, FocusNode
- Dùng const constructor cho widgets không thay đổi
- Extract widget nhỏ hơn 50 lines thành file riêng

## Riverpod Rules
- Provider naming: [feature][Type]Provider, ví dụ: streakStateProvider
- StateNotifier cho complex state, FutureProvider/StreamProvider cho async data
- Luôn có .when() handler cho AsyncValue: data, loading, error

## Error Handling
- Wrap Firebase calls trong try-catch
- Return Either<Failure, Success> từ Repository
- Show SnackBar cho lỗi user-facing

## Performance
- ListView.builder thay vì ListView cho danh sách dài
- Dùng AutomaticKeepAliveClientMixin cho tab content cần giữ state
- Image.network → CachedNetworkImage
```



### File: `.cursor/rules/architecture.mdc`

```
---
description: Clean Architecture enforcement cho LoveHub
globs: lib/features/**/*.dart
alwaysApply: true
---

# Architecture Rules

## Layer Dependencies (KHÔNG được vi phạm)
Presentation → Domain ✅
Data → Domain ✅
Presentation → Data ❌ (KHÔNG ĐƯỢC)
Domain → Data ❌ (KHÔNG ĐƯỢC)
Domain → Presentation ❌ (KHÔNG ĐƯỢC)

## File Templates

### Entity (domain/entities/)
class XxxEntity {
  final String id;
  // immutable, no Firebase dependency
  const XxxEntity({required this.id});
}

### Repository Interface (domain/)
abstract class XxxRepository {
  Stream<XxxEntity> watchXxx(String coupleId);
  Future<void> updateXxx(XxxEntity entity);
}

### UseCase (domain/usecases/)
class DoSomethingUseCase {
  final XxxRepository _repository;
  DoSomethingUseCase(this._repository);
  Future<void> call(params) => _repository.doSomething(params);
}
```



### File: `.cursor/skills/firebase_patterns.md`

```markdown
# Firebase Patterns cho LoveHub

## Real-time Listener pattern
```dart
StreamProvider<StreakEntity>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  return FirebaseFirestore.instance
      .doc('streaks/$coupleId')
      .snapshots()
      .map((doc) => StreakEntity.fromFirestore(doc))
      .handleError((e) => throw FirebaseException(plugin: 'firestore'));
});
```

## Offline Persistence (bắt buộc trong main.dart)

```dart
await FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Atomic Update Pattern (thú cưng HP, điểm)

```dart
await FirebaseFirestore.instance.runTransaction((tx) async {
  final ref = FirebaseFirestore.instance.doc('pets/$coupleId');
  final snap = await tx.get(ref);
  final current = snap.data()!['hp'] as int;
  tx.update(ref, {'hp': min(100, current + 30)});
});
```

```

---
```



## 7. UI DESIGN WORKFLOW — GOOGLE STITCH + MCP



### Tổng quan workflow

```
Google Stitch → Tạo UI mockup → Export MCP → Cursor nhận design
→ Flutter code tự động generate → Review & refine → Android Studio test
```



### Bước 1 — Setup Google Stitch

```
1. Truy cập: stitch.withgoogle.com
2. Đăng nhập Google account
3. Free tier: 350 standard + 200 pro generations/tháng
```



### Bước 2 — Prompt mẫu cho từng màn hình LoveHub

```
Màn hình Home:
"Design a romantic couple app home screen with dark pink/rose gradient theme.
Show: couple avatar pair, days counter (large font 'Day 365'), 
online status indicator (green dot), streak counter with fire icon,
pet character (cute cat) in the center. Bottom navigation: Home, Diary, Pet, Finance, AI.
Style: warm, soft, Gen-Z aesthetic with rounded cards."

Màn hình Streak:
"Design streak tracking screen for a couple app.
Show: fire streak counter (big '🔥 47 days'), 
calendar heatmap of last 30 days (green = both checked in, yellow = one, gray = missed),
recovery tokens display '🛡️ 3/4 tokens available',
two circular check-in buttons for each partner,
CTA: 'Check in now' button with heart animation"

Màn hình Thú cưng:
"Design virtual pet screen for couple app.
Center: cute cartoon cat character (Rive animation placeholder),
HP bar (green progress), EXP bar (pink progress), Level badge,
Love Points balance top right,
Action buttons: Feed (+HP), Play (+EXP), Change outfit
Recent activity log at bottom"

Màn hình Finance:
"Design couple finance screen - savings jar tracker.
Show: piggy bank illustration with progress fill animation,
goal title 'Trip to Dalat 🌸', progress '1,500,000 / 5,000,000 VND',
contribution history list (avatar + amount + date),
Two CTAs: 'Add manually' and 'Pay via MoMo' (MoMo purple button)"
```



### Bước 3 — Kết nối Stitch MCP với Cursor

```json
// Thêm vào .cursor/mcp.json
{
  "servers": {
    "stitch": {
      "url": "https://stitch.googleapis.com/mcp",
      "type": "http",
      "headers": {
        "X-Goog-Api-Key": "YOUR_GOOGLE_AI_API_KEY"
      }
    }
  }
}
```

```bash
# Hoặc dùng Claude Code CLI:
claude mcp add stitch --transport http https://stitch.googleapis.com/mcp \
  --header "X-Goog-Api-Key: YOUR-API-KEY"
```



### Bước 4 — Export từ Stitch sang Flutter

```
Trong Stitch:
1. Chọn screens đã tạo → Export
2. Chọn: MCP (for IDE integration)
3. Cursor tự nhận design context

Hoặc Export → Flutter → download .zip → copy vào lib/features/
```



### Animation Package quyết định (sau khi có Stitch mockup):


| Dùng cho                            | Package                         | Lý do                                   |
| ----------------------------------- | ------------------------------- | --------------------------------------- |
| Thú cưng (idle/happy/sad/levelup)   | **Rive**                        | State machine, interactive real-time    |
| Streak vỡ, confetti milestone       | **Lottie**                      | JSON từ LottieFiles.com, nhiều file sẵn |
| Micro-animations button, transition | **flutter_animate**             | Code-based, dễ customize                |
| Loading skeleton                    | **shimmer**                     | Chuẩn Material                          |
| Page transitions                    | **go_router** built-in + custom | Smooth route                            |




### Nguồn assets animation miễn phí:

- **LottieFiles.com** — tìm: "heart break", "confetti", "streak fire", "loading love"
- **Rive.app** — tìm: "cute cat", "virtual pet", "character idle"
- **Rive Community** — nhiều pet animation sẵn có

---



## 8. ROADMAP TRIỂN KHAI THEO PHASE



### Phase 0 — Setup (3-5 ngày)

- [ ] Tạo Flutter project
- [ ] Setup Firebase (Auth, Firestore, Storage, RTDB, Functions, FCM)
- [ ] Chạy `flutterfire configure`
- [ ] Setup Cursor rules (copy từ Section 6)
- [ ] Tạo 3-4 màn hình trong Google Stitch
- [ ] Kết nối Stitch MCP vào Cursor
- [ ] Tạo cấu trúc thư mục đầy đủ
- [ ] Setup go_router với placeholder screens



### Phase 1 — Core (1-2 tuần)

- [ ] Auth: đăng nhập Google/Phone
- [ ] Ghép đôi bằng mã LOVE-XXXX
- [ ] Home screen: đồng hồ đếm ngày real-time
- [ ] Firebase RTDB Presence (online/offline indicator)
- [ ] Offline persistence



### Phase 2 — Android Native (1 tuần)

- [ ] Home Screen Widget (Kotlin + home_widget)
- [ ] Persistent Notification (FlutterForegroundTask)
- [ ] WorkManager schedule notification milestone



### Phase 3 — Streak + Gamification (1-2 tuần)

- [ ] Checkin hàng ngày + Streak logic
- [ ] Recovery Token system (Cloud Functions)
- [ ] Thú cưng ảo (Rive animation + Firestore game state)
- [ ] Love Points system
- [ ] FCM nhắc checkin lúc 21h



### Phase 4 — Memory + Mood (1 tuần)

- [ ] Nhật ký chung + upload ảnh
- [ ] Love Map (Google Maps + custom marker)
- [ ] Mood Sync hàng ngày
- [ ] Mood chart (fl_chart)



### Phase 5 — Finance + MoMo (1 tuần)

- [ ] Saving Jar CRUD
- [ ] Lịch sử giao dịch
- [ ] MoMo deeplink integration
- [ ] Biểu đồ chi tiêu



### Phase 6 — AI (3-5 ngày)

- [ ] Gemini Date Planner (streaming + typewriter)
- [ ] AI Coach (context-aware prompt)
- [ ] Fallback UI khi API lỗi



### Phase 7 — Polish & Testing (1 tuần)

- [ ] Animation tinh chỉnh (Lottie/Rive)
- [ ] Unit tests UseCase
- [ ] Widget tests màn hình chính
- [ ] Performance profiling (Flutter DevTools)
- [ ] Build APK release

---



## 9. FIREBASE SECURITY RULES



### Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isCoupleMember(coupleId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/couples/$(coupleId)) &&
        (request.auth.uid == get(/databases/$(database)/documents/couples/$(coupleId)).data.user1Id ||
         request.auth.uid == get(/databases/$(database)/documents/couples/$(coupleId)).data.user2Id);
    }

    // Users
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Couples
    match /couples/{coupleId} {
      allow read: if isCoupleember(coupleId);
      allow create: if isAuthenticated();
      allow update: if isCoupleember(coupleId);
    }

    // Diaries, Streaks, Pets, Finance — chỉ couple member
    match /diaries/{coupleId}/{document=**} {
      allow read, write: if isCoupleember(coupleId);
    }

    match /streaks/{coupleId} {
      allow read, write: if isCoupleember(coupleId);
    }

    match /pets/{coupleId} {
      allow read, write: if isCoupleember(coupleId);
    }

    match /savingJars/{coupleId}/{document=**} {
      allow read, write: if isCoupleember(coupleId);
    }

    match /moods/{coupleId}/{document=**} {
      allow read, write: if isCoupleember(coupleId);
    }
  }
}
```



### Firebase Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /couples/{coupleId}/{allPaths=**} {
      allow read, write: if request.auth != null &&
        firestore.get(/databases/(default)/documents/couples/$(coupleId)).data.user1Id == request.auth.uid ||
        firestore.get(/databases/(default)/documents/couples/$(coupleId)).data.user2Id == request.auth.uid;
    }
  }
}
```

---



## 10. TESTING STRATEGY



### Unit Tests (bắt buộc)

```dart
// test/features/streak/streak_usecase_test.dart
void main() {
  group('CheckinUseCase', () {
    late MockStreakRepository mockRepo;
    late CheckinUseCase useCase;

    setUp(() {
      mockRepo = MockStreakRepository();
      useCase = CheckinUseCase(mockRepo);
    });

    test('should checkin successfully', () async {
      when(mockRepo.checkin(any)).thenAnswer((_) async => const Right(null));
      final result = await useCase.call('couple123');
      expect(result.isRight(), true);
    });

    test('recovery token cannot exceed 4', () {
      // Test token cap logic
    });

    test('streak resets to 0 when both miss 24h', () {
      // Test streak break logic
    });
  });
}
```



### Widget Tests

```dart
// test/features/streak/streak_screen_test.dart
testWidgets('shows streak counter correctly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [streakProvider.overrideWith(...)],
      child: const MaterialApp(home: StreakScreen()),
    ),
  );
  expect(find.text('47'), findsOneWidget);
  expect(find.byKey(Key('recovery_tokens')), findsOneWidget);
});
```



### Performance Targets


| Metric                 | Target              |
| ---------------------- | ------------------- |
| Firestore sync latency | < 500ms             |
| Image load (cached)    | < 200ms             |
| App startup (cold)     | < 3s                |
| Widget update          | 15 phút interval    |
| Image compression      | ~70% size reduction |
| Memory usage           | < 150MB             |


---



## 11. MẪU VIẾT CV

```
Dự án cá nhân: LoveHub — Smart Couple Connection App
Tech: Flutter 3 · Firebase · Gemini AI · MoMo API · Kotlin Android Native

• Xây dựng kiến trúc Clean Architecture 3 lớp + Riverpod state management,
  đảm bảo tách biệt hoàn toàn business logic khỏi UI layer.

• Tích hợp Firebase Firestore real-time sync (latency <500ms) + Firebase RTDB
  cho Online Presence indicator — 2 máy thật nhận dữ liệu tức thì không cần reload.

• Phát triển Android Home Screen Widget (Kotlin AppWidgetProvider + Flutter
  home_widget) và Persistent Foreground Service hiển thị đếm ngày trên
  notification bar — chứng minh khả năng Flutter ↔ Android Native integration.

• Thiết kế hệ thống Streak & Recovery Token: checkin hàng ngày, tích lũy token
  mỗi tuần (tối đa 4), khôi phục streak bị gãy — dùng Cloud Functions + FCM.

• Xây dựng Gamification engine (thú cưng ảo + Love Points + nhiệm vụ) với
  Firestore atomic transaction, tránh race condition khi 2 người update đồng thời.

• Tích hợp MoMo Open API cho tính năng "Heo đất chung" — xử lý deeplink
  payment callback, Firestore transaction log, biểu đồ chi tiêu fl_chart.

• Nhúng Google Gemini API (streaming response + typewriter effect) để xây dựng
  AI Date Planner context-aware dựa trên dữ liệu thực của cặp đôi.

• Giảm ~70% dung lượng ảnh nhờ flutter_image_compress trước khi upload,
  cached_network_image cho smooth UX khi xem lại nhật ký.
```

---



## 📌 QUICK REFERENCE — Links quan trọng


| Resource                       | URL                                      |
| ------------------------------ | ---------------------------------------- |
| Google Stitch (thiết kế UI)    | stitch.withgoogle.com                    |
| Stitch MCP docs                | stitch.googleapis.com/mcp                |
| LottieFiles (animation assets) | lottiefiles.com                          |
| Rive (pet animation)           | rive.app/community                       |
| Cursor Flutter Rules ref       | github.com/evanca/flutter-ai-rules       |
| Awesome CursorRules            | github.com/PatrickJS/awesome-cursorrules |
| MoMo Open API                  | developers.momo.vn                       |
| Firebase Console               | console.firebase.google.com              |
| Flutter pub packages           | pub.dev                                  |


---

*Plan này được cập nhật liên tục. Khi bắt đầu một Phase mới, check lại file này để đảm bảo không bỏ sót bước nào.*