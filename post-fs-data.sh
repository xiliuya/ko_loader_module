#!/system/bin/sh
MODDIR=${0%/*}

# 1. 动态加载内核模块 (.ko)
sh "$MODDIR/mod_ins.sh" "$MODDIR/module_files"

# 2. 挂载文件到指定路径 (Bind Mount)
# 语法：mount -o bind <源文件> <目标挂载路径>
TARGET_PATH="/vendor/lib/modules/qca_cld3_wlan.ko"
SOURCE_FILE="$MODDIR/module_files/wlan.ko"

if [ -f "$SOURCE_FILE" ] && [ -f "$TARGET_PATH" ]; then
	# 执行 insmod 并捕获标准错误，判断是否包含 "Exec" 错误
	# 如果 grep 没有匹配到 "Exec"（即没有发生该类错误），则进入条件内部执行挂载
	if ! insmod "$SOURCE_FILE" 2>&1 | grep -q "Exec"; then
		# 先解除可能存在的冲突，再执行绑定挂载
		umount "$TARGET_PATH" 2>/dev/null
		mount -o bind "$SOURCE_FILE" "$TARGET_PATH"
	else
		echo "insmod 出现 Exec 格式错误，跳过 bind mount"
	fi
fi
