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

