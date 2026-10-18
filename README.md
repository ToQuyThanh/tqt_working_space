# tqt_working_space

Cài môi trường dev trên Windows. Một lối vào: `setup.bat`. Phần mềm và bộ cài là JSON trong `catalog/`. Markdown chỉ là hướng dẫn. Runner bỏ qua mục đã có, rồi cài phần còn lại. Đăng nhập tài khoản không nằm trong bước cài.

## Chạy

```bat
setup.bat
setup.bat <profile>
setup.bat --component <id>
setup.bat --component <id>,<id>
setup.bat --check
setup.bat --check <profile>
setup.bat --list
setup.bat --cleanup <profile>
setup.bat --cleanup <profile> --yes
```

Menu:

- Số: cài một profile. Chỉ profile cài (`action` mặc định là `install`).
- `i`: cài đúng một component, chọn bằng số hoặc id.
- `r`: rời máy. Chọn profile `cleanup`. Mặc định chỉ in mục sẽ xóa. Gõ `yes` mới xóa.
- `c`, `p`, `l`: kiểm tra cả máy, kiểm tra một profile, liệt kê catalog.

`cleanupLevel` là `session` (xóa đường dẫn phiên) hoặc `all` (xóa phiên, rồi gỡ gói). Không có `--yes` thì `--cleanup` chỉ xem trước. Gọi profile cleanup như một lần cài thì lệnh dừng và chỉ cách dùng `--cleanup`.

Bước cần Administrator thì hỏi UAC. Mở terminal mới sau khi cài để dùng PATH vừa cập nhật.

```bat
test.bat
```

`test.bat` phải thoát mã 0. Máy thiếu phần mềm không làm test fail. Dòng `[ERROR]` từ catalog hoặc runner thì fail. Test không gọi `--cleanup ... --yes`.

Thêm phần mềm: sửa JSON theo [docs/them-thanh-phan.md](docs/them-thanh-phan.md). Quy tắc cho agent: [AGENTS.md](AGENTS.md).

## Bố cục

```text
setup.bat                 Lối vào
test.bat                  Kiểm tra catalog và runner
catalog/components.json   Từng phần mềm
catalog/profiles.json     Bộ cài và bộ xóa
runner/Setup-Machine.ps1  Menu, cài, xóa, log
runner/Lib.ps1            Hàm dùng chung
runner/scripts/           Việc một object catalog không diễn tả được
docs/                     Hướng dẫn
vendor/                   File cài local, không commit
logs/                     Không commit
```

Id của từng profile nằm trong `catalog/profiles.json`. `full` gồm mọi component. Profile cleanup không nằm trong `full` và không hiện ở menu số.

`.env.example` có `SETUP_LOG_DIR`, `CHOCO_EXTRA_ARGS`, `SETUP_NO_PAUSE`. Không ghi token. Biến của tiến trình thắng `.env`.

`vendor/` chỉ giữ bộ cài có sẵn trên máy. Catalog không gọi các file đó. Các file `.bat` cài riêng trước đây đã gộp vào catalog.
