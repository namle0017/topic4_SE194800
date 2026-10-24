# Thiết kế bài Authentication Practice nhóm 4

## Mục đích

Hoàn thiện bài tập trong `Authentication Practice.html` trên mã nguồn hiện có. Bài phải demo được cả ba câu, có README chạy được, có kiểm thử tự động, và đủ rõ để sinh viên giải thích luồng xác thực.

## Phạm vi

### Question 1: Mock authentication

- Giữ một file độc lập chạy trên DartPad.
- Có form email/password, validation, loading giả lập, tài khoản demo, lỗi đăng nhập, protected home và logout.
- Không phụ thuộc backend hoặc package ngoài.

### Question 2: Login và register với API

- Flutter có các màn hình Login, Register, OTP verification và Home.
- Backend Node cung cấp register, verify OTP, resend OTP, login và `/api/me`.
- Register tạo tài khoản chưa kích hoạt, OTP 6 chữ số có hạn dùng và cooldown gửi lại.
- Login chỉ thành công sau khi email được kích hoạt.
- Backend cấp application access token; Flutter lưu token bằng `flutter_secure_storage`.
- Mở lại app sẽ gọi `/api/me` để khôi phục phiên.
- Có loading, lỗi dễ hiểu và logout.

### Question 3: Google OAuth qua Supabase

- Flutter mở Google OAuth bằng `supabase_flutter`.
- Mobile quay lại app qua `authlab://login-callback`; web dùng URL localhost cố định.
- Sau khi Supabase tạo session, Flutter gửi Supabase access token tới `POST /api/auth/google`.
- Backend xác thực token bằng Supabase Auth API, tạo hoặc cập nhật user, rồi cấp application access token riêng.
- Flutter chỉ dùng application token cho API backend.
- Home hiển thị tên, email và provider; logout xóa token ứng dụng và đăng xuất Supabase.

## Kiến trúc Flutter

- Refactor `lib/main.dart` thành cấu trúc `core/` và `features/` gần với tài liệu hướng dẫn.
- `AppConfig` đọc `.env` nhưng cho phép `--dart-define` ghi đè để CI và demo dễ dùng.
- Dùng `dio` cho HTTP, model typed, `AuthApiService`, `AuthRepository`, và `SecureStorageService`.
- Không thêm framework quản lý state; dùng `StatefulWidget` để phạm vi bài tập dễ giải thích.
- UI Material gọn, responsive, không cố mô phỏng template football-management.

## Kiến trúc backend

- Giữ Node HTTP server nhỏ, tách module theo trách nhiệm khi cần kiểm thử.
- User và OTP lưu trong RAM vì đây là lab; restart server sẽ mất dữ liệu.
- Mật khẩu dùng `scrypt` với salt. OTP chỉ lưu hash, có expiry, cooldown và giới hạn số lần thử.
- Token ứng dụng dùng HMAC SHA-256, kiểm tra chữ ký và hạn dùng bằng so sánh constant-time.
- Email OTP hỗ trợ SMTP qua cấu hình server. Chế độ demo cho phép đặt `DEV_OTP` bằng môi trường; server không log hoặc trả OTP trong response.
- Google Client Secret không đi vào Flutter hoặc backend source. Nó chỉ nằm trong Supabase Dashboard.

## Cấu hình và bí mật

- Thêm `.env.example` cho Flutter và backend.
- Ignore `.env`; không commit credential thật.
- Flutter chỉ nhận Supabase Project URL và publishable/anon key.
- Backend nhận `JWT_SECRET`, cấu hình SMTP, Supabase URL và publishable key qua environment.
- README mô tả Web, Android Emulator, SMTP/demo OTP và Google OAuth.

## API dự kiến

- `POST /api/auth/register`
- `POST /api/auth/email-verification/verify`
- `POST /api/auth/email-verification/resend`
- `POST /api/auth/login`
- `POST /api/auth/google`
- `GET /api/me`

Response dùng một envelope nhất quán gồm `success`, `code`, `message`, và `result` khi có dữ liệu.

## Kiểm thử và tiêu chí hoàn thành

- Node tests kiểm tra register, OTP sai/đúng/hết hạn, resend cooldown, login, token, `/api/me`, và lỗi Google token.
- Flutter tests kiểm tra validation, chuyển Login/Register, loading/error cơ bản và parse model.
- `node --test`, `dart analyze`, và `flutter test` đều đạt.
- Không log password, OTP hoặc access token.
- README đủ lệnh chạy; không chứa secret.
- Google OAuth thật cần người dùng tạo Supabase/Google project và cung cấp cấu hình ngoài source. Mã và kiểm thử không giả vờ rằng external OAuth đã chạy khi chưa có cấu hình đó.

## Không làm

- Không dùng database production, refresh token, role/permission, password reset hoặc 2FA.
- Không triển khai dịch vụ email production hay tự động sửa Supabase/Google Dashboard.
- Không thêm UI phức tạp ngoài yêu cầu bài.

## Quyết định giao cho người triển khai

- Tên file chi tiết và cách chia widget/model nhỏ.
- Cách inject clock, mailer và Supabase verifier để test backend.
- Nội dung thông báo và styling nhỏ, miễn rõ ràng và nhất quán.
