#!/bin/bash
# 统一构建脚本，支持 APK / XAPK

BUILD_TOOLS_DIR=$(find ${ANDROID_HOME}/build-tools -maxdepth 1 -type d | sort -V | tail -n 1)
AAPT_PATH="${BUILD_TOOLS_DIR}/aapt"
DOWNLOAD_DIR="."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
KEY_DIR="${SCRIPT_DIR}/key/"
GAME_SERVER=$1
APK_URL=$2
BUILD_TYPE="APK"

# 路径变量 — 由 SET_BUILD_PATHS 统一赋值
APK_FILE=""
UNSIGNED_FILE=""
FINAL_FILE=""

ARCHS=("arm64_v8a" "x86" "x86_64")
JMBQ_PATH="${DOWNLOAD_DIR}/JMBQ"
TEMP_DIR="${DOWNLOAD_DIR}/.TEMP_LATEST_ARCH"

# ---- 工具函数 ----

# 检查参数 & 推断 BUILD_TYPE
CHECK_PARAM() {
    [ -z "${GAME_SERVER}" ] && { echo "服务器名称不能为空"; exit 1; }
    echo "${GAME_SERVER}" | grep -q "^[a-zA-Z0-9]*$" || { echo "服务器参数包含非英文字符"; exit 1; }

    case "${GAME_SERVER}" in
        "TW" | "EN" | "JP" | "KR")
            BUILD_TYPE="XAPK"
            echo "XAPK 模式: ${GAME_SERVER}" ;;
        *)
            [ -z "${APK_URL}" ] && { echo "APK 下载链接不能为空"; exit 1; }
            BUILD_TYPE="APK"
            echo "APK 模式: ${GAME_SERVER}" ;;
    esac
}

# 包名映射（XAPK 模式）
SET_BUNDLE_ID() {
    case "$GAME_SERVER" in
        "TW") GAME_BUNDLE_ID="com.hkmanjuu.azurlane.gp" ;;
        "EN") GAME_BUNDLE_ID="com.YoStarEN.AzurLane" ;;
        "JP") GAME_BUNDLE_ID="com.YoStarJP.AzurLane" ;;
        "KR") GAME_BUNDLE_ID="kr.txwy.and.blhx" ;;
    esac
    echo "包名: ${GAME_BUNDLE_ID}"
}

# 根据 BUILD_TYPE 设置路径变量
SET_BUILD_PATHS() {
    if [ "${BUILD_TYPE}" = "XAPK" ]; then
        APK_FILE="${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}.apk"
        UNSIGNED_FILE="${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}.unsigned.apk"
        FINAL_FILE="${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}.xapk"
    else
        APK_FILE="${DOWNLOAD_DIR}/${GAME_SERVER}.apk"
        UNSIGNED_FILE="${DOWNLOAD_DIR}/${GAME_SERVER}.unsigned.apk"
        FINAL_FILE="${APK_FILE}"
    fi
}

# 下载 apkeep
DOWNLOAD_APKEEP() {
    local OWNER="EFForg" REPO="apkeep" PLATFORM="x86_64-unknown-linux-gnu"
    echo "下载 apkeep..."
    local URL=$(curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" \
        | jq -r ".assets[] | select(.name | contains(\"${PLATFORM}\")) | .browser_download_url" | head -n 1)
    [ -z "${URL}" ] || [ "${URL}" = "null" ] && { echo "无法获取 apkeep 下载链接"; exit 1; }
    curl -L -o "${DOWNLOAD_DIR}/apkeep" "${URL}" && chmod +x "${DOWNLOAD_DIR}/apkeep" \
        || { echo "apkeep 下载失败"; exit 1; }
    echo "apkeep 下载成功"
}

# 下载 Apktool（锁定 2.12.1）
DOWNLOAD_APKTOOL() {
    local OWNER="iBotPeaches" REPO="Apktool" VERSION="2.12.1"
    echo "下载 Apktool..."
    local URL=$(curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/tags/v${VERSION}" \
        | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' | head -n 1)
    [ -z "${URL}" ] || [ "${URL}" = "null" ] && { echo "无法获取 Apktool 下载链接"; exit 1; }
    curl -L -o "${DOWNLOAD_DIR}/apktool.jar" "${URL}" || { echo "Apktool 下载失败"; exit 1; }
    echo "Apktool 下载成功"
}

# 备份 / 恢复最新补丁文件
COPY_LATEST_ARCHS() {
    local MODE=$1
    if [ "${MODE}" = "save" ]; then
        rm -rf "${TEMP_DIR}" && mkdir -p "${TEMP_DIR}"
        for ARCH in "${ARCHS[@]}"; do
            [ -f "${JMBQ_PATH}/${ARCH}" ] && cp "${JMBQ_PATH}/${ARCH}" "${TEMP_DIR}/"
        done
    elif [ "${MODE}" = "restore" ] && [ -d "${TEMP_DIR}" ]; then
        mkdir -p "${JMBQ_PATH}/assets/arch"
        for ARCH in "${ARCHS[@]}"; do
            [ -f "${TEMP_DIR}/${ARCH}" ] && cp "${TEMP_DIR}/${ARCH}" "${JMBQ_PATH}/assets/arch/"
        done
    fi
    return 0
}

# 验证 MOD 补丁结构（assets/arch 补丁库 + smali_classes* 目录）
VALIDATE_MOD_PATCH() {
    [ -d "${JMBQ_PATH}" ] || return 1
    local HAS_ARCH=0 HAS_SMALI=0
    for ARCH in "${ARCHS[@]}"; do
        [ -d "${JMBQ_PATH}/assets/arch" ] && [ -f "${JMBQ_PATH}/assets/arch/${ARCH}" ] && HAS_ARCH=1
    done
    find "${JMBQ_PATH}" -maxdepth 1 -type d -name "smali_classes*" | grep -q . && HAS_SMALI=1
    [ $HAS_ARCH -eq 1 ] && [ $HAS_SMALI -eq 1 ]
}

# 获取 Release 版本列表（按创建时间降序）
GET_ALL_RELEASES() {
    curl -s "https://api.github.com/repos/JMBQ01/azurlan/releases" \
        | jq -r 'sort_by(.created_at) | reverse | .[].tag_name' 2>/dev/null
}

# 获取指定版本的下载链接与后缀
GET_RELEASE_DOWNLOAD_INFO() {
    local TARGET_VERSION=$1
    local RES=$(curl -s "https://api.github.com/repos/JMBQ01/azurlan/releases/tags/${TARGET_VERSION}")
    local LINK=$(echo "${RES}" | jq -r '.assets[] | select(.name | contains(".rar")) | .browser_download_url' | head -n 1)
    local SUFFIX="rar"
    if [ -z "${LINK}" ] || [ "${LINK}" = "null" ]; then
        LINK=$(echo "${RES}" | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url' | head -n 1)
        SUFFIX="zip"
    fi
    [ -z "${LINK}" ] || [ "${LINK}" = "null" ] && return 1
    echo "${LINK}|${SUFFIX}"
}

# 下载并验证指定版本的 MOD 补丁
TRY_MOD_VERSION() {
    local TARGET_VERSION=$1
    local INFO; INFO=$(GET_RELEASE_DOWNLOAD_INFO "${TARGET_VERSION}") || return 1
    local DOWNLOAD_LINK=$(echo "${INFO}" | cut -d'|' -f1)
    local SUFFIX=$(echo "${INFO}" | cut -d'|' -f2)
    local TRY_FILENAME="MOD_BACKUP_${TARGET_VERSION}.${SUFFIX}"

    rm -rf "${JMBQ_PATH}"
    curl -L -o "${DOWNLOAD_DIR}/${TRY_FILENAME}" "${DOWNLOAD_LINK}" || return 1
    7z x -y "${DOWNLOAD_DIR}/${TRY_FILENAME}" -o"${JMBQ_PATH}" > /dev/null 2>&1
    rm -f "${DOWNLOAD_DIR}/${TRY_FILENAME}"
    [ $? -ne 0 ] && return 1

    if VALIDATE_MOD_PATCH; then
        COPY_LATEST_ARCHS restore
        JMBQ_VERSION="${TARGET_VERSION}"
        return 0
    fi
    return 1
}

# 下载 MOD 补丁（最新版 → 回退历史版本）
DOWNLOAD_MOD_MENU() {
    local OWNER="JMBQ01" REPO="azurlan"
    echo "下载 MOD 补丁..."
    local RES=$(curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest")
    JMBQ_VERSION=$(echo "${RES}" | jq -r '.tag_name')
    local LATEST=$JMBQ_VERSION

    local LINK=$(echo "${RES}" | jq -r '.assets[] | select(.name | contains(".rar")) | .browser_download_url' | head -n 1)
    local FILENAME="MOD_MENU.rar"
    if [ -z "${LINK}" ] || [ "${LINK}" = "null" ]; then
        LINK=$(echo "${RES}" | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url' | head -n 1)
        FILENAME="MOD_MENU.zip"
        [ -z "${LINK}" ] || [ "${LINK}" = "null" ] && { echo "无法获取 MOD 补丁下载链接"; exit 1; }
    fi

    rm -rf "${JMBQ_PATH}" "${DOWNLOAD_DIR}/${FILENAME}"
    curl -L -o "${DOWNLOAD_DIR}/${FILENAME}" "${LINK}" || { echo "补丁下载失败"; exit 1; }
    7z x -y "${DOWNLOAD_DIR}/${FILENAME}" -o"${JMBQ_PATH}" > /dev/null 2>&1 || { echo "解压失败"; exit 1; }

    if VALIDATE_MOD_PATCH; then
        echo "最新版本 ${JMBQ_VERSION} 验证通过"
    else
        echo "最新版本结构不完整，尝试回退历史版本..."
        COPY_LATEST_ARCHS save

        local ALL_VERSIONS=($(GET_ALL_RELEASES))
        local IDX=-1
        for i in "${!ALL_VERSIONS[@]}"; do
            [ "${ALL_VERSIONS[$i]}" = "${JMBQ_VERSION}" ] && { IDX=$i; break; }
        done
        [ $IDX -eq -1 ] && IDX=0

        local TOTAL=${#ALL_VERSIONS[@]}
        local MAX_RETRIES=10
        local REMAIN=$((TOTAL - IDX - 1))
        [ ${REMAIN} -lt ${MAX_RETRIES} ] && MAX_RETRIES=${REMAIN}
        [ ${MAX_RETRIES} -le 0 ] && { echo "无可用历史版本"; exit 1; }

        local FOUND=0
        for ((r=1; r<=MAX_RETRIES; r++)); do
            local TIDX=$((IDX + r))
            [ ${TIDX} -ge ${TOTAL} ] && break
            local PV="${ALL_VERSIONS[${TIDX}]}"
            echo "  -> 回退: ${PV}"
            if TRY_MOD_VERSION "${PV}"; then FOUND=1; break; fi
        done
        [ $FOUND -eq 0 ] && { echo "回退 ${MAX_RETRIES} 个版本均失败"; exit 1; }
    fi

    rm -rf "${TEMP_DIR}"
    echo "JMBQ_VERSION=${LATEST}" >> "${GITHUB_ENV}"
}

# 下载 APK（内部按 BUILD_TYPE 走不同逻辑）
DOWNLOAD_APK() {
    if [ "${BUILD_TYPE}" = "XAPK" ]; then
        echo "通过 apkeep 下载 XAPK..."
        "${DOWNLOAD_DIR}/apkeep" -a "${GAME_BUNDLE_ID}" "${DOWNLOAD_DIR}/" || exit 1
        unzip -o "${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}.xapk" -d "${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}" || exit 1
        mv "${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}/${GAME_BUNDLE_ID}.apk" "${APK_FILE}"
        rm -f "${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}.xapk"
    else
        echo "下载 APK..."
        curl -L -o "${APK_FILE}" "${APK_URL}" || exit 1
    fi
    echo "下载完成: ${APK_FILE}"
}

# 验证 APK 完整性
VERIFY_APK() {
    echo "验证 APK: ${APK_FILE}"
    [ ! -f "${APK_FILE}" ] && { echo "APK 文件未找到"; exit 1; }
    local SIZE=$(stat -f%z "${APK_FILE}" 2>/dev/null || stat -c%s "${APK_FILE}" 2>/dev/null)
    [ "${SIZE}" -lt 1024 ] && { echo "APK 文件大小异常"; exit 1; }
    unzip -t "${APK_FILE}" >/dev/null 2>&1 || { echo "APK 文件损坏"; exit 1; }
    echo "APK 验证通过"
}

# 反编译 APK
DECODE_APK() {
    echo "反编译 APK..."
    java -jar "${DOWNLOAD_DIR}/apktool.jar" d -f "${APK_FILE}" -o "${DOWNLOAD_DIR}/DECODE_Output" || exit 1
    echo "反编译完成"
}

# 删除反编译前的原始 APK
DELETE_ORIGINAL_APK() {
    echo "删除原始 APK..."
    rm -f "${APK_FILE}"
}

# 合入 MOD 补丁
PATCH_APK() {
    echo "合入 MOD..."
    cp -r "${DOWNLOAD_DIR}/JMBQ/assets/." "${DOWNLOAD_DIR}/DECODE_Output/assets/" || exit 1

    local MAX_NUM=$(find "${DOWNLOAD_DIR}/DECODE_Output/" -maxdepth 1 -type d -name "smali_classes*" \
        | sed 's/.*smali_classes//' | sort -n | tail -1)
    MAX_NUM=${MAX_NUM:-3}
    local NEW_DIR="smali_classes$((MAX_NUM + 1))"

    local SRC=$(find "${DOWNLOAD_DIR}/JMBQ" -type d -name "smali_classes*" 2>/dev/null | head -1)
    [ -z "${SRC}" ] && { echo "MOD 中未找到 smali_classes 目录"; exit 1; }
    cp -r "${SRC}" "${DOWNLOAD_DIR}/DECODE_Output/${NEW_DIR}" || exit 1

    local SMALI=$(find "${DOWNLOAD_DIR}/DECODE_Output" -type f -name "UnityPlayerActivity.smali")
    [ -z "${SMALI}" ] && { echo "UnityPlayerActivity.smali 未找到"; exit 1; }

    local LN=$(grep -n ".method public constructor <init>()V" "${SMALI}" | cut -d: -f1)
    [ -z "${LN}" ] && { echo "未找到构造函数"; exit 1; }
    sed -i -e "/\.method public constructor <init>()V/,/\.end method/{/\.locals 0/a\    invoke-static {}, Lcom/android/support/Main;->Start()V" -e "}" "${SMALI}" || exit 1

    local MF="${DOWNLOAD_DIR}/DECODE_Output/AndroidManifest.xml"
    sed -i 's#</application>#    <service android:name="com.android.support.Launcher" android:enabled="true" android:exported="false" android:stopWithTask="true"/>\n    </application>\n    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>#' "${MF}" || exit 1
    echo "MOD 合入完成"
}

# 重新打包 APK
BUILD_APK() {
    echo "重新打包 APK..."
    java -jar "${DOWNLOAD_DIR}/apktool.jar" b -f "${DOWNLOAD_DIR}/DECODE_Output" -o "${APK_FILE}" || exit 1
    echo "打包完成"
}

# Zipalign + apksigner
OPTIMIZE_AND_SIGN_APK() {
    export PATH=${PATH}:${BUILD_TOOLS_DIR}
    local KEY="${KEY_DIR}testkey.pk8"
    local CERT="${KEY_DIR}testkey.x509.pem"

    [ ! -f "${APK_FILE}" ] && { echo "APK 文件不存在: ${APK_FILE}"; exit 1; }
    [ ! -f "${KEY}" ] || [ ! -f "${CERT}" ] && { echo "签名密钥文件缺失"; exit 1; }

    echo "优化 APK..."
    zipalign -f 4 "${APK_FILE}" "${UNSIGNED_FILE}" || { echo "优化失败"; exit 1; }
    rm -f "${APK_FILE}"
    echo "签名 APK..."
    apksigner sign --key "${KEY}" --cert "${CERT}" "${UNSIGNED_FILE}" || { echo "签名失败"; exit 1; }
    mv "${UNSIGNED_FILE}" "${APK_FILE}"
    echo "优化 + 签名完成"
}

# 获取游戏版本号并写入 GITHUB_ENV
GET_GAME_VERSION() {
    GAME_VERSION="0.0.0"
    if [ -f "${APK_FILE}" ] && [ -f "${AAPT_PATH}" ]; then
        local VER=$("${AAPT_PATH}" dump badging "${APK_FILE}" | grep "versionName" | sed "s/.*versionName='\([^']*\)'.*/\1/" | head -1)
        [ -n "${VER}" ] && [ "${VER}" != "''" ] && GAME_VERSION="${VER}"
    fi
    echo "VERSION=${GAME_VERSION}" >> "${GITHUB_ENV}"
    echo "游戏版本: ${GAME_VERSION}"
}

# APK 模式：按包名重命名
RENAME_APK() {
    [ "${BUILD_TYPE}" = "XAPK" ] && return
    [ ! -f "${APK_FILE}" ] && return
    local PKG=$("${AAPT_PATH}" dump badging "${APK_FILE}" 2>/dev/null | grep "package: name=" | cut -d"'" -f2 | head -1)
    [ -z "${PKG}" ] && PKG="${GAME_SERVER}"
    mv "${APK_FILE}" "${DOWNLOAD_DIR}/${PKG}.apk"
    APK_FILE="${DOWNLOAD_DIR}/${PKG}.apk"
    FINAL_FILE="${APK_FILE}"
    echo "重命名为: ${PKG}.apk"
}

# XAPK 模式：重新打包为 .xapk
REPACK_XAPK() {
    [ "${BUILD_TYPE}" != "XAPK" ] && return
    echo "重新打包 XAPK..."
    local DIR="${DOWNLOAD_DIR}/${GAME_BUNDLE_ID}"
    mkdir -p "${DIR}"
    mv -f "${APK_FILE}" "${DIR}/${GAME_BUNDLE_ID}.apk"
    cd "${DIR}" && zip -r "${GAME_BUNDLE_ID}.xapk" . && cd - > /dev/null
    mv "${DIR}/${GAME_BUNDLE_ID}.xapk" "${FINAL_FILE}"
    rm -rf "${DIR}"
    echo "XAPK 打包完成"
}

# 7z 分卷压缩
CREATE_SPLIT_ARCHIVES() {
    [ ! -f "${FINAL_FILE}" ] && { echo "最终文件未找到: ${FINAL_FILE}"; exit 1; }
    echo "压缩: ${FINAL_FILE}"
    7z a -v800M "${GAME_SERVER}-V.${GAME_VERSION}.7z" "${FINAL_FILE}" || exit 1
    echo "分卷压缩完成"
}

# Logo
PRINT_LOGO() {
    cat << "EOF"

 ________  ________  ___  ___  ________  ___       ________  ________   _______              ___  _____ ______   ________  ________      
|\   __  \|\_____  \|\  \|\  \|\   __  \|\  \     |\   __  \|\   ___  \|\  ___ \            |\  \|\   _ \  _   \|\   __  \|\   __  \     
\ \  \|\  \\___/  /\ \  \\  \ \  \|\  \ \  \    \ \  \|\  \ \  \\ \  \ \   __/|           \ \  \ \  \\__\ \  \ \  \|\ /\ \  \|\  \    
 \ \   __  \   /  / /\ \  \\  \ \   _  _\ \  \    \ \   __  \ \  \\ \  \ \  \_|/__       __ \ \  \ \  \\|__| \  \ \   __  \ \  \\  \\  
  \ \  \ \  \ /  /_/__\ \  \\  \ \  \\  \\ \  \____\ \  \ \  \ \  \\ \  \ \  \_|\ \     |\  \\\_\  \ \  \    \ \  \ \  \|\  \ \  \\  \\  
   \ \__\ \__\\________\ \_______\ \__\\ _\\ \_______\ \__\ \__\ \__\\ \__\ \_______\    \ \________\ \__\    \ \__\ \_______\ \_____  \ 
    \|__|\|__\|\|_______|\|_______|\|__|\|__\|_______|\|__|\|__|\|__| \|__\|_______|     \|________|\|__|     \|__\|_______|\|___| \__\
                                                                                                                                     \|__|
                                                                                                                                          
                                                                                                                                         
EOF
}

# ---- 主流程 ----
main() {
    PRINT_LOGO
    CHECK_PARAM

    # XAPK 特有前置步骤
    if [ "${BUILD_TYPE}" = "XAPK" ]; then
        SET_BUNDLE_ID
        DOWNLOAD_APKEEP
    fi

    SET_BUILD_PATHS

    # 公共构建流程
    DOWNLOAD_APKTOOL
    DOWNLOAD_MOD_MENU
    DOWNLOAD_APK
    VERIFY_APK
    DECODE_APK
    DELETE_ORIGINAL_APK
    PATCH_APK
    BUILD_APK
    OPTIMIZE_AND_SIGN_APK
    GET_GAME_VERSION

    # 差异步骤
    if [ "${BUILD_TYPE}" = "XAPK" ]; then
        REPACK_XAPK
    else
        RENAME_APK
    fi

    CREATE_SPLIT_ARCHIVES
    echo "构建完成！类型: ${BUILD_TYPE}"
}

main