#!/bin/bash

# ST8-M 安装脚本
# 功能：安装st8m命令行工具到系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
ST8M_REPO="https://github.com/Archie-Z/st8m.git"
PROJECT_ROOT="$HOME/Projects/st8m"
BIN_DIR="$HOME/.local/bin"
ST8M_BIN="$BIN_DIR/st8m"
SHELL_CONFIGS=("$HOME/.zshrc" "$HOME/.bashrc")

echo -e "${BLUE}=== ST8-M 安装程序 ===${NC}"

# 检查项目是否存在
if [ ! -d "$PROJECT_ROOT" ]; then
    echo -e "${YELLOW}未找到本地项目，正在从GitHub克隆...${NC}"
    mkdir -p "$(dirname "$PROJECT_ROOT")"
    git clone "$ST8M_REPO" "$PROJECT_ROOT"
    echo -e "${GREEN}项目克隆完成${NC}"
fi

# 创建bin目录
echo -e "${BLUE}创建本地bin目录: $BIN_DIR${NC}"
mkdir -p "$BIN_DIR"

# 添加到PATH（对zsh和bash都添加）
echo -e "${BLUE}配置PATH环境变量...${NC}"
for config in "${SHELL_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        # 检查是否已存在
        if ! grep -q "$BIN_DIR" "$config"; then
            echo "" >> "$config"
            echo "# ST8-M CLI工具路径" >> "$config"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$config"
            echo -e "${GREEN}已添加到 $(basename "$config")${NC}"
        else
            echo -e "${YELLOW}PATH已存在于 $(basename "$config")${NC}"
        fi
    fi
done

# 生成st8m主脚本
echo -e "${BLUE}生成st8m命令行工具...${NC}"

cat > "$ST8M_BIN" << 'EOF'
#!/bin/bash

# ST8-M CLI Tool
# 个人博客管理系统命令行工具
# 兼容zsh和bash

set -e

# 版本信息
VERSION="1.0.0"
PROJECT_ROOT="$HOME/Projects/st8m"
CONTENT_DIR="$PROJECT_ROOT/src/content"
EDITOR="${EDITOR:-code}"  # 默认使用VSCode作为编辑器

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 语言配置
LANGS=("zh-cn" "en" "ja")
DEFAULT_LANG="zh-cn"

# 辅助函数
print_error() {
    echo -e "${RED}错误: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}警告: $1${NC}"
}

# 检查项目是否存在
check_project() {
    if [ ! -d "$PROJECT_ROOT" ]; then
        print_error "未找到项目目录: $PROJECT_ROOT"
        echo "请先运行: git clone https://github.com/Archie-Z/st8m.git $PROJECT_ROOT"
        exit 1
    fi
}

# 获取文件路径
get_file_path() {
    local type=$1  # note或jotting
    local lang=$2  # 语言代码
    local filename=$3
    
    # 确保文件名有.md后缀
    if [[ ! "$filename" == *.md ]]; then
        filename="${filename}.md"
    fi
    
    echo "$CONTENT_DIR/$type/$lang/$filename"
}

# 获取所有语言变体的路径
get_all_lang_paths() {
    local type=$1
    local filename=$2
    local paths=()
    
    if [[ ! "$filename" == *.md ]]; then
        filename="${filename}.md"
    fi
    
    for lang in "${LANGS[@]}"; do
        paths+=("$CONTENT_DIR/$type/$lang/$filename")
    done
    
    echo "${paths[@]}"
}

# 生成YAML前置元数据
generate_frontmatter() {
    local title=$1
    local date=$(date +"%Y-%m-%d")
    local datetime=$(date +"%Y-%m-%dT%H:%M:%S")
    
    cat << YAML
---
title: "$title"
timestamp: "$datetime"
series: 
tags: []
description: 
---

YAML
}

# 更新文件中的日期字段
update_frontmatter_date() {
    local file=$1
    local new_date=$(date +"%Y-%m-%dT%H:%M:%S")
    
    if [ -f "$file" ]; then
        # 使用sed更新timestamp字段
        sed -i "s/timestamp: \".*\"/timestamp: \"$new_date\"/" "$file"
    fi
}

# 列出文件
cmd_list() {
    local type="${1:-n}"
    local target_dir
    
    case "$type" in
        -n|--note)
            target_dir="$CONTENT_DIR/note/$DEFAULT_LANG"
            print_info "笔记列表 (note/$DEFAULT_LANG):"
            ;;
        -j|--jotting)
            target_dir="$CONTENT_DIR/jotting/$DEFAULT_LANG"
            print_info "随想列表 (jotting/$DEFAULT_LANG):"
            ;;
        *)
            print_error "未知类型: $type. 使用 -n (笔记) 或 -j (随想)"
            return 1
            ;;
    esac
    
    if [ ! -d "$target_dir" ]; then
        print_warning "目录不存在: $target_dir"
        return 1
    fi
    
    local count=0
    for file in "$target_dir"/*.md; do
        if [ -f "$file" ]; then
            local name=$(basename "$file" .md)
            local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$file" 2>/dev/null)
            echo -e "${CYAN}  •${NC} $name ${YELLOW}($date)${NC}"
            ((count++))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "  (空)"
    else
        print_success "共 $count 个文件"
    fi
}

# 创建新文件
cmd_new() {
    local type="${1:-n}"
    local filename="$2"
    
    if [ -z "$filename" ]; then
        print_error "请提供文件名"
        echo "用法: st8m new [-n|-j] <filename>"
        return 1
    fi
    
    local target_dir
    
    case "$type" in
        -n|--note)
            target_dir="$CONTENT_DIR/note/$DEFAULT_LANG"
            ;;
        -j|--jotting)
            target_dir="$CONTENT_DIR/jotting/$DEFAULT_LANG"
            ;;
        *)
            print_error "未知类型: $type"
            return 1
            ;;
    esac
    
    mkdir -p "$target_dir"
    local filepath="$target_dir/$filename"
    
    if [[ ! "$filepath" == *.md ]]; then
        filepath="${filepath}.md"
    fi
    
    if [ -f "$filepath" ]; then
        print_warning "文件已存在: $filepath"
        read -p "是否覆盖? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    local title=$(basename "$filename" .md)
    generate_frontmatter "$title" > "$filepath"
    
    print_success "创建文件: $filepath"
    
    # 使用编辑器打开
    cd "$target_dir"
    $EDITOR "$filepath"
}

# 编辑文件
cmd_edit() {
    local type="${1:-n}"
    local filename="$2"
    
    if [ -z "$filename" ]; then
        print_error "请提供文件名"
        echo "用法: st8m edit [-n|-j] <filename>"
        return 1
    fi
    
    local target_dir
    
    case "$type" in
        -n|--note)
            target_dir="$CONTENT_DIR/note/$DEFAULT_LANG"
            ;;
        -j|--jotting)
            target_dir="$CONTENT_DIR/jotting/$DEFAULT_LANG"
            ;;
        *)
            print_error "未知类型: $type"
            return 1
            ;;
    esac
    
    local filepath="$target_dir/$filename"
    if [[ ! "$filepath" == *.md ]]; then
        filepath="${filepath}.md"
    fi
    
    if [ ! -f "$filepath" ]; then
        print_error "文件不存在: $filepath"
        echo "使用 'st8m new $type $filename' 创建新文件"
        return 1
    fi
    
    # 更新修改时间
    update_frontmatter_date "$filepath"
    
    cd "$target_dir"
    $EDITOR "$filepath"
}

# 重命名文件
cmd_rename() {
    local type="${1:-n}"
    local oldname="$2"
    local newname="$3"
    
    if [ -z "$oldname" ] || [ -z "$newname" ]; then
        print_error "请提供原文件名和新文件名"
        echo "用法: st8m rename [-n|-j] <oldname> <newname>"
        return 1
    fi
    
    local target_dir
    
    case "$type" in
        -n|--note)
            target_dir="$CONTENT_DIR/note/$DEFAULT_LANG"
            ;;
        -j|--jotting)
            target_dir="$CONTENT_DIR/jotting/$DEFAULT_LANG"
            ;;
        *)
            print_error "未知类型: $type"
            return 1
            ;;
    esac
    
    local oldpath="$target_dir/$oldname"
    local newpath="$target_dir/$newname"
    
    if [[ ! "$oldpath" == *.md ]]; then
        oldpath="${oldpath}.md"
    fi
    if [[ ! "$newpath" == *.md ]]; then
        newpath="${newpath}.md"
    fi
    
    if [ ! -f "$oldpath" ]; then
        print_error "源文件不存在: $oldpath"
        return 1
    fi
    
    if [ -f "$newpath" ]; then
        print_error "目标文件已存在: $newpath"
        return 1
    fi
    
    # 更新YAML中的title字段
    local new_title=$(basename "$newname" .md)
    sed -i "s/title: \".*\"/title: \"$new_title\"/" "$oldpath"
    update_frontmatter_date "$oldpath"
    
    mv "$oldpath" "$newpath"
    print_success "重命名: $oldname -> $newname"
}

# 删除文件
cmd_del() {
    local type="$1"
    local filename="$2"
    
    if [ -z "$type" ] || [ -z "$filename" ]; then
        print_error "请提供类型和文件名"
        echo "用法: st8m del [-n|-j] <filename>"
        return 1
    fi
    
    local base_type
    
    case "$type" in
        -n|--note)
            base_type="note"
            ;;
        -j|--jotting)
            base_type="jotting"
            ;;
        *)
            print_error "未知类型: $type"
            return 1
            ;;
    esac
    
    # 获取所有语言版本的路径
    local paths_str=$(get_all_lang_paths "$base_type" "$filename")
    local paths=($paths_str)
    local existing_paths=()
    
    # 检查哪些文件存在
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            existing_paths+=("$path")
        fi
    done
    
    if [ ${#existing_paths[@]} -eq 0 ]; then
        print_error "未找到文件: $filename"
        return 1
    fi
    
    echo "将删除以下文件:"
    for path in "${existing_paths[@]}"; do
        echo "  ${RED}• $path${NC}"
    done
    
    read -p "确认删除? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi
    
    for path in "${existing_paths[@]}"; do
        rm "$path"
        print_success "已删除: $path"
    done
}

# 翻译功能（预留接口）
cmd_trans() {
    local type="$1"
    local filename="$2"
    shift 2
    local target_langs=("$@")
    
    if [ -z "$type" ] || [ -z "$filename" ] || [ ${#target_langs[@]} -eq 0 ]; then
        print_error "参数不足"
        echo "用法: st8m trans [-n|-j] <filename> <lang1> [lang2] [lang3]"
        echo "支持语言: zh-cn, en, ja"
        return 1
    fi
    
    local base_type
    
    case "$type" in
        -n|--note)
            base_type="note"
            ;;
        -j|--jotting)
            base_type="jotting"
            ;;
        *)
            print_error "未知类型: $type"
            return 1
            ;;
    esac
    
    local source_path=$(get_file_path "$base_type" "$DEFAULT_LANG" "$filename")
    
    if [ ! -f "$source_path" ]; then
        print_error "源文件不存在: $source_path"
        return 1
    fi
    
    print_info "正在翻译 $filename..."
    print_warning "此功能需要配置元宝AI API密钥"
    
    # 读取源文件内容（跳过YAML前置元数据）
    local content=$(sed -n '/^---$/,/^---$/!p' "$source_path" | sed '1{/^$/d}')
    local title=$(grep "title:" "$source_path" | head -1 | sed 's/title: "\(.*\)"/\1/')
    
    for lang in "${target_langs[@]}"; do
        # 验证语言代码
        if [[ ! " ${LANGS[*]} " =~ " $lang " ]]; then
            print_warning "跳过不支持的语言: $lang"
            continue
        fi
        
        local target_dir="$CONTENT_DIR/$base_type/$lang"
        local target_path="$target_dir/$(basename "$source_path")"
        
        mkdir -p "$target_dir"
        
        # 生成翻译后的文件（预留：这里应调用元宝AI API）
        print_info "生成 $lang 版本..."
        
        # 临时：复制并标记为待翻译
        local trans_title="[待翻译] $title"
        local trans_date=$(date +"%Y-%m-%dT%H:%M:%S")
        
        cat > "$target_path" << YAML
---
title: "$trans_title"
timestamp: "$trans_date"
series: 
tags: []
description: 
lang: "$lang"
---

<!-- 此文件由st8m trans自动生成，待翻译 -->
<!-- 源文件: $source_path -->

$content
YAML
        
        print_success "已创建: $target_path"
    done
    
    print_info "提示: 请手动编辑翻译文件或配置元宝AI API实现自动翻译"
}

# 更新到GitHub
cmd_update() {
    check_project
    
    print_info "正在同步到GitHub..."
    cd "$PROJECT_ROOT"
    
    # 检查是否有变更
    if [ -z "$(git status --porcelain)" ]; then
        print_warning "没有需要提交的变更"
        return 0
    fi
    
    # 添加所有变更
    git add .
    
    # 提交信息
    local msg="update: $(date +"%Y-%m-%d %H:%M")"
    git commit -m "$msg"
    
    # 推送到远程，设置30秒超时
    print_info "推送到GitHub (超时: 30秒)..."
    
    # 获取当前分支名
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    if timeout 30 git push origin "$current_branch" 2>&1; then
        print_success "同步成功!"
    else
        print_error "同步失败或超时"
        git reset --soft HEAD~1  # 回滚本地提交
        return 1
    fi
}

# 回滚版本
cmd_rollback() {
    local version="$1"
    
    if [ -z "$version" ]; then
        print_error "请提供版本号"
        echo "用法: st8m --rollback <commit-hash>"
        return 1
    fi
    
    check_project
    cd "$PROJECT_ROOT"
    
    print_warning "即将回滚到版本: $version"
    read -p "确认? 这将丢失未提交的变更! (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    # 强制回滚
    git fetch origin --all
    git reset --hard "$version"
    
    print_success "已回滚到: $version"
}

# 显示版本
cmd_version() {
    echo -e "${CYAN}ST8-M CLI Tool${NC}"
    echo "版本: $VERSION"
    echo "项目路径: $PROJECT_ROOT"
    echo "作者: Archie-Z"
}

# 显示帮助
cmd_help() {
    printf "\n${CYAN}ST8-M CLI Tool${NC} - 个人博客管理系统\n\n"
    printf "${GREEN}用法:${NC}\n"
    printf "    st8m <command> [options]\n\n"
    printf "${GREEN}命令:${NC}\n"
    printf "    ${YELLOW}list${NC} [-n|-j]              列出文件 (默认: note)\n"
    printf "    ${YELLOW}new${NC} [-n|-j] <filename>    创建并编辑新文件\n"
    printf "    ${YELLOW}edit${NC} [-n|-j] <filename>   编辑现有文件\n"
    printf "    ${YELLOW}rename${NC} [-n|-j] <old> <new> 重命名文件\n"
    printf "    ${YELLOW}del${NC} [-n|-j] <filename>    删除文件（所有语言版本）\n"
    printf "    ${YELLOW}trans${NC} [-n|-j] <file> <lang...> 翻译文件 (zh-cn, en, ja)\n\n"
    printf "${GREEN}选项:${NC}\n"
    printf "    ${YELLOW}-n, --note${NC}                操作笔记目录 (默认)\n"
    printf "    ${YELLOW}-j, --jotting${NC}             操作随想目录\n\n"
    printf "${GREEN}全局选项:${NC}\n"
    printf "    ${YELLOW}--update${NC}                  同步项目到GitHub\n"
    printf "    ${YELLOW}--rollback${NC} <version>      回滚到指定版本\n"
    printf "    ${YELLOW}--version${NC}                 显示版本信息\n"
    printf "    ${YELLOW}--help${NC}                    显示此帮助信息\n\n"
    printf "${GREEN}示例:${NC}\n"
    printf "    st8m list                    # 列出所有笔记\n"
    printf "    st8m new -j today-thoughts   # 创建随想\n"
    printf "    st8m edit -n my-article      # 编辑笔记\n"
    printf "    st8m trans -n hello en ja    # 翻译到英文和日文\n"
    printf "    st8m --update                # 同步到GitHub\n\n"
    printf "${BLUE}项目地址:${NC} https://github.com/Archie-Z/st8m\n\n"  
}

# 主入口
main() {
    # 无参数时显示帮助
    if [ $# -eq 0 ]; then
        cmd_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        list|ls)
            cmd_list "$@"
            ;;
        new|n)
            cmd_new "$@"
            ;;
        edit|e)
            cmd_edit "$@"
            ;;
        rename|mv)
            cmd_rename "$@"
            ;;
        del|rm|delete)
            cmd_del "$@"
            ;;
        trans|translate|t)
            cmd_trans "$@"
            ;;
        --update|update|up)
            cmd_update
            ;;
        --rollback|rollback)
            cmd_rollback "$@"
            ;;
        --version|-v|version)
            cmd_version
            ;;
        --help|-h|help)
            cmd_help
            ;;
        *)
            print_error "未知命令: $command"
            echo "使用 'st8m --help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
EOF

# 设置可执行权限
chmod +x "$ST8M_BIN"

echo -e "${GREEN}st8m已安装到: $ST8M_BIN${NC}"

# 立即在当前shell中可用（如果可能）
export PATH="$BIN_DIR:$PATH"

echo -e "\n${GREEN}=== 安装完成 ===${NC}"
echo -e "请运行: ${YELLOW}source ~/.zshrc${NC} 或 ${YELLOW}source ~/.bashrc${NC} 以立即使用"
echo -e "或直接使用: ${YELLOW}$ST8M_BIN --help${NC}"
