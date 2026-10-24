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

