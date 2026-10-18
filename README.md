# tqt_working_space

Cài môi trường dev trên Windows. Một lối vào: `setup.bat`. Danh sách phần mềm nằm trong `catalog/`. Runner đọc catalog, bỏ qua mục đã có, rồi cài phần còn lại.

## Chạy

Mở terminal tại thư mục này. Cài đặt sẽ hỏi quyền Administrator.

```bat
setup.bat
setup.bat ide
setup.bat --component windows-terminal
setup.bat --component rust
setup.bat --check
setup.bat --check data
setup.bat --list
```

Trong menu, mục `i` liệt kê từng ứng dụng. Chọn một số để cài đúng ứng dụng đó, gồm Windows Terminal (`windows-terminal`).

Mở một terminal mới sau khi cài để dùng PATH vừa cập nhật.

Kiểm tra code, không cài thêm gì:

```bat
test.bat
```

`test.bat` kết thúc với mã 0 khi catalog và runner đúng. Máy chưa cài hết phần mềm trong catalog vẫn là một lần test đạt.

| Profile | Nội dung |
|---|---|
| `base` | Chocolatey, Git, Python 3.10, uv |
| `python` | Python 3.10, uv |
| `ide` | `base`, VS Code, extension Python |
| `data` | PostgreSQL, Redis, DBeaver |
| `extras` | Rust, Node.js LTS, Firefox, Windows Terminal |
| `apps` | Grok Build, Bitwarden, DeepSeek Harness |
| `full` | Mọi mục trong catalog |

## Thêm một phần mềm

Sửa `catalog/components.json` và gắn id vào profile trong `catalog/profiles.json`. Không tạo file `.bat` mới ở thư mục gốc.

Phần lớn gói Chocolatey chỉ cần một object. Script trong `runner/scripts/` chỉ dùng khi phải kiểm tra hoặc cài theo cách riêng (extension VS Code, shortcut DBeaver, gói MSIX).

Chi tiết từng field: [docs/them-thanh-phan.md](docs/them-thanh-phan.md). Hướng dẫn cho agent: [AGENTS.md](AGENTS.md).

## Bố cục

```text
setup.bat                 Lối vào
test.bat                  Kiểm tra catalog và runner
catalog/components.json   Từng phần mềm
catalog/profiles.json     Bộ cài
runner/Setup-Machine.ps1  Menu, thứ tự cài, log
runner/Lib.ps1            Hàm dùng chung
runner/scripts/           Script cho mục không cài được chỉ bằng một dòng catalog
docs/                     Hướng dẫn
vendor/                   File cài offline, không commit
logs/                     Log mỗi lần chạy, không commit
```

## Biến môi trường

Không bắt buộc. Mẫu nằm ở `.env.example`. Copy thành `.env` khi cần đổi thư mục log, tham số Chocolatey, hoặc tắt `pause`. File `.env` không được commit. Repo này không giữ token hay mật khẩu.

## File cài offline

`vendor/` đang để trống trong git. Hai bộ cài từng nằm ở thư mục gốc được chuyển vào đây trên máy local, và git bỏ qua file `.exe`:

- `python-3.10.9-amd64.exe`
- `VSCodeUserSetup-x64-1.106.3.exe`

Catalog hiện cài Python và VS Code bằng Chocolatey, không gọi hai file này.

## Script cũ

| Trước | Nay |
|---|---|
| `setup_dev_comp.bat` | `setup.bat base` |
| `setup_python.bat` | `setup.bat python` |
| `dev_team_automation/setup_dev_with_IDE.bat` | `setup.bat ide` |
| `install_vscode.bat` | `setup.bat --component vscode,vscode-python` |
| `install_dbeaver.bat` | `setup.bat --component dbeaver` |
| `install_rust.bat` | `setup.bat --component rust` |
| `install_terminal.bat` | `setup.bat --component windows-terminal` |
| `eat_choco/install_postgres_redis.bat` | `setup.bat --component postgres,redis` |
| `eat_choco/software_list.txt` | `node` và `firefox` trong catalog, profile `extras` |
