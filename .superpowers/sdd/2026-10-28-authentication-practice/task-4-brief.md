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

