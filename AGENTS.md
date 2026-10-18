# AGENTS.md

Repo này cài công cụ dev trên Windows. Người và agent thêm phần mềm bằng catalog, không thêm file `.bat` ở thư mục gốc.

## Lối vào

- `setup.bat` gọi `runner/Setup-Machine.ps1`.
- `catalog/components.json` mô tả từng mục (schema version 1).
- `catalog/profiles.json` gom id thành bộ cài.
- `runner/Lib.ps1` đọc JSON, sắp thứ tự theo `dependsOn`, kiểm tra đã cài chưa, gọi Chocolatey / WinGet / lệnh / script.
- `runner/scripts/` chỉ chứa việc catalog không diễn tả được bằng một object.

PowerShell đích là Windows PowerShell 5.1. Không dùng cú pháp PowerShell 7 (`&&`, `??`, ternary).

## Thêm một gói Chocolatey

Ví dụ 7-Zip:

1. Thêm object vào `components` trong `catalog/components.json`.
2. `id` viết thường, số, dấu gạch: `7zip` không hợp lệ vì bắt đầu bằng số; dùng `seven-zip`.
3. `detect` là tên lệnh hoặc đường dẫn file, không phải cả câu lệnh. `python` và `python3` trỏ vào `WindowsApps` không được tính là đã cài.
4. `install.type` là `choco`, `package` là id đúng trên Chocolatey.
5. `dependsOn` thường là `["choco"]`. `admin` là `true` nếu bước cài cần Administrator.
6. Thêm id đó vào các profile cần nó trong `catalog/profiles.json`, kể cả `full` nếu máy đầy đủ phải có nó.
7. Chạy `test.bat`. Lệnh này phải thoát với mã 0.

```json
{
  "id": "seven-zip",
  "name": "7-Zip",
  "description": "7-Zip",
  "detect": { "type": "path", "paths": ["%ProgramFiles%\\7-Zip\\7z.exe"] },
  "install": { "type": "choco", "package": "7zip" },
  "dependsOn": ["choco"],
  "admin": true
}
```

Runner tự cài dependency trước. Một mục đã có trên máy thì bị bỏ qua.

## Khi nào được thêm script

Chỉ khi `command`, `path`, `choco`, hoặc `winget` không đủ. Đặt file trong `runner/scripts/`. Catalog trỏ tới tên file, không ghi đường dẫn tuyệt đối.

- `detect.type = script`: process con, exit 0 nghĩa là đã có, exit 1 nghĩa là chưa có.
- `install.type = script`: process con, exit 0 là thành công. Ném lỗi bằng `throw`.
- Không gọi `exit` trong code chạy cùng process với runner. Script được gọi bằng process con nên `exit` trong file script là được.

Script đặc biệt hiện có: Chocolatey bootstrap, tìm VS Code, extension Python, tìm DBeaver và tạo shortcut, PostgreSQL, Redis, Windows Terminal (MSIX khi WinGet và Chocolatey đều thất bại).

`install.type = fallback` thử lần lượt `steps`. Không lồng `fallback` bên trong `steps`. Bước sau chỉ chạy khi bước trước không làm `detect` thành công.

`afterInstall` chạy sau khi mục đã có, kể cả khi máy đã cài từ trước. Lỗi ở bước này là cảnh báo, không hủy mục đã cài.

## Đăng nhập tài khoản

Chưa làm trong menu. Chưa thêm component đăng nhập GitHub hay Grok. Khi cần, thêm object `install.type = command` và để nó ngoài profile cài máy, để lần cài mặc định không mở trình duyệt. Không ghi token vào JSON, `.env`, hay script.

## File không được thêm hoặc commit

- Không tạo `install-*.bat` mới ở gốc.
- Không commit `.env`, `logs/`, hay file cài trong `vendor/` (đã có trong `.gitignore`).
- Không ghi bí mật vào `components.json`. `.env.example` chỉ chứa biến tùy chọn của runner: `SETUP_LOG_DIR`, `CHOCO_EXTRA_ARGS`, `SETUP_NO_PAUSE`.
- Biến đã có trong môi trường tiến trình thắng `.env`.

## Kiểm tra sau khi sửa

Chạy `test.bat` tại thư mục gốc. Lệnh phải in `All tests passed.` và thoát với mã 0.

Bộ test kiểm tra catalog, thứ tự dependency, `--list`, `--help`, và lỗi id không tồn tại. `setup.bat --check` chỉ báo phần mềm đã có hay chưa có trên máy. Máy thiếu Firefox hay PostgreSQL không làm `test.bat` thất bại. Dòng `[ERROR]` từ runner thì có.
