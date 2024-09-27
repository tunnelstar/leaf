#!/bin/bash

# 获取脚本的绝对路径
script_path=$(realpath "$0")

# 设置 directory 为脚本所在目录的上级目录
directory=$(dirname "$(dirname "$script_path")")

# 获取脚本文件的名称
script_name=$(basename "$script_path")

# 改名后的目标
target="mosshal"

echo "The working directory (parent of the script directory) is: $directory"

# 切换到工作目录
cd "$directory" || { echo "Failed to change to directory $directory"; exit 1; }

# 询问用户确认
echo "This script will replace 'leaf' with '$target' in all file names and file contents under $directory"
echo "Excluding this script file ($script_name) and .git directory"
read -p "Do you want to continue? (y/n): " confirm

if [[ $confirm != [Yy]* ]]; then
    echo "Operation cancelled."
    exit 1
fi

# 函数：替换文件内容
replace_content() {
    local file="$1"
    if [ -f "$file" ] && [ ! -L "$file" ]; then
        awk -v target="$target" '{gsub(/leaf/, target)}1' "$file" > tmp && mv tmp "$file"
        echo "Content replaced in: $file"
    fi
}

# 使用 find 命令查找目录中的所有文件名包含 "leaf" 的文件
# 使用 mv 命令将文件名中的 "leaf" 替换为 $target
find . -path "./.git" -prune -o -depth -name "*leaf*" -not -name "$script_name" -print0 | while IFS= read -r -d '' file; do
    newfile=$(echo "$file" | sed "s/leaf/$target/g")
    if [ "$file" != "$newfile" ]; then
        if mv "$file" "$newfile"; then
            echo "Renamed: $file -> $newfile"
            replace_content "$newfile"
        else
            echo "Failed to rename: $file"
        fi
    else
        replace_content "$file"
    fi
done

# 处理不包含 "leaf" 在文件名中的文件
find . -path "./.git" -prune -o -type f -not -name "*leaf*" -not -name "$script_name" -print0 | while IFS= read -r -d '' file; do
    replace_content "$file"
done

echo "Operation completed."