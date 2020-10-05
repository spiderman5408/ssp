#!/bin/bash

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

CUR_VER=""
NEW_VER=""
ARCH=""
VDIS="amd64"
ZIPFILE="/tmp/ssp/ssp.zip"
ssp_RUNNING=0
VSRC_ROOT="/tmp/ssp"
EXTRACT_ONLY=0
ERROR_IF_UPTODATE=0

CMD_INSTALL=""
CMD_UPDATE=""
SOFTWARE_UPDATED=0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

CHECK=""
FORCE=""
HELP=""

#######color code########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message


#########################
while [[ $# > 0 ]];do
    key="$1"
    case $key in
        -p|--proxy)
        PROXY="-x ${2}"
        shift # past argument
        ;;
        -h|--help)
        HELP="1"
        ;;
        -f|--force)
        FORCE="1"
        ;;
        -c|--check)
        CHECK="1"
        ;;
        --remove)
        REMOVE="1"
        ;;
        --version)
        VERSION="$2"
        shift
        ;;
        --extract)
        VSRC_ROOT="$2"
        shift
        ;;
        --extractonly)
        EXTRACT_ONLY="1"
        ;;
        -l|--local)
        LOCAL="$2"
        LOCAL_INSTALL="1"
        shift
        ;;
        --errifuptodate)
        ERROR_IF_UPTODATE="1"
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

###############################
colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

downloadssp(){
    rm -rf /tmp/ssp
    mkdir -p /tmp/ssp
    colorEcho ${BLUE} "Downloading ssp."
    DOWNLOAD_LINK="https://github.com/ColetteContreras/ssp/releases/download/${NEW_VER}/ssp-linux-${VDIS}.zip"
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        colorEcho ${RED} "Failed to download! Please check your network or try again."
        return 3
    fi
    return 0
}

installSoftware(){
    COMPONENT=$1
    if [[ -n `command -v $COMPONENT` ]]; then
        return 0
    fi

    getPMT
    if [[ $? -eq 1 ]]; then
        colorEcho ${RED} "The system package manager tool isn't APT or YUM, please install ${COMPONENT} manually."
        return 1 
    fi
    if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Updating software repo"
        $CMD_UPDATE      
        SOFTWARE_UPDATED=1
    fi

    colorEcho ${BLUE} "Installing ${COMPONENT}"
    $CMD_INSTALL $COMPONENT
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to install ${COMPONENT}. Please install it manually."
        return 1
    fi
    return 0
}

# return 1: not apt, yum, or zypper
getPMT(){
    if [[ -n `command -v apt-get` ]];then
        CMD_INSTALL="apt-get -y -qq install"
        CMD_UPDATE="apt-get -qq update"
    elif [[ -n `command -v yum` ]]; then
        CMD_INSTALL="yum -y -q install"
        CMD_UPDATE="yum -q makecache"
    elif [[ -n `command -v zypper` ]]; then
        CMD_INSTALL="zypper -y install"
        CMD_UPDATE="zypper ref"
    else
        return 1
    fi
    return 0
}

extract(){
    colorEcho ${BLUE}"Extracting ssp package to /tmp/ssp."
    mkdir -p /tmp/ssp
    unzip $1 -d ${VSRC_ROOT}
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to extract ssp."
        return 2
    fi
    if [[ -d "/tmp/ssp/ssp-${NEW_VER}-linux-${VDIS}" ]]; then
      VSRC_ROOT="/tmp/ssp/ssp-${NEW_VER}-linux-${VDIS}"
    fi
    return 0
}


# 1: new ssp. 0: no. 2: not installed. 3: check failed. 4: don't check.
getVersion(){
    if [[ -n "$VERSION" ]]; then
        NEW_VER="$VERSION"
        if [[ ${NEW_VER} != v* ]]; then
          NEW_VER=v${NEW_VER}
        fi
        return 4
    else
        VER=`/usr/bin/ssp/ssp -version 2>/dev/null`
        RETVAL="$?"
        CUR_VER=`echo $VER | head -n 1 | cut -d " " -f2`
        if [[ ${CUR_VER} != v* ]]; then
            CUR_VER=v${CUR_VER}
        fi
        TAG_URL="https://api.github.com/repos/ColetteContreras/ssp/releases/latest"
        NEW_VER=`curl ${PROXY} -s ${TAG_URL} --connect-timeout 10| grep 'tag_name' | head -1 | cut -d\" -f4`
        if [[ ${NEW_VER} != v* ]]; then
          NEW_VER=v${NEW_VER}
        fi
        if [[ $? -ne 0 ]] || [[ $NEW_VER == "" ]]; then
            colorEcho ${RED} "Failed to fetch release information. Please check your network or try again."
            return 3
        elif [[ $RETVAL -ne 0 ]];then
            return 2
        elif [[ "$NEW_VER" != "$CUR_VER" ]];then
            return 1
        fi
        return 0
    fi
}

stopssp(){
    colorEcho ${BLUE} "Shutting down ssp service."
    if [[ -n "${SYSTEMCTL_CMD}" ]] || [[ -f "/lib/systemd/system/ssp.service" ]] || [[ -f "/etc/systemd/system/ssp.service" ]]; then
        ${SYSTEMCTL_CMD} stop ssp
    elif [[ -n "${SERVICE_CMD}" ]] || [[ -f "/etc/init.d/ssp" ]]; then
        ${SERVICE_CMD} ssp stop
    fi
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to shutdown ssp service."
        return 2
    fi
    return 0
}

startssp(){
    if [ -n "${SYSTEMCTL_CMD}" ] && [ -f "/lib/systemd/system/ssp.service" ]; then
        ${SYSTEMCTL_CMD} start ssp
    elif [ -n "${SYSTEMCTL_CMD}" ] && [ -f "/etc/systemd/system/ssp.service" ]; then
        ${SYSTEMCTL_CMD} start ssp
    elif [ -n "${SERVICE_CMD}" ] && [ -f "/etc/init.d/ssp" ]; then
        ${SERVICE_CMD} ssp start
    fi
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to start ssp service."
        return 2
    fi
    return 0
}

copyFile() {
    NAME=$1
    ERROR=`cp "${VSRC_ROOT}/${NAME}" "/usr/bin/${NAME}" 2>&1`
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "${ERROR}"
        return 1
    fi
    return 0
}

makeExecutable() {
    chmod +x "/usr/bin/$1"
}

installssp(){
    # Install ssp binary to /usr/bin/ssp
    copyFile ssp
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to copy ssp binary and resources."
        return 1
    fi
    makeExecutable ssp

    # Install ssp server config to /etc/ssp
    if [[ ! -f "/etc/ssp/config.ini" ]]; then
        mkdir -p /etc/ssp
        mkdir -p /var/log/ssp

		cp "${VSRC_ROOT}/config.ini" "/etc/ssp/"
    fi

    return 0
}


installInitScript(){
    if [[ -n "${SYSTEMCTL_CMD}" ]];then
        if [[ ! -f "/etc/systemd/system/ssp.service" ]]; then
            if [[ ! -f "/lib/systemd/system/ssp.service" ]]; then
                cp "${VSRC_ROOT}/ssp.service" "/etc/systemd/system/"
                cp "${VSRC_ROOT}/ssp@.service" "/etc/systemd/system/"
                systemctl enable ssp.service
            fi
        fi
        return
    fi
    return
}

Help(){
    echo "./install-release.sh [-h] [-c] [--remove] [-p proxy] [-f] [--version vx.y.z] [-l file]"
    echo "  -h, --help            Show help"
    echo "  -p, --proxy           To download through a proxy server, use -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:3128 etc"
    echo "  -f, --force           Force install"
    echo "      --version         Install a particular version, use --version v3.15"
    echo "  -l, --local           Install from a local file"
    echo "      --remove          Remove installed ssp"
    echo "  -c, --check           Check for update"
    return 0
}

remove(){
    if [[ -n "${SYSTEMCTL_CMD}" ]] && [[ -f "/etc/systemd/system/ssp.service" ]];then
        if pgrep "ssp" > /dev/null ; then
            stopssp
        fi
        systemctl disable ssp.service
        rm -rf "/usr/bin/ssp" "/etc/systemd/system/ssp.service"
        if [[ $? -ne 0 ]]; then
            colorEcho ${RED} "Failed to remove ssp."
            return 0
        else
            colorEcho ${GREEN} "Removed ssp successfully."
            colorEcho ${BLUE} "If necessary, please remove configuration file and log file manually."
            return 0
        fi
    else
        colorEcho ${YELLOW} "ssp not found."
        return 0
    fi
}

checkUpdate(){
    echo "Checking for update."
    VERSION=""
    getVersion
    RETVAL="$?"
    if [[ $RETVAL -eq 1 ]]; then
        colorEcho ${BLUE} "Found new version ${NEW_VER} for ssp.(Current version:$CUR_VER)"
    elif [[ $RETVAL -eq 0 ]]; then
        colorEcho ${BLUE} "No new version. Current version is ${NEW_VER}."
    elif [[ $RETVAL -eq 2 ]]; then
        colorEcho ${YELLOW} "No ssp installed."
        colorEcho ${BLUE} "The newest version for ssp is ${NEW_VER}."
    fi
    return 0
}

main() {
    #helping information
    [[ "$HELP" == "1" ]] && Help && return
    [[ "$CHECK" == "1" ]] && checkUpdate && return
    [[ "$REMOVE" == "1" ]] && remove && return
    
    # extract local file
    if [[ $LOCAL_INSTALL -eq 1 ]]; then
        colorEcho ${YELLOW} "Installing ssp via local file. Please make sure the file is a valid ssp package, as we are not able to determine that."
        NEW_VER=local
        installSoftware unzip || return $?
        rm -rf /tmp/ssp
        extract $LOCAL || return $?
        #FILEVDIS=`ls /tmp/ssp |grep ssp-v |cut -d "-" -f4`
        #SYSTEM=`ls /tmp/ssp |grep ssp-v |cut -d "-" -f3`
        #if [[ ${SYSTEM} != "linux" ]]; then
        #    colorEcho ${RED} "The local ssp can not be installed in linux."
        #    return 1
        #elif [[ ${FILEVDIS} != ${VDIS} ]]; then
        #    colorEcho ${RED} "The local ssp can not be installed in ${ARCH} system."
        #    return 1
        #else
        #    NEW_VER=`ls /tmp/ssp |grep ssp-v |cut -d "-" -f2`
        #fi
    else
        # download via network and extract
        installSoftware "curl" || return $?
        getVersion
        RETVAL="$?"
        if [[ $RETVAL == 0 ]] && [[ "$FORCE" != "1" ]]; then
            colorEcho ${BLUE} "Latest version ${NEW_VER} is already installed."
            if [[ "${ERROR_IF_UPTODATE}" == "1" ]]; then
              return 10
            fi
            return
        elif [[ $RETVAL == 3 ]]; then
            return 3
        else
            colorEcho ${BLUE} "Installing ssp ${NEW_VER} on ${ARCH}"
            downloadssp || return $?
            installSoftware unzip || return $?
            extract ${ZIPFILE} || return $?
        fi
    fi 
    
    if [[ "${EXTRACT_ONLY}" == "1" ]]; then
        colorEcho ${GREEN} "ssp extracted to ${VSRC_ROOT}, and exiting..."
        return 0
    fi

    if pgrep "ssp" > /dev/null ; then
        ssp_RUNNING=1
        stopssp
    fi
    installssp || return $?
    installInitScript || return $?

    sed -i "1s|YOUR_PANEL_TYPE|${panel_type:-v2board}|g" /etc/ssp/config.ini
    sed -i "2s|https://www.domain.com|${webapi_url}|g" /etc/ssp/config.ini
    sed -i "3s|webapi_key=\"\"|webapi_key=\"${webapi_key}\"|g" /etc/ssp/config.ini
    sed -i "4s|1|${node_id:-1}|g" /etc/ssp/config.ini
    sed -i "7s|poseidon_license=\"\"|poseidon_license=\"${poseidon_license}\"|g" /etc/ssp/config.ini
    sed -i "9s|log_level=\"info\"|log_level=\"${log_level:-info}\"|g" /etc/ssp/config.ini

    colorEcho ${GREEN} "ssp ${NEW_VER} is installed."

    colorEcho ${BLUE} "Starting ssp service."
    stopssp
    startssp

    rm -rf /tmp/ssp
    return 0
}

main
