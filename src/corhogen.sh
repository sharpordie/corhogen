#!/usr/bin/env bash
# shellcheck disable=SC2155

attend_addon() {

    local addonid="${1:-plugin.video.vstream}"

    while true; do
        local address='localhost:8080'
        local headers='content-type:application/json'
        # local payload="[{'jsonrpc':'2.0','method':'Addons.GetAddonDetails','params':{'addonid':'$addonid','properties':['name','path','dependencies','broken','enabled','installed']},'id':1}]"
        local payload='[{"jsonrpc":"2.0","method":"Addons.GetAddonDetails","params":{"addonid": "'"$addonid"'", "properties":["name","path","dependencies","broken","enabled","installed"]},"id":1}]'
        local details="$(curl "http://$address/jsonrpc" -H "$headers" -d "$payload")"
        echo "$details"
        # factor1="$(echo "$details" | jq -r '.[0].result.addon.broken' || true)"
        # factor2="$(echo "$details" | jq -r '.[0].result.addon.installed' || true)"
        # factor3="$(echo "$details" | jq -r '.[0].result.addon.enabled' || true)"
        [[ "$factor1" == "false" && "$factor2" == "true" && "$factor3" == "true" ]] && return 0
        sleep 1
    done
    return 1

}

enable_addon() {

    local addonid=${1}
    local enabled=${2}

    # Invoke jsonrpc request
    local address="localhost:8080"
    local headers="content-type:application/json"
    # local payload="[{'jsonrpc':'2.0','method':'Addons.SetAddonEnabled','params':{'addonid':'$addonid','enabled':'$enabled'},'id':1}]"
    local payload='[{"jsonrpc":"2.0","method":"Addons.SetAddonEnabled","params":{"addonid":"'"$addonid"'","enabled":'"$enabled"'},"id":1}]'
    curl "http://$address/jsonrpc" -H "$headers" -d "$payload"

}

enable_webserver() {

    local enabled="${1:-true}"
    local secured="${2:-true}"
    local webuser="${3:-kodi}"
    local webpass="${4:-}"

    # Finish the application
    systemctl stop kodi

    # Change the settings
    local configs="$HOME/.kodi/userdata/guisettings.xml"
    update_setting "$configs" '//*[@id="services.webserver"]' "$enabled"
    update_setting "$configs" '//*[@id="services.webserverauthentication"]' "$secured"
    update_setting "$configs" '//*[@id="services.webserverusername"]' "$webuser"
    update_setting "$configs" '//*[@id="services.webserverpassword"]' "$webpass"

    # Launch the application
    systemctl start kodi && sleep 8

}

# change_setting() { # TODO: REMOVE

#     local setting=${1}
#     local payload=${2}

#     # Invoke jsonrpc request
#     [[ ! "$payload" =~ ^(-?[0-9]+|true|false)$ ]] && local payload='"'"$payload"'"'
#     local address="localhost:8080"
#     local headers='Content-Type: application/json'
#     local payload='[{"jsonrpc":"2.0","method":"Settings.SetSettingValue","params":["'"$setting"'",'"$payload"'],"id":1}]'
#     curl "http://$address/jsonrpc" -H "$headers" -d "$payload" && sleep 1

# }

# gather_setting() {

#     local xmlfile=${1}
#     local pattern=${2}

#     # Invoke xmlstarlet command
#     xmlstarlet sel -T -v "$pattern" "$xmlfile"

# }

update_setting() {

    local xmlfile="${1}"
    local pattern="${2}"
    local payload="${3}"
    local default="${4:-true}"

    # Invoke xmlstarlet commands
    xmlstarlet ed -L -u "$pattern" -v "$payload" "$xmlfile"
    [[ "$default" == 'true' ]] && xmlstarlet ed -L -u "$pattern/@default" -v 'false' "$xmlfile"

}

verify_requirements() {

    # Verify the external drive
    local deposit="$(find "/var/media" -maxdepth 1 -type d | sort -r | head -1)"
    local present="$([[ "$deposit" != "/var/media" ]] && echo "true" || echo "false")"
    [[ "$present" == "false" ]] && return 1

    # Enable the webserver
    enable_webserver "true" "false"

}

update_docker() {
    return 0
}

update_entware() {

    local current="$(dirname "$(readlink -f "$0")")/$(basename "$0")"
    local startup="${HOME}/.config/autostart.sh"

    # Install entware package
    if ! [ -x "$(command -v opkg)" ]; then
        echo "(sleep 10 && /usr/bin/sh $current)&" | tee "$startup"
        installentware
        reboot
        exit 1
    fi

    # Remove autostart script
    rm -f "$startup"

    # Install qbittorrent package
    opkg update && opkg upgrade
    opkg install qbittorrent

}

update_estuary() {

    local configs="$HOME/.kodi/userdata/addon_data/skin.estuary/settings.xml"

    # Finish the application
    systemctl stop kodi

    # Change the settings
    update_setting "$configs" '//*[@id="homemenunofavbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunogamesbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunomoviebutton"]' 'false'
    update_setting "$configs" '//*[@id="homemenunomusicbutton"]' 'false'
    update_setting "$configs" '//*[@id="homemenunomusicvideobutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunopicturesbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunoprogramsbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunoradiobutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunotvbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunotvshowbutton"]' 'false'
    update_setting "$configs" '//*[@id="homemenunovideosbutton"]' 'true'
    update_setting "$configs" '//*[@id="homemenunoweatherbutton"]' 'true'

    # Launch the application
    systemctl start kodi && sleep 8

}

update_kodi() {

    local configs="$HOME/.kodi/userdata/guisettings.xml"

    # Change the language
    local addonid="resource.language.fr_fr"
    kodi-send -a "InstallAddon($addonid)" && sleep 6
    kodi-send -a "SendClick(11)" && sleep 8
    # kodi-send -a "SetGUILanguage($addonid)" && sleep 8
    # kodi-send -a "RestartApp" && sleep 8

    # Finish the application
    systemctl stop kodi

    # Change addon settings
    update_setting "$configs" '//*[@id="addons.unknownsources"]' 'true'
    update_setting "$configs" '//*[@id="addons.updatemode"]' '1'

    # Change audio settings
    update_setting "$configs" '//*[@id="audiooutput.channels"]' '10'
    update_setting "$configs" '//*[@id="audiooutput.dtshdpassthrough"]' 'true'
    update_setting "$configs" '//*[@id="audiooutput.dtspassthrough"]' 'true'
    update_setting "$configs" '//*[@id="audiooutput.eac3passthrough"]' 'true'
    update_setting "$configs" '//*[@id="audiooutput.passthrough"]' 'true'
    update_setting "$configs" '//*[@id="audiooutput.truehdpassthrough"]' 'true'

    # Change file settings
    update_setting "$configs" '//*[@id="filelists.showparentdiritems"]' 'false'

    # Change keyboard settings
    update_setting "$configs" '//*[@id="locale.keyboardlayouts"]' 'French AZERTY'
    update_setting "$configs" '//*[@id="locale.activekeyboardlayout"]' 'French AZERTY'

    # Change library settings
    update_setting "$configs" '//*[@id="videolibrary.backgroundupdate"]' 'true'

    # Change locale settings
    update_setting "$configs" '//*[@id="locale.audiolanguage"]' 'mediadefault'
    update_setting "$configs" '//*[@id="locale.country"]' 'Belgique'
    update_setting "$configs" '//*[@id="locale.language"]' 'resource.language.fr_fr'
    update_setting "$configs" '//*[@id="locale.subtitlelanguage"]' 'forced_only'

    # Change video settings
    update_setting "$configs" '//*[@id="videoplayer.adjustrefreshrate"]' '2'
    update_setting "$configs" '//*[@id="videoscreen.delayrefreshchange"]' '35'

    # Change viewstates settings
    update_setting "$configs" '/settings/viewstates/videonavtitles/sortattributes' '0' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtitles/sortmethod' '40' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtitles/sortorder' '2' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtitles/viewmode' '131123' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtvshows/sortattributes' '0' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtvshows/sortmethod' '40' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtvshows/sortorder' '2' 'false'
    update_setting "$configs" '/settings/viewstates/videonavtvshows/viewmode' '131123' 'false'

    # Launch the application
    systemctl start kodi && sleep 8

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

    # Finish kodi application
    systemctl stop kodi

    # Create the sources
    local sources="$HOME/.kodi/userdata/sources.xml"
    {
        echo '<sources>'
        echo '    <programs>'
        echo '        <default pathversion="1"></default>'
        echo '    </programs>'
        echo '    <video>'
        echo '        <default pathversion="1"></default>'
        echo '        <source>'
        echo '            <name>Films</name>'
        echo "            <path pathversion=\"1\">$deposit/Films/</path>"
        echo '            <allowsharing>true</allowsharing>'
        echo '        </source>'
        echo '        <source>'
        echo '            <name>Séries</name>'
        echo "            <path pathversion=\"1\">$deposit/Séries/</path>"
        echo '            <allowsharing>true</allowsharing>'
        echo '        </source>'
        echo '    </video>'
        echo '    <music>'
        echo '        <default pathversion="1"></default>'
        echo '        <source>'
        echo '            <name>Musique</name>'
        echo "            <path pathversion=\"1\">$deposit/Musique/</path>"
        echo '            <allowsharing>true</allowsharing>'
        echo '        </source>'
        echo '    </music>'
        echo '    <pictures>'
        echo '        <default pathversion="1"></default>'
        echo '        <source>'
        echo '            <name>Photos</name>'
        echo "            <path pathversion=\"1\">$deposit/Photos/</path>"
        echo '            <allowsharing>true</allowsharing>'
        echo '        </source>'
        echo '    </pictures>'
        echo '    <files>'
        echo '        <default pathversion="1"></default>'
        echo '    </files>'
        echo '    <games>'
        echo '        <default pathversion="1"></default>'
        echo '    </games>'
        echo '</sources>'
    } >"$sources"

    # Launch kodi application
    systemctl start kodi && sleep 8

    # TODO: Change the settings

}

update_vstream() {

    # Expand the repository
    local address="https://kodi-vstream.github.io/repo/repository.vstream-0.0.6.zip"
    local deposit="$HOME/.kodi/addons"
    kodi-send -a "Extract($address, $deposit)" && sleep 4
    enable_addon "repository.vstream" "true" && sleep 4

    # Enable the repository
    local addonid="repository.vstream"
    kodi-send -a "InstallAddon($addonid)" && sleep 12
    kodi-send -a "SendClick(11)" && sleep 8

    # Update the extension
    local addonid="plugin.video.vstream"
    kodi-send -a "InstallAddon($addonid)" && sleep 2
    kodi-send -a "SendClick(11)" && sleep 8

}

update_youtube() {

    local factor1=${1}
    local factor2=${2}
    local factor3=${3}

    # Expand the repository
    local address="http://ftp.fau.de/osmc/osmc/download/dev/anxdpanic/repositories/repository.anxdpanic-2.0.4.zip"
    local deposit="$HOME/.kodi/addons"
    kodi-send -a "Extract($address, $deposit)"
    kodi-send -a "RestartApp"

    # Enable the repository
    local addonid="repository.anxdpanic"
    kodi-send -a "InstallAddon($addonid)" && sleep 2
    kodi-send -a "SendClick(11)"

    # Update the extension
    local addonid="plugin.video.youtube"
    kodi-send -a "InstallAddon($addonid)" && sleep 2

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

    update_entware

    # verify_requirements || return 1
    # update_kodi
    # update_estuary
    # update_sources
    # # update_youtube "" "" ""
    # update_vstream

}

main
