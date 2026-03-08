#!/bin/bash

# ============================================
# CamTools IPK 打包脚本
# ============================================
# 注意：此脚本默认为 aarch64_cortex-a53 架构编译
# 如需其他架构，请修改下方 ARCH 变量
# 
# 常见架构：
# - aarch64_cortex-a53
# - aarch64_cortex-a72
# - arm_cortex-a7
# - arm_cortex-a9
# - mipsel_24kc
# - x86_64
# ============================================

# 读取版本号
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_VERSION=$(cat "${SOURCE_DIR}/VERSION" 2>/dev/null | tr -d '\r\n' || echo "1.0.0.0")

# 配置变量
ARCH="aarch64_cortex-a53"  # 目标架构，根据你的设备修改
PKG_NAME="luci-app-camtools"
PKG_RELEASE="1"
WORK_DIR="/tmp/camtools_build"
IPKG_DIR="${WORK_DIR}/ipkg-${PKG_NAME}"

# 清理工作目录
echo "Cleaning work directory..."
rm -rf "${WORK_DIR}"
mkdir -p "${IPKG_DIR}"

# 创建目录结构
echo "Creating directory structure..."
mkdir -p "${IPKG_DIR}/usr/bin"
mkdir -p "${IPKG_DIR}/etc/init.d"
mkdir -p "${IPKG_DIR}/etc/config"
mkdir -p "${IPKG_DIR}/etc/camtools"
mkdir -p "${IPKG_DIR}/usr/lib/lua/luci/controller"
mkdir -p "${IPKG_DIR}/usr/lib/lua/luci/model/cbi/camtools"
mkdir -p "${IPKG_DIR}/usr/lib/lua/luci/view/camtools"
mkdir -p "${IPKG_DIR}/CONTROL"

# 复制文件
echo "Copying files..."

# 主脚本
cp "${SOURCE_DIR}/camtools.sh" "${IPKG_DIR}/usr/bin/"
chmod 755 "${IPKG_DIR}/usr/bin/camtools.sh"

# Init 脚本
cp "${SOURCE_DIR}/files/camtools.init" "${IPKG_DIR}/etc/init.d/camtools"
chmod 755 "${IPKG_DIR}/etc/init.d/camtools"

# 配置文件
cp "${SOURCE_DIR}/files/camtools.config" "${IPKG_DIR}/etc/config/camtools"

# 版本文件
echo "${PKG_VERSION}" > "${IPKG_DIR}/etc/camtools/version"

# LuCI 控制器
cp "${SOURCE_DIR}/luasrc/controller/camtools.lua" \
   "${IPKG_DIR}/usr/lib/lua/luci/controller/"

# LuCI 模型
cp "${SOURCE_DIR}/luasrc/model/cbi/camtools/settings.lua" \
   "${IPKG_DIR}/usr/lib/lua/luci/model/cbi/camtools/"
cp "${SOURCE_DIR}/luasrc/model/cbi/camtools/logs.lua" \
   "${IPKG_DIR}/usr/lib/lua/luci/model/cbi/camtools/"

# LuCI 视图
cp "${SOURCE_DIR}/luasrc/view/camtools/"*.htm \
   "${IPKG_DIR}/usr/lib/lua/luci/view/camtools/"

# 创建 control 文件
echo "Creating control file..."
cat > "${IPKG_DIR}/CONTROL/control" << CONTROL_EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}-${PKG_RELEASE}
Depends: curl, luci-base
Section: luci
Category: LuCI
Architecture: ${ARCH}
Maintainer: CamTools Team
Description: LuCI Support for CamTools_wrt
 LuCI web interface for CamTools - Campus Network Auto Login Tool.
 Automatic campus network authentication service for OpenWrt.
 Monitors network connectivity and automatically authenticates
 with campus network portal when internet access is lost.
 .
 Features:
 - Automatic network connectivity monitoring
 - Auto-login on connection loss
 - LuCI web interface for easy configuration
 - Real-time status monitoring
 - Detailed logging with web viewer
 .
 Pure shell script implementation - no compilation required!
CONTROL_EOF

# 创建 postinst 脚本
echo "Creating postinst script..."
cat > "${IPKG_DIR}/CONTROL/postinst" << 'POSTINST_EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	echo "Enabling camtools service..."
	/etc/init.d/camtools enable
	echo "CamTools installed successfully!"
	echo "Configure via LuCI or edit /etc/config/camtools"
}
exit 0
POSTINST_EOF
chmod 755 "${IPKG_DIR}/CONTROL/postinst"

# 创建 prerm 脚本
echo "Creating prerm script..."
cat > "${IPKG_DIR}/CONTROL/prerm" << 'PRERM_EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	echo "Stopping camtools service..."
	/etc/init.d/camtools stop
	/etc/init.d/camtools disable
}
exit 0
PRERM_EOF
chmod 755 "${IPKG_DIR}/CONTROL/prerm"

# 创建 conffiles
echo "Creating conffiles..."
cat > "${IPKG_DIR}/CONTROL/conffiles" << 'CONFFILES_EOF'
/etc/config/camtools
CONFFILES_EOF

# 打包
echo "Building IPK package..."
cd "${WORK_DIR}"

# 输出目录
OUTPUT_DIR="${SOURCE_DIR}/bin"
mkdir -p "${OUTPUT_DIR}"
OUTPUT_IPK="${OUTPUT_DIR}/luci-app-camtools_${PKG_VERSION}-${PKG_RELEASE}_${ARCH}.ipk"

# 创建 data.tar.gz
cd "${IPKG_DIR}"
tar czf "${WORK_DIR}/data.tar.gz" --exclude=CONTROL .

# 创建 control.tar.gz
cd "${IPKG_DIR}/CONTROL"
tar czf "${WORK_DIR}/control.tar.gz" .

# 创建 debian-binary
echo "2.0" > "${WORK_DIR}/debian-binary"

# 打包成 IPK
cd "${WORK_DIR}"
tar czf "${OUTPUT_IPK}" debian-binary control.tar.gz data.tar.gz

echo ""
echo "✓ IPK package created successfully!"
echo "  Location: ${OUTPUT_IPK}"
ls -lh "${OUTPUT_IPK}"

# 清理
echo ""
echo "Cleaning up..."
rm -rf "${WORK_DIR}"

echo ""
echo "Done! You can install the package with:"
echo "  opkg install ${OUTPUT_IPK}"
