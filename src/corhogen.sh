#!/usr/bin/env bash

enable_addon() {

    local addonid=${1}
    local enabled=${2}

    # # Enable the webserver
    # local results="$(netstat -an | grep 8080 | grep -i listen)"
    # local present="$(test "$results" -eq "" && echo false || echo true)"
    # test "$present" -eq "false" && enable_webserver

    # Invoke jsonrpc request
    local address="localhost:8080"
    local headers="content-type:application/json"
    local payload="[{'jsonrpc':'2.0','method':'Addons.SetAddonEnabled','params':{'addonid':'$addonid','enabled':'$enabled'},'id':1}]"
    curl "http://$address/jsonrpc" -H "$headers" -d "$payload"

}

enable_webserver() {

    local enabled=${1:-true}
    local secured=${2:-true}
    local webuser=${3:-kodi}
    local webpass=${4:-}

    # Finish kodi application
    systemctl stop kodi

    # Change the settings
    local configs="$HOME/.kodi/userdata/guisettings.xml"
    update_setting "$configs" "//*[@id='services.webserver']" "true"
    update_setting "$configs" "//*[@id='services.webserver']/@default" "false"
    update_setting "$configs" "//*[@id='services.webserverauthentication']" "false"
    update_setting "$configs" "//*[@id='services.webserverauthentication']/@default" "false"

    # Launch kodi application
    systemctl start kodi

}

change_setting() {

    local setting=${1}
    local payload=${2}

    # Invoke jsonrpc request
    local address="localhost:8080"
    local headers="content-type:application/json"
    # local payload='[{"jsonrpc":"2.0","method":"Settings.SetSettingValue","params":["'"$setting"'",'"$payload"'],"id":1}]'
    local payload="[{'jsonrpc':'2.0','method':'Settings.SetSettingValue','params':['$setting','$payload'],'id':1}]"
    curl "http://$address/jsonrpc" -H "$headers" -d "$payload"

}

gather_setting() {

    local xmlfile=${1}
    local pattern=${2}

    # Invoke xmlstarlet command
    xmlstarlet sel -T -v "$pattern" "$xmlfile"

}

update_setting() {

    local xmlfile=${1}
    local pattern=${2}
    local payload=${3}

    # Invoke xmlstarlet command
    xmlstarlet ed -L -u "$pattern" -v "$payload" "$xmlfile"

}

verify_requirements() {

    # Verify the external drive
    deposit="$(find "/var/media" -maxdepth 1 -type d | sort -r | head -1)"
    present="$(test "$deposit" -ne "/var/media" && echo true || echo false)"
    test "$present" -eq "false" && return 1

    # Enable the webserver
    enable_webserver "true" "false"

}

update_docker() {
    return 0
}

update_estuary() {
    return 0
}

update_kodi() {
    return 0
}

update_luna() {
    return 0
}

update_moonlight() {
    return 0
}

update_qbittorrent() {
    return 0
}

update_sources() {

    # Create the directories
    local deposit="$(find "/var/media" -maxdepth 1 -type d | sort -r | head -1)"
    mkdir -p "$deposit/Films"
    mkdir -p "$deposit/Musique"
    mkdir -p "$deposit/Photos"
    mkdir -p "$deposit/Séries"
    mkdir -p "$deposit/Torrents/Incomplets"

    # TODO: Create the sources
    # TODO: Change the settings

}

update_vstream() {

    # Change the settings
    update_setting "addons.unknownsources" "true"
    update_setting "addons.updatemode" "1"

    # Expand the repository
    local address="https://kodi-vstream.github.io/repo/repository.vstream-0.0.6.zip"
    local deposit="$HOME/.kodi/addons"
    kodi-send -a "Extract($address, $deposit)"
    kodi-send -a "RestartApp"

    # Enable the repository
    local addonid="repository.vstream"
    kodi-send -a "InstallAddon($addonid)"
    sleep 2 && kodi-send -a "SendClick(11)"

    # Update the extension
    local addonid="plugin.video.vstream"
    kodi-send -a "InstallAddon($addonid)"

}

update_youtube() {

    local factor1=${1}
    local factor2=${2}
    local factor3=${3}

    # Change the settings
    update_setting "addons.unknownsources" "true"
    update_setting "addons.updatemode" "1"

    # Expand the repository
    local address="http://ftp.fau.de/osmc/osmc/download/dev/anxdpanic/repositories/repository.anxdpanic-2.0.4.zip"
    local deposit="$HOME/.kodi/addons"
    kodi-send -a "Extract($address, $deposit)"
    kodi-send -a "RestartApp"

    # Enable the repository
    local addonid="repository.anxdpanic"
    kodi-send -a "InstallAddon($addonid)"
    sleep 2 && kodi-send -a "SendClick(11)"

    # Update the extension
    local addonid="plugin.video.youtube"
    kodi-send -a "InstallAddon($addonid)"

    # Change the settings
    local deposit="$HOME/.kodi/userdata/addon_data/plugin.video.youtube"
    local apikeys="$deposit/api_keys.json"
    mkdir -p "$deposit" && {
        echo "{"
        echo "    \"keys\": {"
        echo "        \"developer\": {},"
        echo "        \"personal\": {"
        echo "            \"api_key\": \"$factor1\","
        echo "            \"client_id\": \"$factor2\","
        echo "            \"client_secret\": \"$factor3\""
        echo "        }"
        echo "    }"
        echo "}"
    } >"$apikeys"

}

main() {

    enable_webserver

}

main
