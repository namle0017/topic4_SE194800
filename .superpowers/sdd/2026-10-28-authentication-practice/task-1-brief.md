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

