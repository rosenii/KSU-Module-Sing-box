
#!/system/bin/sh

MODPATH="${MODPATH:-/data/adb/modules/singbox_ebpf_ui}"
BOX_SRC="$MODPATH/Box"
BOX_DST="/data/adb/Box"

ui_print "正在安装 Box 运行目录..."

if [ -d "$BOX_SRC" ]; then
    mkdir -p "$BOX_DST" || abort "无法创建 $BOX_DST"

    # 复制 Box 内容到实际运行目录，保留已有文件
    cp -af "$BOX_SRC/." "$BOX_DST/" || abort "复制 Box 目录失败"

    # 统一设置目录及文件权限
    chmod -R 755 "$BOX_DST" || abort "设置 Box 权限失败"

    # 删除模块目录中的副本，避免重复存储
    rm -rf "$BOX_SRC" || abort "删除模块内 Box 目录失败"

    ui_print "Box 已部署到 $BOX_DST"
else
    ui_print "模块内没有 Box 目录，跳过部署"
fi
