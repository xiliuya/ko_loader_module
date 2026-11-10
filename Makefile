# ==============================================================================
# Magisk Module Makefile
# ==============================================================================

MODULE_NAME = kernel_ko_loader_module
BUILD_DIR = build
ZIP_OUTPUT = $(MODULE_NAME).zip
TARGET_SCRIPT = mod_ins.sh

# 核心源码依赖（注意：这里不包含生成的 mod_ins.sh）
REQUIRED_FILES = module.prop post-fs-data.sh gen_insmod_order.py modules.dep modules.blocklist META-INF

.PHONY: all clean check generate zip

all: clean check generate zip
	@echo "===> 模块打包成功！输出文件: $(ZIP_OUTPUT)"

# 1. 清理旧的构建产物（包含动态生成的 mod_ins.sh）
clean:
	@echo "===> 清理旧的构建文件及生成产物..."
	@rm -f $(ZIP_OUTPUT) $(TARGET_SCRIPT)
	@rm -rf $(BUILD_DIR)

# 2. 检查必要源码文件是否存在
check:
	@echo "===> 检查项目结构..."
	@for file in $(REQUIRED_FILES); do \
		if [ ! -e "$$file" ]; then \
			echo "错误: 缺少必要的源文件: $$file"; \
			exit 1; \
		fi; \
	done
	@echo "===> 检查通过。"

# 3. 动态生成 mod_ins.sh
generate:
	@echo "===> 正在根据依赖关系动态生成 $(TARGET_SCRIPT)..."
	python3 gen_insmod_order.py modules.dep modules.blocklist /debug_ramdisk > $(TARGET_SCRIPT)
	@echo "===> $(TARGET_SCRIPT) 生成完毕。"

# 4. 赋予权限并打包
zip: generate
	@echo "===> 正在赋予 shell 脚本可执行权限..."
	@chmod +x post-fs-data.sh $(TARGET_SCRIPT) 2>/dev/null || true
	
	@echo "===> 正在打包 Magisk 模块..."
	@mkdir -p $(BUILD_DIR)
	# 将生成的 mod_ins.sh 以及其他必要文件打包，排除源码及开发辅助文件
	@zip -r $(ZIP_OUTPUT) module.prop post-fs-data.sh $(TARGET_SCRIPT) META-INF module_files \
		-x "Makefile" -x "gen_insmod_order.py" -x "modules.dep" -x "modules.blocklist" -x "*.DS_Store" "*~" > /dev/null
	@echo "===> 打包完成！"
