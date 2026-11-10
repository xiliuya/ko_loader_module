#!/usr/init/env python3
import os
import sys

def parse_blocklist(blocklist_path):
    """解析 blocklist 配置文件，提取所有禁用的模块名"""
    blocklist = set()
    if not os.path.exists(blocklist_path):
        print(f"提示: 未找到 blocklist 文件 ({blocklist_path})，将不进行黑名单过滤。", file=sys.stderr)
        return blocklist
    with open(blocklist_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if len(parts) >= 2 and parts[0] == 'blocklist':
                mod_name = parts[1].strip()
                if mod_name.endswith('.ko'):
                    mod_name = mod_name[:-3]
                blocklist.add(mod_name.replace('-', '_'))
    print(f"===> 已加载 {len(blocklist)} 个黑名单模块", file=sys.stderr)
    return blocklist

def parse_modules_dep(dep_file_path, blocklist):
    """解析 modules.dep，同时过滤掉黑名单中的模块"""
    dependency_graph = {}
    all_modules = set()
    filtered_count = 0
    if not os.path.exists(dep_file_path):
        print(f"错误: 找不到 modules.dep 文件: {dep_file_path}", file=sys.stderr)
        sys.exit(1)
    with open(dep_file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                        
            parts = line.split(':')
            if len(parts) < 2:
                continue
                        
            target = parts[0].strip()
            target_name = os.path.basename(target)
            target_base = target_name[:-3] if target_name.endswith('.ko') else target_name
            target_clean = target_base.replace('-', '_')
                        
            if target_clean in blocklist:
                filtered_count += 1
                continue
                        
            deps = parts[1].strip().split()
            dep_names = []
            for d in deps:
                d_name = os.path.basename(d)
                d_base = d_name[:-3] if d_name.endswith('.ko') else d_name
                d_clean = d_base.replace('-', '_')
                                    
                if d_clean in blocklist:
                    continue
                dep_names.append(d_name)
                        
            all_modules.add(target_name)
            dependency_graph[target_name] = dep_names
            
    print(f"===> 已过滤掉 {filtered_count} 个黑名单模块", file=sys.stderr)
    return dependency_graph, all_modules

def topological_sort(graph, all_modules):
    """
    带权重引导的正向拓扑排序：
    确保高通核心基底模块拥有最高优先级，强制在最前方加载。
    """
    core_prio_mapping = {
        "native_dlkm.ko": 1,
        "platform_dlkm.ko": 2,
        "machine_dlkm.ko": 3,
        "q6_dlkm.ko": 4,
        "apr_dlkm.ko": 5,
        "pinctrl_lpi_dlkm.ko": 6,
        "wcd_core_dlkm.ko": 7,
    }

    adj = {m: [] for m in all_modules}
    in_degree = {m: 0 for m in all_modules}
    
    for target, deps in graph.items():
        for dep in deps:
            if dep not in all_modules:
                continue
            adj[dep].append(target)
            in_degree[target] += 1
            
    queue = [m for m in all_modules if in_degree[m] == 0]
    sorted_modules = []
    
    while queue:
        queue.sort(key=lambda x: (core_prio_mapping.get(x, 999), x))
        current = queue.pop(0)
        sorted_modules.append(current)
        for neighbor in adj[current]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)
                
    if len(sorted_modules) != len(all_modules):
        print("警告: 检测到循环依赖，将追加剩余模块...", file=sys.stderr)
        remaining = [m for m in all_modules if m not in sorted_modules]
        sorted_modules.extend(remaining)
        
    return sorted_modules

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python3 gen_clean_insmod_script.py <modules.dep路径> <blocklist路径>")
        sys.exit(1)
        
    dep_file = sys.argv[1]
    blocklist_file = sys.argv[2]

    blocked_set = parse_blocklist(blocklist_file)
    graph, all_mods = parse_modules_dep(dep_file, blocked_set)
    order = topological_sort(graph, all_mods)
    print(f"===> 已加载 {len(order)} 个模块", file=sys.stderr)

    print("#!/system/bin/sh")
    print("#=============================================================================")
    print("# 自动生成的带黑名单过滤、核心基底优先串行加载及内核日志上报的脚本")
    print("#=============================================================================\n")
    
    # 修改这里：生成的脚本支持动态传参及默认路径兜底
    print("""MOD_DIR="$1"
if [ -z "$MOD_DIR" ]; then
    MOD_DIR="${0%/*}/module_files"
    echo "<4>ModScript: 提示: 未指定路径，已自动使用默认路径: $MOD_DIR" > /dev/kmsg
fi""")
    
    blocked_str = " ".join(sorted(blocked_set))
    modules_str = " ".join(order)
    
    print(f'BLOCKLIST="{blocked_str}"')
    print(f'MODULES="{modules_str}"\n')
    
    print("""# 遍历模块列表，采用严格的串行顺序依次加载，并将状态写入内核 /dev/kmsg
for mod in ${MODULES}; do
    target_path="$MOD_DIR/$mod"
    if [ ! -f "$target_path" ]; then
        echo "<4>ModScript: 警告: 找不到模块文件 $target_path，跳过..." > /dev/kmsg
        continue
    fi
    
    # 如果该模块已经加载过，直接跳过，避免 File exists 干扰
    mod_name=$(basename "$mod" .ko)
    if [ -d "/sys/module/$mod_name" ]; then
        echo "<6>ModScript: Module $mod already loaded, skipping." > /dev/kmsg
        continue
    fi
    
    if insmod "$target_path"; then
        echo "<6>ModScript: Successfully loaded module $mod" > /dev/kmsg
    else
        ret=$?
        echo "<3>ModScript: Error: Failed to load module $mod (ret=$ret)" > /dev/kmsg
    fi
done

echo "<6>ModScript: 所有模块加载完毕。" > /dev/kmsg
""")
