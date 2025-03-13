#!/usr/bin/with-contenv bashio
# ==============================================================================
# Configures Asterisk
# ==============================================================================

# shellcheck shell=bash

function is_addon() {
    [[ -n "${SUPERVISOR_TOKEN:-}" ]]
}

if is_addon; then
    readonly ha_url="http://supervisor/core"

    if [[ ! -d /config/asterisk && -d /homeassistant/asterisk ]]; then
        bashio::log.info "Migrating Asterisk files out of Home Assistant config directory..."
        mv -fv /homeassistant/asterisk /config/ || bashio::exit.nok "Failed to move Asterisk files out of Home Assistant config directory"
    fi
else
    readonly default_ha_url="http://homeassistant.local:8123"
    readonly ha_url="${HA_URL:-"${default_ha_url}"}"

    readonly addon_config_path="/config/config.json"
    readonly default_addon_config_path="/etc/asterisk-addon/default_config.json"
    if [[ -f "${addon_config_path}" ]]; then
        addon_config=$(
            jq --slurp 'reduce .[] as $item ({}; . * $item)' "${default_addon_config_path}" "${addon_config_path}"
        )
    else
        addon_config=$(cat "${default_addon_config_path}")
    fi

    # Overrides calling the Supervisor API on bashio::config calls
    function bashio::addon.config() {
        echo "${addon_config}"
    }
fi
readonly ha_token="${HA_TOKEN:-"${SUPERVISOR_TOKEN:-}"}"

readonly etc_asterisk="/etc/asterisk"
readonly config_dir="/config"
readonly default_config_dir="${config_dir}/default"
readonly custom_config_dir="${config_dir}/custom"

readonly tempio_dir="/usr/share/tempio"

# Ensure the config folders exist
if ! mkdir -p "${default_config_dir}" "${custom_config_dir}"; then
    bashio::exit.nok "Failed to create Asterisk config folders at ${config_dir}"
fi

# Needed for google-tts cache, speech-recog cache, and mbox cache
readonly cache_dir="/data/tmp"
# Ensure the cache folder exists
if ! mkdir -p "${cache_dir}"; then
    bashio::exit.nok "Failed to create Asterisk cache folder at ${cache_dir}"
fi

bashio::log.info "Configuring certificate..."
certfile_config=$(bashio::config 'certfile')
keyfile_config=$(bashio::config 'keyfile')
if [[ "${certfile_config}" == /* ]]; then
    certfile="${certfile_config}"
else
    certfile="/ssl/${certfile_config}"
fi
if [[ "${keyfile_config}" == /* ]]; then
    keyfile="${keyfile_config}"
else
    keyfile="/ssl/${keyfile_config}"
fi
unset certfile_config keyfile_config
readonly certfile keyfile

readonly keys_dir="${etc_asterisk}/keys"
readonly target_certfile="${keys_dir}/fullchain.pem"
readonly target_keyfile="${keys_dir}/privkey.pem"

mkdir -p "${keys_dir}"

if bashio::var.true "$(bashio::config 'generate_ssl_cert')"; then
    bashio::log.info "Generating a self-signed certificate..."

    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=NL/ST=Denial/L=Amsterdam/O=Dis/CN=Asterisk" \
        -keyout "${target_keyfile}" -out "${target_certfile}" >/dev/null
else
    bashio::log.info "Using existing certificate as 'generate_ssl_certificate' is disabled..."

    if ! bashio::fs.file_exists "${certfile}"; then
        bashio::exit.nok "Certificate file at ${certfile} was not found"
    fi

    if ! bashio::fs.file_exists "${keyfile}"; then
        bashio::exit.nok "Key file at ${keyfile} was not found"
    fi

    cp -f "${certfile}" "${target_certfile}"
    cp -f "${keyfile}" "${target_keyfile}"
fi

cat "${target_keyfile}" <(echo) "${target_certfile}" >${keys_dir}/asterisk.pem
chmod 600 "${keys_dir}"/*.pem

bashio::log.info "Generating Asterisk config files from add-on configuration..."

if bashio::config.is_empty 'ami_password'; then
    bashio::exit.nok "'ami_password' must be set"
fi

# deleting the target before writing to it ensures we don't write to a
# symlinked file, like when the container is restarted
rm -f "${etc_asterisk}/manager.conf"
bashio::var.json \
    password "$(bashio::config 'ami_password')" |
    tempio \
        -template "${tempio_dir}/manager.conf.gtpl" \
        -out "${etc_asterisk}/manager.conf"

rm -f "${etc_asterisk}/logger.conf"
bashio::var.json \
    log_level "$(bashio::config 'log_level')" |
    tempio \
        -template "${tempio_dir}/logger.conf.gtpl" \
        -out "${etc_asterisk}/logger.conf"

rm -f "${etc_asterisk}/http.conf"
bashio::var.json \
    certfile "${target_certfile}" \
    keyfile "${target_keyfile}" |
    tempio \
        -template "${tempio_dir}/http.conf.gtpl" \
        -out "${etc_asterisk}/http.conf"

auto_add=$(bashio::config 'auto_add')
auto_add_secret=$(bashio::config 'auto_add_secret')
video_support=$(bashio::config 'video_support')

# If `auto_add` is enabled, retrieve the list of persons using the Home Assistant API
if bashio::var.true "${auto_add}"; then
    if bashio::config.is_empty 'auto_add_secret'; then
        bashio::exit.nok "'auto_add_secret' must be set when 'auto_add' is enabled"
    fi

    bashio::log.info "Retrieving the list of persons from Home Assistant"
    if ! is_addon && bashio::var.is_empty "${ha_token}"; then
        message="Please define the HA_TOKEN env variable with a long-lived Home Assistant access token so the container can get the list of persons from Home Assistant."
        if [[ -z "${HA_URL:-}" ]]; then
            message="${message} Optionally, you can also define the HA_URL env variable to point to your Home Assistant URL if it differs from ${default_ha_url}."
        fi
        bashio::exit.nok "${message}"
    fi
    persons=$(
        curl -fsSL -X GET \
            -H "Authorization: Bearer ${ha_token}" \
            -H "Content-Type: application/json" \
            "${ha_url}/api/states" |
            jq -c '[.[] | select(.entity_id | contains("person.")).attributes.friendly_name]'
    )
else
    # Define an empty array, so the subsequent template won't complain
    persons=[]
fi

rm -f "${etc_asterisk}/pjsip_default.conf"
bashio::var.json \
    auto_add "^${auto_add}" \
    auto_add_secret "${auto_add_secret}" \
    video_support "^${video_support}" \
    persons "^${persons}" |
    tempio \
        -template "${tempio_dir}/pjsip_default.conf.gtpl" \
        -out "${etc_asterisk}/pjsip_default.conf"

rm -f "${etc_asterisk}/asterisk_mbox.ini"
bashio::var.json \
    port "$(bashio::config 'mailbox_port')" \
    password "$(bashio::config 'mailbox_password')" \
    extension "$(bashio::config 'mailbox_extension')" \
    api_key "$(bashio::config 'mailbox_google_api_key')" |
    tempio \
        -template "${tempio_dir}/asterisk_mbox.ini.gtpl" \
        -out "${etc_asterisk}/asterisk_mbox.ini"

if bashio::var.true "$(bashio::config 'mailbox')"; then
    mkdir -p /media/asterisk
else
    touch /tmp/disable-asterisk-mailbox
fi

# Save default configs
bashio::log.info "Saving default configs to ${default_config_dir}..."
if ! rsync --archive --delete "${etc_asterisk}/" "${default_config_dir}/"; then
    bashio::exit.nok "Failed to copy default configs to ${default_config_dir}"
fi

# Restore custom configs
bashio::log.info "Restoring custom configs from ${custom_config_dir}..."
for file in "${custom_config_dir}"/*; do
    rel_file="$(basename "${file}")"
    ln -svf "${custom_config_dir}/${rel_file}" "${etc_asterisk}/${rel_file}"
done

# TODO: open issue in Bashio for set +e
readarray -t additional_sounds < <(set +e && bashio::config 'additional_sounds')

temp_dir="/tmp/sounds_download"
for sound in "${additional_sounds[@]}"; do
    sound_rel_dir="sounds/${sound//-/_}"
    sound_dir="/media/asterisk/${sound_rel_dir}"
    asterisk_sound_dir="/var/lib/asterisk/${sound_rel_dir}"
    lang_file="${sound_dir}/.language"

    if [[ -f "${lang_file}" && "$(cat "${lang_file}")" == "${sound}" ]]; then
        bashio::log.info "Skipping sounds download for '${sound}'..."
    else
        bashio::log.info "Downloading '${sound}' sounds to '${sound_dir}'..."

        bashio::log.info "Ensuring '${sound_dir}' is clean..."
        rm -rf "${sound_dir}"
        mkdir -p "${sound_dir}" "${temp_dir}"

        cd "${temp_dir}" || exit 1

        url="https://www.asterisksounds.org/${sound,,}/download/asterisk-sounds-extra-${sound}-sln16.zip"
        bashio::log.info "Downloading ${url}..."
        curl -fsSL --output extra.zip "${url}"
        unzip -q extra.zip
        rm -f extra.zip

        url="https://www.asterisksounds.org/${sound,,}/download/asterisk-sounds-core-${sound}-sln16.zip"
        bashio::log.info "Downloading ${url}..."
        curl -fsSL --output core.zip "${url}"
        unzip -q -o core.zip
        rm -f core.zip

        bashio::log.info "Converting sounds for '${sound}' (this can take a while)..."
        readarray -d $'\0' -t files < <(find . -type f -name "*.sln16" -print0)
        for file in "${files[@]}"; do
            file_without_ext="${file%".sln16"}"
            sox -t raw -e signed-integer -b 16 -c 1 -r 16k "${file}" -t gsm -r 8k "${file_without_ext}.gsm"
            sox -t raw -e signed-integer -b 16 -c 1 -r 16k "${file}" -t raw -r 8k -e a-law "${file_without_ext}.alaw"
            sox -t raw -e signed-integer -b 16 -c 1 -r 16k "${file}" -t raw -r 8k -e mu-law "${file_without_ext}.ulaw"
        done

        cd - >/dev/null || exit 1

        chmod 0755 -R "${temp_dir}"
        rsync -a "${temp_dir}/" "${sound_dir}/"
        rm -rf "${temp_dir}"
    fi
    rm -rf "${asterisk_sound_dir}"
    ln -svf "${sound_dir}" "${asterisk_sound_dir}"
done
