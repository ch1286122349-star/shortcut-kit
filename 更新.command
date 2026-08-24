#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
"$project_root/update.sh" --apply --skip-hammerspoon
read -r -p "更新完成，按回车关闭窗口。" _
