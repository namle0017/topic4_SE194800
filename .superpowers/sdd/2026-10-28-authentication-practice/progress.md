# SDD ledger — plan: docs/superpowers/plans/2026-10-28-authentication-practice.md

- Setup Ruling: workspace không có `.git`, nên không thể tạo worktree, lấy BASE, commit hoặc dùng task-done/review-package theo Git — triển khai tại workspace hiện tại, giữ ledger sau khi hoàn tất — cost if wrong: thay đổi không có lịch sử Git để rollback theo từng task.
- Pre-flight: Task 2 produces auth core, application token và HTTP endpoints; Task 3 consumes và mở rộng đúng interfaces — compatible.
- Pre-flight: Task 4 produces `AuthGateway` và typed models; Tasks 5–6 consume cùng method names — compatible.
- Pre-flight Ruling: Task 5 từng yêu cầu `App(authGateway, googleAuthGateway)` trước khi Task 6 tạo `GoogleAuthGateway` — sửa Task 5 thành `App(authGateway)`, Task 6 mở rộng constructor — cost if wrong: một lần đổi constructor và cập nhật widget tests.
- Pre-flight: Task 5 produces auth pages/Home; Task 6 extends Google integration without changing email flow — compatible.
- Pre-flight: Task 7 consumes commands/configuration produced by Tasks 1–6 — compatible.
- Baseline: `backend_server/server.js` syntax và `flutter analyze` pass; `flutter test` trả exit 1 vì chưa có test file, đúng trạng thái ban đầu.
- Task 1 Ruling: cả `dart analyze question1_dartpad.dart` và `flutter analyze ../question1_dartpad.dart` không resolve Flutter SDK cho file ngoài package — dùng widget test import file thật để chứng minh compile/behavior, cộng `dart format` — cost if wrong: không có analyzer độc lập cho file DartPad, nhưng compiler của Flutter test vẫn biên dịch chính file đó.
- Task 1: complete (no commits; tests: `flutter test` → 2 passed, 0 failed; RED observed for raw token exposure, GREEN after removal).
- Task 2 Ruling: plan dự kiến RED do module chưa tồn tại, nhưng TDD yêu cầu failure behavior thay vì import error — test đầu chạy server cũ và fail `201 !== 202`, sau đó các vòng RED dùng methods/endpoints thiếu — cost if wrong: integration test khởi động process thật chậm hơn unit test nhưng kiểm tra đúng boundary HTTP.
- Task 2: complete (no commits; tests: `npm test` → 9 passed, 0 failed; `node --check server.js` exit 0).
- Task 3: complete (no commits; tests: `npm test` → 13 passed, 0 failed; Nodemailer installed; syntax checks exit 0; RED observed for missing sender, Google endpoint, network failure and Google-only password login).
