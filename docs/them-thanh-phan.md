# Thêm một thành phần

Dữ liệu nằm ở `catalog/components.json` và `catalog/profiles.json`. Cả hai file có `"version": 1`. Runner không đọc Markdown.

## Component

| Field | Bắt buộc | Ý nghĩa |
|---|---|---|
| `id` | có | Khóa duy nhất. Chữ thường, số, dấu gạch. Không bắt đầu bằng số. |
| `name` | có | Tên trên menu và log. |
| `description` | không | Một dòng giải thích. |
| `detect` | có | Cách biết máy đã có chưa. |
| `install` | có | Cách cài. |
| `afterInstall` | không | Việc làm sau khi mục đã có. Lỗi ở đây là cảnh báo. |
| `remove` | không | Dữ liệu xóa khi rời máy. |
| `dependsOn` | có | Id cài trước. `[]` nếu không phụ thuộc ai. |
| `admin` | có | `true` nếu bước cài cần Administrator. |

`detect.type`:

- `command`: tên chương trình, không có đối số. `python` và `python3` trong `WindowsApps` là stub, tính là chưa có. `winget` trong `WindowsApps` vẫn là đã có.
- `path`: mảng `paths`. Một file tồn tại là đã có. Được dùng biến kiểu `%ProgramFiles%` và `%USERPROFILE%`.
- `script`: tên file trong `runner/scripts/`. Exit 0 là đã có.

`install.type`:

- `choco`: field `package`. Exit 0 hoặc 3010 là thành công.
- `winget`: field `id`.
- `command`: field `run`, PowerShell trong process con. Lỗi thì `throw`. Không `exit` trong chuỗi `run`.
- `script`: field `script`, tên file trong `runner/scripts/`.
- `fallback`: field `steps`, các kiểu ở trên. Không lồng `fallback`. Bước sau chỉ chạy khi detect vẫn chưa thành công.

Detect phải khớp terminal người dùng mở, không chỉ process đang `ExecutionPolicy Bypass`.

## Profile

Profile cài là `id`, `name`, `description`, và mảng `components`. Runner tự kéo dependency vào trước. `full` phải liệt kê mọi component id.

Profile rời máy thêm `"action": "cleanup"` và `"cleanupLevel": "session"` hoặc `"all"`. Mọi id trong profile đó phải có `remove`. Không đưa profile này vào `full`. Menu số không hiện nó. Menu `r` và `setup.bat --cleanup <id>` mới dùng nó.

Thứ tự xóa ngược thứ tự cài, và chỉ đúng id được ghi. Trong một mục, xóa `session` trước, `package` sau khi level là `all`.

## remove

- `session`: mảng đường dẫn.
- `package`: mảng bước `choco`, `npm`, hoặc `path`. `choco` và `npm` dùng `package`. `path` dùng `path`.

Đường dẫn chỉ được nằm dưới `%USERPROFILE%`, `%APPDATA%`, hoặc `%LOCALAPPDATA%`, và không được là chính thư mục gốc đó. Không wildcard, không ổ đĩa, không thư mục Windows, không hồ sơ user khác.

Xóa thật chỉ khi có `--yes` hoặc người dùng gõ `yes` trong menu.

## Ví dụ

```json
{
  "id": "seven-zip",
  "name": "7-Zip",
  "description": "7-Zip",
  "detect": { "type": "path", "paths": ["%ProgramFiles%\\7-Zip\\7z.exe"] },
  "install": { "type": "choco", "package": "7zip" },
  "remove": {
    "session": ["%APPDATA%\\7-Zip"],
    "package": [{ "type": "choco", "package": "7zip" }]
  },
  "dependsOn": ["choco"],
  "admin": true
}
```

Gắn id vào `components` của profile cần nó. Phần lớn gói chỉ cần object như trên. Thêm file trong `runner/scripts/` khi `command`, `path`, `choco`, hoặc `winget` không đủ. Catalog ghi tên file, không ghi đường dẫn tuyệt đối.
