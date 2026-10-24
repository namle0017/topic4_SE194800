# Module 10 Lab - Authentication (nhom4)

| Câu | File |
|---|---|
| Q1 Mock auth (DartPad) | `question1_dartpad.dart` - demo: `demo@test.com` / `123456` |
| Q2 Login/Register API | `backend_server/server.js` + `flutter_app/lib/main.dart` |
| Q3 Google (Supabase) | `flutter_app/lib/main.dart` (nút Continue with Google) |

## Q1
Dán file vào https://dartpad.dev và Run.

## Q2 - chạy
```
cd backend_server && node server.js        # http://localhost:8080 (không cần npm install)
cd flutter_app && flutter pub get
flutter run -d chrome                       # web
flutter run --dart-define=BASE_URL=http://10.0.2.2:8080   # Android emulator
```
Flow: UI → `AuthService` (http) → `POST /api/auth/register|login` → access token (HMAC JWT) →
lưu bằng `flutter_secure_storage` → Home → Logout (xóa token). Mở lại app sẽ gọi `GET /api/me` để khôi phục phiên.

## Q3 - cấu hình Google + Supabase
1. Google Cloud: tạo OAuth consent (thêm Test Users), tạo **Web Client** (Android: thêm Android Client đúng package `com.nhom4.auth_lab` + SHA-1).
2. Authorized redirect URI của Google = `https://<project>.supabase.co/auth/v1/callback`.
3. Supabase → Authentication → Providers → Google: nhập Client ID/Secret. Thêm `authlab://login-callback` vào Redirect URLs (web: thêm URL localhost).
4. Chạy:
```
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```
Flow: Flutter → Supabase → Google OAuth → Supabase callback → deep link `authlab://login-callback` → session → Home.
Vai trò: Google OAuth xác thực user mà app không biết password Google; Supabase quản lý OAuth, user và session.
Không commit key/secret; chỉ truyền qua `--dart-define`.
