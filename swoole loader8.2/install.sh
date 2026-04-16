#!/bin/bash

echo -e "=========================环境安装助手==========================="

echo ">>> 正在检测环境"

# 自动检测PHP路径，支持多种环境
detect_php_path() {
    # 宝塔面板
    if [ -f "/www/server/php/82/bin/php" ]; then
        echo "/www/server/php/82/bin/php"
        return
    fi
    # 1Panel面板
    if [ -f "/opt/1panel/apps/php/php82/bin/php" ]; then
        echo "/opt/1panel/apps/php/php82/bin/php"
        return
    fi
    # 系统默认PHP
    if command -v php &> /dev/null; then
        echo "$(which php)"
        return
    fi
    echo ""
}

# 检测PHP配置文件路径
detect_php_ini() {
    local php_bin="$1"
    
    # 方法1: 检查宝塔面板的非CLI配置文件（优先级最高）
    if [ -f "/www/server/php/82/etc/php.ini" ]; then
        echo "/www/server/php/82/etc/php.ini"
        return
    fi
    
    # 方法2: 检查1Panel的非CLI配置文件
    if [ -f "/opt/1panel/apps/php/php82/etc/php.ini" ]; then
        echo "/opt/1panel/apps/php/php82/etc/php.ini"
        return
    fi
    
    # 方法3: 通过php-fpm -t获取配置文件路径（FPM模式）
    local fpm_ini=$("$php_bin" -r "echo php_ini_loaded_file();" 2>/dev/null)
    if [ -n "$fpm_ini" ] && [ -f "$fpm_ini" ] && [[ "$fpm_ini" != *"cli"* ]]; then
        echo "$fpm_ini"
        return
    fi
    
    # 方法4: 查找php-fpm配置文件中的php.ini路径
    local fpm_conf="/www/server/php/82/etc/php-fpm.conf"
    if [ -f "$fpm_conf" ]; then
        local fpm_ini_path=$(grep -E "^\s*php_admin_value\[include_path\]|^\s*php_value\[include_path\]" "$fpm_conf" 2>/dev/null | head -1)
        if [ -n "$fpm_ini_path" ]; then
            echo "$fpm_ini_path"
            return
        fi
    fi
    
    # 方法5: 系统标准路径
    if [ -f "/etc/php/8.2/fpm/php.ini" ]; then
        echo "/etc/php/8.2/fpm/php.ini"
        return
    fi
    
    # 方法6: 通过php -i获取配置文件路径（最后的备选方案）
    local ini_path=$("$php_bin" -i 2>/dev/null | grep "Loaded Configuration File" | awk -F' => ' '{print $2}')
    if [ -n "$ini_path" ] && [ -f "$ini_path" ]; then
        # 如果获取到的是cli.ini，尝试替换为php.ini
        if [[ "$ini_path" == *"cli"* ]]; then
            local non_cli_ini="${ini_path//-cli/}"
            if [ -f "$non_cli_ini" ]; then
                echo "$non_cli_ini"
                return
            fi
        fi
        echo "$ini_path"
        return
    fi
    
    echo ""
}

# 检测PHP扩展目录
detect_extension_dir() {
    local php_bin="$1"
    local ext_dir=$("$php_bin" -i 2>/dev/null | grep "extension_dir" | head -1 | awk -F' => ' '{print $2}')
    echo "$ext_dir"
}

# 重启PHP-FPM服务
restart_php_fpm() {
    echo ">>> 尝试重启PHP-FPM服务..."
    local restart_success=0
    
    # 方法1: 宝塔面板
    if [ -f "/etc/init.d/php-fpm-82" ]; then
        echo ">>> 检测到宝塔面板，使用init.d重启"
        /etc/init.d/php-fpm-82 restart && restart_success=1
    fi
    
    # 方法2: systemctl (多种服务名)
    if [ $restart_success -eq 0 ]; then
        for svc in "php-fpm-82" "php82-fpm" "php8.2-fpm" "php-fpm"; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                echo ">>> 使用systemctl重启 $svc"
                systemctl restart "$svc" && restart_success=1
                break
            fi
        done
    fi
    
    # 方法3: service命令
    if [ $restart_success -eq 0 ]; then
        for svc in "php-fpm-82" "php82-fpm" "php8.2-fpm" "php-fpm"; do
            if service "$svc" status &>/dev/null; then
                echo ">>> 使用service重启 $svc"
                service "$svc" restart && restart_success=1
                break
            fi
        done
    fi
    
    # 方法4: 1Panel面板Docker容器
    if [ $restart_success -eq 0 ] && command -v docker &>/dev/null; then
        local php_container=$(docker ps --format '{{.Names}}' | grep -i "php" | head -1)
        if [ -n "$php_container" ]; then
            echo ">>> 检测到Docker容器 $php_container，重启容器"
            docker restart "$php_container" && restart_success=1
        fi
    fi
    
    # 方法5: 发送USR2信号给php-fpm主进程
    if [ $restart_success -eq 0 ]; then
        local fpm_pid=$(pgrep -o "php-fpm: master" 2>/dev/null)
        if [ -n "$fpm_pid" ]; then
            echo ">>> 发送USR2信号重载php-fpm (PID: $fpm_pid)"
            kill -USR2 "$fpm_pid" && restart_success=1
        fi
    fi
    
    # 方法6: 强制重启所有php-fpm进程
    if [ $restart_success -eq 0 ]; then
        if pgrep -x "php-fpm" &>/dev/null; then
            echo ">>> 强制重启php-fpm进程"
            pkill -x "php-fpm"
            sleep 1
            # 尝试启动
            if [ -f "/etc/init.d/php-fpm-82" ]; then
                /etc/init.d/php-fpm-82 start && restart_success=1
            fi
        fi
    fi
    
    if [ $restart_success -eq 1 ]; then
        echo ">>> PHP-FPM重启成功"
    else
        echo ">>> 警告：无法自动重启PHP-FPM，请手动重启"
        echo ">>> 常用命令："
        echo ">>>   宝塔面板: /etc/init.d/php-fpm-82 restart"
        echo ">>>   systemd: systemctl restart php-fpm"
        echo ">>>   service: service php-fpm restart"
    fi
}

# 检测PHP路径
PHP_BIN=$(detect_php_path)
if [ -z "$PHP_BIN" ]; then
    echo ">>> 错误：未找到PHP 8.2，请确保已安装PHP 8.2"
    exit 1
fi
echo ">>> 检测到PHP路径: $PHP_BIN"

# 获取PHP信息
$PHP_BIN -i > phpinfo.txt

# 检查phpinfo输出中是否包含线程安全性信息
if grep -q "Thread Safety => enabled" phpinfo.txt; then
    echo ">>> 当前环境：PHP 8.2 环境是 Thread Safe (TS)"
    source_file="/file/linux/zts/swoole_loader.so"
elif grep -q "Thread Safety => disabled" phpinfo.txt; then
    echo ">>> 当前环境：PHP 8.2 环境是 Non-Thread Safe (NTS)"
    source_file="/file/linux/nts/swoole_loader.so"
else
    echo ">>> 当前环境：无法确定 PHP 8.2 环境类型"
    rm -f phpinfo.txt
    exit 1
fi

# 删除临时文件
rm -f phpinfo.txt

# 检测PHP扩展目录
ext_dir=$(detect_extension_dir "$PHP_BIN")
if [ -z "$ext_dir" ]; then
    echo ">>> 错误：无法检测PHP扩展目录"
    exit 1
fi
extension_dir="${ext_dir}/swoole_loader.so"
echo ">>> 扩展目录: $ext_dir"

# 检测PHP配置文件路径
php_ini=$(detect_php_ini "$PHP_BIN")
if [ -z "$php_ini" ]; then
    echo ">>> 错误：无法检测php.ini路径"
    exit 1
fi
echo ">>> 配置文件: $php_ini"

# 定义要添加的扩展
extension="extension = swoole_loader.so"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查目标目录是否存在swoole_loader.so文件，如果不存在则复制
if [ ! -f "$extension_dir" ]; then
    cp "${script_dir}${source_file}" "$extension_dir"
    echo ">>> swoole_loader扩展安装成功"
else
    echo ">>> swoole_loader扩展存在，跳过安装"
fi

# 检查是否已在php.ini中添加了扩展
if ! grep -q "$extension" "$php_ini"; then
    echo "$extension" >> "$php_ini"
fi

# 删除禁用的函数
sudo sed -i '/disable_functions/s/\(exec,\)\?\(exec\)//' "$php_ini"

# 重启PHP-FPM
restart_php_fpm
echo ""
echo ">>> 环境安装成功，您可以继续安装程序了！"
echo ""
