# AGENTS.md

Repo cài công cụ dev trên Windows. Thêm phần mềm bằng catalog JSON. Không thêm `.bat` ở thư mục gốc. Không ghi dữ liệu catalog vào Markdown.

## Lối vào

- `setup.bat` gọi `runner/Setup-Machine.ps1`. PowerShell đích là 5.1. Không dùng `&&`, `??`, hay ternary.
- `catalog/components.json` và `catalog/profiles.json` có `"version": 1`. Field nằm ở [docs/them-thanh-phan.md](docs/them-thanh-phan.md).
- `runner/Lib.ps1` đọc JSON, sắp `dependsOn`, detect, cài, và dựng bước xóa.
- `runner/scripts/` chỉ khi một object catalog không đủ. Catalog ghi tên file, không ghi đường dẫn tuyệt đối.

Cách chạy, menu `i` / `r`, và `--cleanup` nằm ở [README.md](README.md).

## Sửa catalog

1. Thêm một component. `id` chữ thường, số, dấu gạch, không bắt đầu bằng số.
2. Gắn id vào profile cài cần nó. Máy đầy đủ thì thêm vào `full`. `full` phải đúng tập mọi component id.
3. Có dữ liệu cần xóa khi rời máy thì thêm `remove`, rồi gắn id vào profile `"action": "cleanup"`. Không đưa profile cleanup vào `full`.
4. Chạy `test.bat`. Lệnh phải in `All tests passed.` và thoát mã 0.

Runner cài dependency trước cả khi profile không ghi dependency đó. Mục đã detect thì bỏ qua bước cài, nhưng vẫn chạy `afterInstall`. Lỗi `afterInstall` là cảnh báo.

Script detect và install chạy ở process con. Trong chuỗi `command.run` thì `throw`, không `exit`. Không gọi `exit` trong code đang chạy cùng process với runner.

## Rời máy

- Dùng menu `r` hoặc `setup.bat --cleanup <profile>`. Không có `--yes` thì chỉ in, không xóa.
- Trong menu, xóa khi người dùng gõ `yes`.
- `setup.bat <profile-cleanup>` phải lỗi và chỉ cách dùng `--cleanup`.
- Test chỉ dry-run. Không chạy `--cleanup ... --yes`.

## Ngoài phạm vi

Đăng nhập tài khoản và mở trình duyệt không chạy trong lúc cài. Khi làm sau này, để ngoài profile cài máy. Không ghi token vào JSON, `.env`, hay script.

## File và biến

- Không tạo `install-*.bat` ở gốc.
- Không commit `.env`, `logs/`, hay `vendor/*.exe`.
- `.env.example` chỉ có `SETUP_LOG_DIR`, `CHOCO_EXTRA_ARGS`, `SETUP_NO_PAUSE`. Biến của tiến trình thắng `.env`.
- Tham số `$Component` trong `Setup-Machine.ps1` là `[string]`. Không gán object catalog vào `$component` trong thân script. PowerShell không phân biệt hoa thường, nên gán đó làm mất object. Dùng tên khác, ví dụ `$entry`.

## Test

`test.bat` kiểm tra parse, catalog, thứ tự dependency, `--list`, `--help`, id sai, và dry-run cleanup. `setup.bat --check` chỉ phân loại đã có hoặc chưa có. Thiếu phần mềm là được. `[ERROR]` do catalog hoặc runner hỏng thì không được.
