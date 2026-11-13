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

	# 【修改这里】：使用 && 确保“退出码不为 0”与“包含 Exec”同时成立时才跳过
	if [ $INSMOD_STATUS -ne 0 ] && echo "$INSMOD_OUTPUT" | grep -q "Exec"; then
		echo "检测到 insmod 失败且为格式错误 (Exec)，跳过 bind mount。"
	else
		# 只要不同时满足（例如模块已加载导致的非 0 退出），照常执行挂载
		umount "$TARGET_PATH" 2>/dev/null
		mount -o bind "$SOURCE_FILE" "$TARGET_PATH"
		if [ $? -eq 0 ]; then
			echo "insmod 处理完成，已成功完成 bind mount。"
		else
			echo "Bind mount 执行失败，请检查挂载点权限。"
		fi
	fi

fi
