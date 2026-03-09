#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
============================================
CamTools IPK 打包脚本 (Windows/Linux/macOS)
============================================
注意：此脚本默认为 aarch64_cortex-a53 架构编译
如需其他架构，请修改下方 ARCH 变量

常见架构：
- aarch64_cortex-a53
- aarch64_cortex-a72
- arm_cortex-a7
- arm_cortex-a9
- mipsel_24kc
- x86_64
============================================
"""

import os
import sys
import shutil
import tarfile
import tempfile
from pathlib import Path

# 配置变量
ARCH = "aarch64_cortex-a53"  # 目标架构，根据你的设备修改
PKG_NAME = "luci-app-camtools"
PKG_RELEASE = "1"


def read_version(source_dir):
    """读取版本号"""
    version_file = source_dir / "VERSION"
    try:
        with open(version_file, 'r', encoding='utf-8') as f:
            version = f.read().strip()
            return version if version else "1.0.0.0"
    except Exception as e:
        print(f"Warning: Could not read VERSION file: {e}")
        return "1.0.0.0"


def create_directory_structure(ipkg_dir):
    """创建目录结构"""
    print("Creating directory structure...")
    dirs = [
        "usr/bin",
        "etc/init.d",
        "etc/config",
        "etc/camtools",
        "usr/lib/lua/luci/controller",
        "usr/lib/lua/luci/model/cbi/camtools",
        "usr/lib/lua/luci/view/camtools",
        "CONTROL"
    ]
    for d in dirs:
        (ipkg_dir / d).mkdir(parents=True, exist_ok=True)


def copy_files(source_dir, ipkg_dir, pkg_version):
    """复制文件"""
    print("Copying files...")
    
    # 主脚本
    shutil.copy2(source_dir / "camtools.sh", ipkg_dir / "usr/bin/camtools.sh")
    (ipkg_dir / "usr/bin/camtools.sh").chmod(0o755)
    
    # Init 脚本
    shutil.copy2(source_dir / "files/camtools.init", ipkg_dir / "etc/init.d/camtools")
    (ipkg_dir / "etc/init.d/camtools").chmod(0o755)
    
    # 配置文件
    shutil.copy2(source_dir / "files/camtools.config", ipkg_dir / "etc/config/camtools")
    
    # 版本文件
    with open(ipkg_dir / "etc/camtools/version", 'w', encoding='utf-8') as f:
        f.write(pkg_version)
    
    # LuCI 控制器
    shutil.copy2(
        source_dir / "luasrc/controller/camtools.lua",
        ipkg_dir / "usr/lib/lua/luci/controller/camtools.lua"
    )
    
    # LuCI 模型
    shutil.copy2(
        source_dir / "luasrc/model/cbi/camtools/settings.lua",
        ipkg_dir / "usr/lib/lua/luci/model/cbi/camtools/settings.lua"
    )
    shutil.copy2(
        source_dir / "luasrc/model/cbi/camtools/logs.lua",
        ipkg_dir / "usr/lib/lua/luci/model/cbi/camtools/logs.lua"
    )
    
    # LuCI 视图
    view_dir = source_dir / "luasrc/view/camtools"
    for htm_file in view_dir.glob("*.htm"):
        shutil.copy2(htm_file, ipkg_dir / "usr/lib/lua/luci/view/camtools" / htm_file.name)


def create_control_file(ipkg_dir, pkg_version):
    """创建 control 文件"""
    print("Creating control file...")
    control_content = f"""Package: {PKG_NAME}
Version: {pkg_version}-{PKG_RELEASE}
Depends: curl, luci-base
Section: luci
Category: LuCI
Architecture: {ARCH}
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
"""
    with open(ipkg_dir / "CONTROL/control", 'w', encoding='utf-8', newline='\n') as f:
        f.write(control_content)


def create_postinst_script(ipkg_dir):
    """创建 postinst 脚本"""
    print("Creating postinst script...")
    postinst_content = """#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	echo "Enabling camtools service..."
	/etc/init.d/camtools enable
	echo "CamTools installed successfully!"
	echo "Configure via LuCI or edit /etc/config/camtools"
}
exit 0
"""
    postinst_file = ipkg_dir / "CONTROL/postinst"
    with open(postinst_file, 'w', encoding='utf-8', newline='\n') as f:
        f.write(postinst_content)
    # 设置执行权限
    postinst_file.chmod(0o755)


def create_prerm_script(ipkg_dir):
    """创建 prerm 脚本"""
    print("Creating prerm script...")
    prerm_content = """#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	echo "Stopping camtools service..."
	/etc/init.d/camtools stop
	/etc/init.d/camtools disable
}
exit 0
"""
    prerm_file = ipkg_dir / "CONTROL/prerm"
    with open(prerm_file, 'w', encoding='utf-8', newline='\n') as f:
        f.write(prerm_content)
    # 设置执行权限
    prerm_file.chmod(0o755)


def create_conffiles(ipkg_dir):
    """创建 conffiles"""
    print("Creating conffiles...")
    conffiles_content = "/etc/config/camtools\n"
    with open(ipkg_dir / "CONTROL/conffiles", 'w', encoding='utf-8', newline='\n') as f:
        f.write(conffiles_content)


def create_tar_gz(source_dir, output_file, exclude_dirs=None):
    """创建 tar.gz 压缩包（使用 GNU tar 格式兼容 opkg）"""
    with tarfile.open(output_file, 'w:gz', format=tarfile.GNU_FORMAT) as tar:
        # 先添加所有目录
        for item in sorted(source_dir.rglob('*')):
            if item.is_dir():
                # 检查是否需要排除
                if exclude_dirs:
                    skip = False
                    for exclude in exclude_dirs:
                        if exclude in item.parts:
                            skip = True
                            break
                    if skip:
                        continue
                
                # 计算相对路径并添加目录
                arcname = item.relative_to(source_dir)
                tarinfo = tar.gettarinfo(item, arcname=str(arcname))
                tarinfo.mode = 0o755
                tarinfo.uid = 0
                tarinfo.gid = 0
                tar.addfile(tarinfo)
        
        # 再添加所有文件
        for item in sorted(source_dir.rglob('*')):
            if item.is_file():
                # 检查是否需要排除
                if exclude_dirs:
                    skip = False
                    for exclude in exclude_dirs:
                        if exclude in item.parts:
                            skip = True
                            break
                    if skip:
                        continue
                
                # 计算相对路径
                arcname = item.relative_to(source_dir)
                tarinfo = tar.gettarinfo(item, arcname=str(arcname))
                
                # 设置权限
                # CONTROL 目录中的 postinst, prerm, postrm 等脚本需要执行权限
                # init.d 目录中的脚本需要执行权限
                # usr/bin 目录中的脚本需要执行权限
                filename = item.name
                parent_name = item.parent.name
                
                if filename in ['postinst', 'prerm', 'postrm', 'preinst']:
                    # CONTROL 脚本
                    tarinfo.mode = 0o755
                elif parent_name == 'init.d' or parent_name == 'bin':
                    # init 脚本和可执行文件
                    tarinfo.mode = 0o755
                elif item.suffix == '.sh':
                    # shell 脚本
                    tarinfo.mode = 0o755
                elif item.stat().st_mode & 0o111:
                    # 其他有执行权限的文件
                    tarinfo.mode = 0o755
                else:
                    # 普通文件
                    tarinfo.mode = 0o644
                
                tarinfo.uid = 0
                tarinfo.gid = 0
                
                with open(item, 'rb') as f:
                    tar.addfile(tarinfo, f)


def build_ipk(source_dir, work_dir, ipkg_dir, pkg_version):
    """打包 IPK"""
    print("Building IPK package...")
    
    # 创建输出目录
    output_dir = source_dir / "bin"
    output_dir.mkdir(exist_ok=True)
    output_ipk = output_dir / f"luci-app-camtools_{pkg_version}-{PKG_RELEASE}_{ARCH}.ipk"
    
    # 创建 data.tar.gz (排除 CONTROL 目录)
    data_tar = work_dir / "data.tar.gz"
    print("  Creating data.tar.gz...")
    create_tar_gz(ipkg_dir, data_tar, exclude_dirs=['CONTROL'])
    
    # 创建 control.tar.gz
    control_tar = work_dir / "control.tar.gz"
    print("  Creating control.tar.gz...")
    create_tar_gz(ipkg_dir / "CONTROL", control_tar)
    
    # 创建 debian-binary
    debian_binary = work_dir / "debian-binary"
    with open(debian_binary, 'w', encoding='utf-8') as f:
        f.write("2.0\n")
    
    # 打包成 IPK
    print("  Creating final IPK...")
    with tarfile.open(output_ipk, 'w:gz', format=tarfile.GNU_FORMAT) as tar:
        tar.add(debian_binary, arcname="debian-binary")
        tar.add(control_tar, arcname="control.tar.gz")
        tar.add(data_tar, arcname="data.tar.gz")
    
    return output_ipk


def main():
    """主函数"""
    print("=" * 50)
    print("CamTools IPK 打包脚本")
    print("=" * 50)
    print()
    
    # 获取源代码目录
    source_dir = Path(__file__).parent.resolve()
    print(f"Source directory: {source_dir}")
    
    # 读取版本号
    pkg_version = read_version(source_dir)
    print(f"Package version: {pkg_version}")
    print(f"Architecture: {ARCH}")
    print()
    
    # 清理旧的 IPK 文件
    output_dir = source_dir / "bin"
    if output_dir.exists():
        print("Cleaning old IPK files...")
        for old_ipk in output_dir.glob("luci-app-camtools_*.ipk"):
            print(f"  Removing: {old_ipk.name}")
            old_ipk.unlink()
        print()
    
    # 创建临时工作目录
    with tempfile.TemporaryDirectory(prefix='camtools_build_') as temp_dir:
        work_dir = Path(temp_dir)
        ipkg_dir = work_dir / f"ipkg-{PKG_NAME}"
        
        print(f"Work directory: {work_dir}")
        print()
        
        # 创建目录结构
        create_directory_structure(ipkg_dir)
        
        # 复制文件
        copy_files(source_dir, ipkg_dir, pkg_version)
        
        # 创建控制文件
        create_control_file(ipkg_dir, pkg_version)
        create_postinst_script(ipkg_dir)
        create_prerm_script(ipkg_dir)
        create_conffiles(ipkg_dir)
        
        # 打包
        output_ipk = build_ipk(source_dir, work_dir, ipkg_dir, pkg_version)
        
        # 显示结果
        print()
        print("✓ IPK package created successfully!")
        print(f"  Location: {output_ipk}")
        
        # 显示文件大小
        size_kb = output_ipk.stat().st_size / 1024
        print(f"  Size: {size_kb:.1f} KB")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nBuild cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nError: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
