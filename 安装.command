#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
"$project_root/install.sh" --apply
read -r -p "安装完成，按回车关闭窗口。" _
