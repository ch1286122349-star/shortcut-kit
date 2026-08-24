#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")" && pwd)"
"$project_root/uninstall.sh" --apply
read -r -p "卸载完成，按回车关闭窗口。" _
