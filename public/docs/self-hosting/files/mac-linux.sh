#!/bin/bash

# 信任自签证书脚本 (macOS/Linux)
# 用法:
#   ./trust-cert.sh <URL>                 # 默认 auto：先 HTTP 拉取，再 TLS 抓取
#   ./trust-cert.sh --mode http <URL>     # 强制从 http://$HOST:32000/ssl/ca.crt 获取
#   ./trust-cert.sh --mode tls <URL>      # 强制用 openssl s_client 抓取服务端证书
#
# 例如:
#   ./trust-cert.sh https://192.168.10.70.nip.io/
#   ./trust-cert.sh --mode http https://192.168.10.70.nip.io/
#   ./trust-cert.sh --mode tls https://192.168.10.70.nip.io:8443/

set -e

MODE="auto"

# 简单参数解析：支持 --mode <auto|http|tls>
if [ "$1" = "--mode" ]; then
  if [ -z "$2" ]; then
    echo "错误: --mode 需要一个参数(auto|http|tls)"
    exit 1
  fi
  MODE="$2"
  shift 2
fi

if [ -z "$1" ]; then
    echo "用法: $0 [--mode auto|http|tls] <URL>"
    echo "例如: $0 https://192.168.10.70.nip.io/"
    exit 1
fi

URL="$1"

# 从 URL 提取主机和端口
HOST=$(echo "$URL" | sed -E 's|https?://([^/:]+).*|\1|')
PORT=$(echo "$URL" | sed -E 's|https?://[^:]+:([0-9]+).*|\1|')
if [ "$PORT" = "$URL" ] || [ -z "$PORT" ]; then
    PORT=443
fi

CERT_FILE="/tmp/${HOST}.crt"

download_cert_http() {
  local http_url="http://${HOST}:32000/ssl/ca.crt"
  echo "尝试 HTTP 拉取证书: $http_url"

  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$CERT_FILE" "$http_url" || return 1
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$http_url" -o "$CERT_FILE" || return 1
  else
    echo "错误: 未找到 wget 或 curl，无法通过 HTTP 拉取证书"
    return 1
  fi

  [ -s "$CERT_FILE" ] || return 1
  return 0
}

download_cert_tls() {
  echo "使用 TLS 握手抓取证书: ${HOST}:${PORT}"
  # 注意：这里抓到的是“服务器当前返回的证书”（可能是 leaf）
  echo | openssl s_client -servername "$HOST" -connect "${HOST}:${PORT}" 2>/dev/null | \
      openssl x509 -outform PEM > "$CERT_FILE"

  [ -s "$CERT_FILE" ] || return 1
  return 0
}

echo "=========================================="
echo "自签证书信任工具"
echo "=========================================="
echo "目标地址: $URL"
echo "主机: $HOST"
echo "端口: $PORT"
echo "模式: $MODE (auto/http/tls)"
echo ""

echo "[1/3] 正在下载证书..."

case "$MODE" in
  http)
    if ! download_cert_http; then
      echo "错误: HTTP 拉取证书失败"
      exit 1
    fi
    ;;
  tls)
    if ! download_cert_tls; then
      echo "错误: TLS 抓取证书失败，请检查地址是否正确"
      exit 1
    fi
    ;;
  auto)
    # 先 HTTP，失败再 TLS
    if download_cert_http; then
      echo "✅ 已通过 HTTP 拉取证书"
    else
      echo "HTTP 拉取失败，改用 TLS 抓取..."
      if ! download_cert_tls; then
        echo "错误: HTTP 和 TLS 两种方式都获取证书失败，请检查地址是否正确"
        exit 1
      fi
      echo "✅ 已通过 TLS 抓取证书"
    fi
    ;;
  *)
    echo "错误: 不支持的模式: $MODE (仅支持 auto/http/tls)"
    exit 1
    ;;
esac

echo "证书已保存到: $CERT_FILE"
echo ""

# 显示证书信息
echo "[2/3] 证书信息:"
echo "-------------------------------------------"
openssl x509 -in "$CERT_FILE" -noout -subject -issuer -dates || {
  echo "警告: 证书解析失败（文件可能不是 PEM 格式的 X509 证书）"
  echo "你可以检查文件内容：head -n 5 $CERT_FILE"
  exit 1
}
echo "-------------------------------------------"
echo ""

# 根据操作系统安装证书
echo "[3/3] 正在安装证书到系统信任存储..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "检测到 macOS 系统"
    echo "需要管理员权限来添加证书到系统钥匙串..."
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_FILE"
    echo ""
    echo "✅ 证书已成功添加到 macOS 系统钥匙串！"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "检测到 Linux 系统"

    if [ -d "/usr/local/share/ca-certificates" ]; then
        sudo cp "$CERT_FILE" "/usr/local/share/ca-certificates/${HOST}.crt"
        sudo update-ca-certificates
    elif [ -d "/etc/pki/ca-trust/source/anchors" ]; then
        sudo cp "$CERT_FILE" "/etc/pki/ca-trust/source/anchors/${HOST}.crt"
        sudo update-ca-trust
    else
        echo "警告: 未识别的 Linux 发行版，请手动安装证书"
        echo "证书文件位置: $CERT_FILE"
        exit 1
    fi
    echo ""
    echo "✅ 证书已成功添加到 Linux 系统信任存储！"
else
    echo "不支持的操作系统: $OSTYPE"
    exit 1
fi

echo ""
echo "=========================================="
echo "完成！"
echo "注意: 某些应用程序可能需要重启才能识别新证书"
echo "=========================================="

