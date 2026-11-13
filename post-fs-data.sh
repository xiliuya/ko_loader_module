#!/system/bin/sh
MODDIR=${0%/*}

# 1. 动态加载内核模块 (.ko)
sh "$MODDIR/mod_ins.sh" "$MODDIR/module_files"

# 2. 挂载文件到指定路径 (Bind Mount)
TARGET_PATH="/vendor/lib/modules/qca_cld3_wlan.ko"
SOURCE_FILE="$MODDIR/module_files/wlan.ko"

if [ -f "$SOURCE_FILE" ] && [ -f "$TARGET_PATH" ]; then

	# 步骤拆解：先执行 insmod 并捕获所有的标准错误与输出
	INSMOD_OUTPUT=$(insmod "$SOURCE_FILE" 2>&1)
	INSMOD_STATUS=$?

	# 打印出具体的加载结果，方便你调试看日志
	echo "$INSMOD_OUTPUT"

	# 判断：如果退出码不为 0，或者输出中包含了 "Exec" 错误
	if [ $INSMOD_STATUS -ne 0 ] || echo "$INSMOD_OUTPUT" | grep -q "Exec"; then
		echo "检测到 insmod 失败或出现格式错误，跳过 bind mount。"
	else
		# 只有在 insmod 完全成功时，才执行挂载
		umount "$TARGET_PATH" 2>/dev/null
		mount -o bind "$SOURCE_FILE" "$TARGET_PATH"
		echo "insmod 成功，已完成 bind mount。"
	fi

fi
