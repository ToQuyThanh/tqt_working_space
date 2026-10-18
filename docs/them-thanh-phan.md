# Thêm một thành phần

Dữ liệu nằm ở `catalog/components.json` và `catalog/profiles.json`. Cả hai file có `"version": 1`. Markdown này chỉ giải thích field. Runner không đọc file Markdown.

## Component

| Field | Bắt buộc | Ý nghĩa |
|---|---|---|
| `id` | có | Khóa duy nhất. Chữ thường, số, dấu gạch. Không bắt đầu bằng số. |
| `name` | có | Tên hiện trên menu và log. |
| `description` | không | Một dòng giải thích. |
| `detect` | có | Cách biết máy đã có chưa. |
| `install` | có | Cách cài. |
| `afterInstall` | không | Việc làm sau khi đã có, ví dụ tạo shortcut. |
| `dependsOn` | có | Mảng id cài trước. Dùng `[]` nếu không phụ thuộc ai. |
| `admin` | có | `true` nếu bước cài cần Administrator. |

`detect.type`:

- `command`: tên chương trình, ví dụ `git`. Không ghi đối số. Riêng `python` và `python3` trong `WindowsApps` bị bỏ qua vì đó là stub của Microsoft Store. `winget` trong `WindowsApps` vẫn được tính là đã có.
- `path`: mảng `paths`. Có một file tồn tại là đã cài. Được ghi biến môi trường kiểu `%ProgramFiles%` và `%USERPROFILE%`.
- `script`: tên file trong `runner/scripts/`. Exit 0 là đã cài.

`install.type`:

- `choco`: field `package` là id Chocolatey.
- `winget`: field `id` là id WinGet.
- `command`: field `run` là câu lệnh PowerShell, chạy trong process con. Khi lỗi, `throw`. Không dùng `exit` trong chuỗi `run`.
- `script`: field `script` là tên file trong `runner/scripts/`.
- `fallback`: field `steps` là mảng các bước thuộc bốn kiểu trên. Không để `fallback` bên trong `steps`.

Profile là một id cộng với mảng id component. Runner tự kéo dependency vào trước, kể cả khi profile không ghi dependency đó. Vẫn nên ghi dependency trong profile cho dễ đọc.

## Ví dụ chỉ cần JSON

Gói Chocolatey thông thường:

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

Gắn `"seven-zip"` vào `components` của profile cần nó.

## Ví dụ lệnh cài riêng

Mục `grok` trong catalog dùng trình cài PowerShell chính thức. Cài và đăng nhập là hai việc khác nhau. Lần đầu chạy `grok` mới mở trình duyệt. Menu chưa có bước đăng nhập.

```json
{
  "id": "grok",
  "name": "Grok Build",
  "description": "Grok Build CLI",
  "detect": { "type": "path", "paths": ["%USERPROFILE%\\.grok\\bin\\grok.exe"] },
  "install": {
    "type": "command",
    "run": "irm https://x.ai/cli/install.ps1 | iex"
  },
  "dependsOn": [],
  "admin": false
}
```

`admin: false` nên một profile chỉ có `grok` không bật UAC. Profile nào trộn với mục `admin: true` thì cả lần chạy đó vẫn cần Administrator.
