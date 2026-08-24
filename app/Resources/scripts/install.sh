#!/bin/bash
set -euo pipefail
resource_root="$(cd "$(dirname "$0")/.." && pwd)"
exec "$resource_root/install.sh" "$@"
