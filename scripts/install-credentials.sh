#!/usr/bin/env bash
# 把本地填好的 Moonshot Key 装进已安装 App 的沙盒：Application Support/moonshot-key.json。
# 用法：scripts/install-credentials.sh [模拟器名或UDID，默认 booted]
# 真机装不了（沙盒拿不到），真机的 Keychain 入口在模块 6 的设置页。
set -euo pipefail

bundle_id="com.fi2zz.replo"
source_file="secrets/moonshot-key.json"
destination_name="moonshot-key.json"

if [[ ! -f "$source_file" ]]; then
  echo "缺少 $source_file" >&2
  echo "先 cp secrets/moonshot-key.example.json $source_file 并填入 KIMI_API_KEY" >&2
  exit 1
fi

container="$(xcrun simctl get_app_container "${1:-booted}" "$bundle_id" data)"
support="$container/Library/Application Support"
mkdir -p "$support"
install -m 600 "$source_file" "$support/$destination_name"
echo "已安装：$support/$destination_name"
echo "重启 App，「教练」页状态应为「已就绪」。"
