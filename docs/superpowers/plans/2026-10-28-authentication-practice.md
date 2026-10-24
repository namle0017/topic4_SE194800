# Authentication Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện bài Authentication Practice nhóm 4 với mock auth, API email/OTP và Google OAuth qua Supabase.

**Architecture:** Flutter tách cấu hình, network, storage, repository và UI theo feature; mọi màn hình phụ thuộc `AuthGateway` để test không cần mạng. Backend Node dùng HTTP server nhỏ, core auth có dependency injection cho clock, OTP sender và Supabase verifier; dữ liệu chỉ lưu RAM.

**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, Dio, Supabase Flutter, flutter_secure_storage, flutter_dotenv, Node.js 24, node:test, Nodemailer.

**Spec:** `docs/superpowers/specs/2026-10-28-authentication-practice-design.md`

## Global Constraints

- Q1 phải chạy độc lập trên DartPad và không dùng package ngoài Flutter SDK.
- Flutter dùng Supabase Project URL và publishable/anon key; không chứa Client Secret hoặc service-role key.
- Backend không log password, OTP hoặc access token.
- Token ứng dụng chỉ lưu qua `flutter_secure_storage`.
- User và OTP lưu RAM; restart server làm mất dữ liệu.
- `.env` phải bị ignore; chỉ `.env.example` được lưu.
- Workspace hiện không có Git repository; thay bước commit bằng checkpoint xác minh file và test.

## Review Focus

- Email khác hoa/thường phải được chuẩn hóa và không tạo hai tài khoản; Task 2 có test duplicate case-insensitive.
- JSON sai hoặc body vượt giới hạn phải trả 400/413 thay vì làm server crash; Task 2 có API tests.
- OTP sai nhiều lần, hết hạn hoặc resend sớm phải bị chặn; Task 2 có clock-injected tests.
- API trả body không phải JSON hoặc mất mạng phải thành thông báo người dùng; Task 4 có service tests.
- Supabase phát nhiều sự kiện `signedIn` cho cùng session không được gọi backend hai lần; Task 6 có widget/service test.

---

### Task 1: Hoàn thiện Question 1 độc lập

**Files:**
- Modify: `question1_dartpad.dart`

**Interfaces:**
- Produces: `AuthService.login(String email, String password) -> Future<String>` và demo UI độc lập.

- [ ] **Step 1: Kiểm tra thủ công các acceptance cases hiện có**

Xác nhận file có validation email/password, tài khoản `demo@test.com / 123456`, loading, lỗi, protected home và logout. Ghi lại gap duy nhất: token đang bị hiển thị trên UI.

- [ ] **Step 2: Sửa demo để không hiển thị raw token**

Giữ token làm điều kiện vào `HomePage`, nhưng chỉ hiển thị trạng thái authenticated và email.

- [ ] **Step 3: Format và kiểm tra phân tích tĩnh**

Run: `dart format question1_dartpad.dart`

Run: `dart analyze question1_dartpad.dart`

Expected: `No issues found!`

- [ ] **Step 4: Checkpoint**

Xác nhận file vẫn có thể copy nguyên khối vào DartPad.

### Task 2: Backend email/password và OTP

**Files:**
- Create: `backend_server/package.json`
- Create: `backend_server/src/token.js`
- Create: `backend_server/src/auth_store.js`
- Create: `backend_server/src/auth_service.js`
- Create: `backend_server/src/http_app.js`
- Create: `backend_server/test/auth_api.test.js`
- Modify: `backend_server/server.js`

**Interfaces:**
- Produces: `createAuthService({store, secret, clock, generateOtp, sendOtp})`.
- Produces: `createHttpServer({authService, verifyGoogleToken}) -> http.Server`.
- Produces endpoints register, verify, resend, login và `/api/me` với envelope `{success, code, message, result?}`.

- [ ] **Step 1: Viết test thất bại cho register và chuẩn hóa email**

Trong `auth_api.test.js`, assert register trả 202 cùng `verificationId` và `cooldownSeconds`; đăng ký lại cùng email khác hoa/thường trả 409; response không chứa OTP/password/hash.

- [ ] **Step 2: Chạy test register để xác nhận thất bại**

Run: `node --test test/auth_api.test.js --test-name-pattern="register"`

Expected: FAIL vì module `src/http_app.js` chưa tồn tại.

- [ ] **Step 3: Cài core store, password hashing và register**

Tạo `InMemoryAuthStore`; tạo `register({name, email, password})`; chuẩn hóa email lowercase; dùng `crypto.scryptSync`; lưu OTP hash, expiry 10 phút, cooldown 60 giây và tối đa 5 lần thử.

- [ ] **Step 4: Viết test thất bại cho verify/resend/login**

Assert OTP sai, hết hạn, quá 5 lần, resend trước cooldown, resend sau cooldown, login trước activation, login sai password và login thành công.

- [ ] **Step 5: Chạy nhóm test OTP/login để xác nhận thất bại**

Run: `node --test test/auth_api.test.js --test-name-pattern="OTP|login|resend"`

Expected: FAIL tại endpoint hoặc method chưa cài.

- [ ] **Step 6: Cài verify, resend, login và application token**

Trong `token.js`, cung cấp `issueToken(payload, secret, now)` và `verifyToken(token, secret, now)`; dùng HMAC SHA-256, expiry 1 giờ và `crypto.timingSafeEqual`.

- [ ] **Step 7: Viết test thất bại cho `/api/me`, JSON sai và body lớn**

Assert bearer token hợp lệ trả user; token sai/hết hạn trả 401; JSON sai trả 400; body trên 64 KiB trả 413; server vẫn xử lý request kế tiếp.

- [ ] **Step 8: Cài HTTP routing và giới hạn request body**

`createHttpServer` map lỗi domain sang status; luôn thêm JSON content type và CORS; OPTIONS trả 204.

- [ ] **Step 9: Chạy toàn bộ backend tests**

Run: `node --test`

Expected: tất cả tests PASS.

- [ ] **Step 10: Checkpoint**

Run: `node --check server.js`

Expected: exit code 0.

### Task 3: SMTP và Supabase token exchange ở backend

**Files:**
- Create: `backend_server/src/config.js`
- Create: `backend_server/src/otp_sender.js`
- Create: `backend_server/src/supabase_verifier.js`
- Create: `backend_server/.env.example`
- Modify: `backend_server/package.json`
- Modify: `backend_server/src/http_app.js`
- Modify: `backend_server/src/auth_service.js`
- Modify: `backend_server/server.js`
- Modify: `backend_server/test/auth_api.test.js`

**Interfaces:**
- Consumes: `createHttpServer` và auth store từ Task 2.
- Produces: `createOtpSender(config).send({email, otp}) -> Future<void>`.
- Produces: `verifySupabaseToken(accessToken, {url, publishableKey, fetchImpl}) -> Promise<{email, name}>`.
- Produces: `POST /api/auth/google` trả application token và user.

- [ ] **Step 1: Viết test thất bại cho OTP sender và Google exchange**

Assert test-injected sender nhận OTP nhưng response không lộ OTP; Supabase 401/non-JSON/network error trả 401/502 phù hợp; token hợp lệ tạo user provider `google` và application token.

- [ ] **Step 2: Chạy test để xác nhận thất bại**

Run: `node --test test/auth_api.test.js --test-name-pattern="Google|sender"`

Expected: FAIL vì verifier/sender chưa tồn tại.

- [ ] **Step 3: Cài cấu hình và Nodemailer sender**

`loadConfig(env)` đọc `PORT`, `JWT_SECRET`, `DEV_OTP`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`; thiếu SMTP và `DEV_OTP` phải báo lỗi rõ khi register.

Run: `npm install`

Expected: Nodemailer được cài theo `package.json` và `package-lock.json` được tạo.

- [ ] **Step 4: Cài Supabase verifier và `/api/auth/google`**

Gọi `GET <SUPABASE_URL>/auth/v1/user` với `Authorization: Bearer` và `apikey`; không log token; cấp application token sau khi xác thực.

- [ ] **Step 5: Chặn xử lý Google trùng trong backend**

Upsert theo email chuẩn hóa; request lặp lại không tạo user thứ hai.

- [ ] **Step 6: Chạy backend tests và audit output**

Run: `node --test`

Expected: PASS và output không chứa password, OTP hoặc token mẫu.

- [ ] **Step 7: Checkpoint**

Run: `npm install`

Run: `npm test`

Expected: lockfile được tạo và tests PASS.

### Task 4: Flutter data, config và storage layer

**Files:**
- Modify: `flutter_app/pubspec.yaml`
- Modify: `flutter_app/.gitignore`
- Create: `flutter_app/.env.example`
- Create: `flutter_app/lib/core/config/app_config.dart`
- Create: `flutter_app/lib/core/network/api_client.dart`
- Create: `flutter_app/lib/core/network/api_exception.dart`
- Create: `flutter_app/lib/core/storage/secure_storage_service.dart`
- Create: `flutter_app/lib/features/auth/data/auth_models.dart`
- Create: `flutter_app/lib/features/auth/data/auth_api_service.dart`
- Create: `flutter_app/lib/features/auth/data/auth_gateway.dart`
- Create: `flutter_app/lib/features/auth/data/auth_repository.dart`
- Create: `flutter_app/test/features/auth/data/auth_models_test.dart`
- Create: `flutter_app/test/features/auth/data/auth_api_service_test.dart`

**Interfaces:**
- Produces: `AppConfig.load()` và getters `baseUrl`, `supabaseUrl`, `supabasePublishableKey`, `supabaseRedirectUrl`.
- Produces: `abstract interface class AuthGateway` với `login`, `register`, `verifyEmail`, `resendEmailVerification`, `loginWithGoogle`, `restoreSession`, `logout`.
- Produces: typed request/response/session models dùng bởi UI.

- [ ] **Step 1: Viết model parsing tests thất bại**

Assert envelope hợp lệ parse đúng; thiếu `result`, `accessToken`, email hoặc kiểu dữ liệu sai ném `ApiException` có message ổn định.

- [ ] **Step 2: Chạy model tests để xác nhận thất bại**

Run: `flutter test test/features/auth/data/auth_models_test.dart`

Expected: FAIL vì model chưa tồn tại.

- [ ] **Step 3: Thêm dependencies và typed models**

Thêm `dio`, `flutter_dotenv`; giữ `supabase_flutter`, `flutter_secure_storage`; khai báo `.env` asset và `.env` trong `.gitignore`.

Run: `flutter pub get`

Expected: dependency resolution thành công và `pubspec.lock` được cập nhật.

- [ ] **Step 4: Viết service tests thất bại**

Inject Dio `HttpClientAdapter`; assert endpoint/body/header; non-JSON, timeout và connection error đều thành `ApiException` dùng được cho UI.

- [ ] **Step 5: Chạy service tests để xác nhận thất bại**

Run: `flutter test test/features/auth/data/auth_api_service_test.dart`

Expected: FAIL tại `AuthApiService`.

- [ ] **Step 6: Cài config, API service, repository và secure storage**

`.env` là optional; `String.fromEnvironment` ghi đè giá trị dotenv. Repository lưu application token sau email/Google login, dùng token cho `/api/me`, và xóa token khi logout.

- [ ] **Step 7: Chạy data tests**

Run: `flutter test test/features/auth/data`

Expected: PASS.

- [ ] **Step 8: Checkpoint**

Run: `flutter analyze`

Expected: `No issues found!`

### Task 5: Flutter email login, register, OTP và Home

**Files:**
- Create: `flutter_app/lib/app.dart`
- Create: `flutter_app/lib/features/auth/presentation/auth_gate.dart`
- Create: `flutter_app/lib/features/auth/presentation/login_page.dart`
- Create: `flutter_app/lib/features/auth/presentation/register_page.dart`
- Create: `flutter_app/lib/features/auth/presentation/otp_verification_page.dart`
- Create: `flutter_app/lib/features/home/presentation/home_page.dart`
- Create: `flutter_app/test/features/auth/presentation/auth_flow_test.dart`
- Modify: `flutter_app/lib/main.dart`

**Interfaces:**
- Consumes: `AuthGateway` và auth models từ Task 4.
- Produces: `App(authGateway)`, `AuthGate`, các auth pages và `HomePage(session)`; Task 6 mở rộng constructor để nhận `GoogleAuthGateway`.

- [ ] **Step 1: Viết widget tests thất bại cho validation và chuyển màn hình**

Assert email sai/password dưới 6 không gọi gateway; Register thành công mở OTP page với `verificationId`, email và cooldown; Login thành công mở Home.

- [ ] **Step 2: Chạy widget tests để xác nhận thất bại**

Run: `flutter test test/features/auth/presentation/auth_flow_test.dart`

Expected: FAIL vì pages chưa tồn tại.

- [ ] **Step 3: Cài App, AuthGate, Login và Register**

AuthGate gọi `restoreSession` một lần; hiển thị progress; chuyển Login hoặc Home. Form có loading, error và controller disposal.

- [ ] **Step 4: Viết widget tests thất bại cho OTP**

Assert chỉ nhận 6 chữ số; verify sai giữ page và báo lỗi; verify đúng về Login; resend bị khóa theo cooldown rồi được mở; dispose hủy timer.

- [ ] **Step 5: Cài OTP input, countdown và Home/logout**

OTP page dùng input native 6 số; không log mã. Home hiển thị name/email/provider; logout quay về Login.

- [ ] **Step 6: Chạy widget tests**

Run: `flutter test test/features/auth/presentation/auth_flow_test.dart`

Expected: PASS.

- [ ] **Step 7: Checkpoint**

Run: `flutter analyze`

Expected: `No issues found!`

### Task 6: Flutter Google OAuth coordination

**Files:**
- Create: `flutter_app/lib/features/auth/data/google_auth_gateway.dart`
- Create: `flutter_app/lib/features/auth/data/supabase_google_auth_gateway.dart`
- Create: `flutter_app/lib/features/auth/presentation/google_auth_coordinator.dart`
- Modify: `flutter_app/lib/features/auth/presentation/login_page.dart`
- Modify: `flutter_app/lib/features/auth/presentation/auth_gate.dart`
- Modify: `flutter_app/lib/features/home/presentation/home_page.dart`
- Modify: `flutter_app/android/app/src/main/AndroidManifest.xml`
- Create: `flutter_app/test/features/auth/presentation/google_auth_test.dart`

**Interfaces:**
- Produces: `abstract interface class GoogleAuthGateway` với `Stream<String> get accessTokens`, `signIn()` và `signOut()`.
- Produces: `GoogleAuthCoordinator.processAccessToken(String token)` chống xử lý trùng.
- Consumes: `AuthGateway.loginWithGoogle(String accessToken)`.

- [ ] **Step 1: Viết tests thất bại cho Google button và event deduplication**

Assert chưa cấu hình Supabase báo lỗi; click khi cấu hình gọi `signIn`; hai event cùng token chỉ gọi backend một lần; token mới gọi lần mới; logout gọi cả hai gateway.

- [ ] **Step 2: Chạy Google tests để xác nhận thất bại**

Run: `flutter test test/features/auth/presentation/google_auth_test.dart`

Expected: FAIL vì gateway/coordinator chưa tồn tại.

- [ ] **Step 3: Cài Supabase gateway và coordinator**

Web dùng redirect mặc định; mobile dùng `authlab://login-callback`; OAuth query có `prompt=select_account`; listener được cancel khi widget dispose.

- [ ] **Step 4: Xác nhận Android deep link**

Manifest phải có VIEW/DEFAULT/BROWSABLE với scheme `authlab` và host `login-callback`; không tạo intent filter trùng.

- [ ] **Step 5: Chạy Google tests và toàn bộ Flutter tests**

Run: `flutter test`

Expected: tất cả tests PASS.

- [ ] **Step 6: Checkpoint**

Run: `flutter analyze`

Expected: `No issues found!`

### Task 7: README, cấu hình mẫu và kiểm chứng cuối

**Files:**
- Modify: `README.md`
- Modify: `flutter_app/README.md`
- Verify: `backend_server/.env.example`
- Verify: `flutter_app/.env.example`

**Interfaces:**
- Consumes: tất cả lệnh chạy, biến môi trường và flows từ Tasks 1–6.
- Produces: hướng dẫn demo và giải thích flow đủ cho bài nộp.

- [ ] **Step 1: Viết README gốc**

Mô tả Q1, Q2, Q3; lệnh backend; Flutter web port 3000; Android `10.0.2.2`; tài khoản demo Q1; OTP SMTP/`DEV_OTP`; Google Cloud/Supabase callback; không ghi secret.

- [ ] **Step 2: Viết Flutter README**

Liệt kê cấu trúc module, `.env` hoặc `--dart-define`, deep link, flow token exchange và troubleshooting ngắn.

- [ ] **Step 3: Chạy verification matrix**

Run: `node --test` trong `backend_server`.

Run: `dart analyze question1_dartpad.dart` tại root.

Run: `flutter analyze` và `flutter test` trong `flutter_app`.

Expected: tất cả exit code 0; analyzer báo không có issue.

- [ ] **Step 4: Kiểm tra bí mật và file cấu hình**

Run: `rg -n "service_role|client_secret|BEGIN PRIVATE KEY|password\s*=|accessToken\s*=" . -g '!Authentication Practice.html' -g '!**/pubspec.lock' -g '!**/package-lock.json'`

Expected: không có credential thật; chỉ placeholder, model field hoặc test fixture vô hại.

- [ ] **Step 5: Kiểm tra thay đổi cuối**

Liệt kê file mới/sửa, xác nhận không có build artifact hoặc `.env` thật. Ghi rõ Google OAuth/SMTP thật chưa thể end-to-end nếu chưa có cấu hình external.
