<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

# Changelog

## 5.1.1

- Enable HAOS Ingress

## 5.1.0

### Breaking Changes

- Migrate Asterisk files out of Home Assistant config directory
  - This ensures the add-on backup and restore includes the Asterisk files
  - Apart from the automatic migration, if your Asterisk files refer to files in the Home Assistant config dir, like scripts, their references must be **manually changed** from `/config/` to `/homeassistant/`.

    Note: this breaking change was realized after 5.1.0 was initially released. Otherwise, this release would have been 6.0.0.

### Upgrades

- Upgrade Asterisk from 22.1.0 to 22.2.0
- Upgrade debian-base from 7.6.2 to 7.7.1

## 5.0.0

### Breaking Changes

- `chan_sip` was [removed](https://docs.asterisk.org/Configuration/Channel-Drivers/SIP/Configuring-chan_sip/) in Asterisk 21, thus it is no longer supported by this add-on.
  You should [migrate](https://docs.asterisk.org/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/Migrating-from-chan_sip-to-res_pjsip/) to `res_pjsip` if you were using `chan_sip`.

### Upgrades

- Upgrade Asterisk from 20.8.1 to 22.1.0
- Upgrade debian-base from 7.4.0 to 7.6.2

## 4.4.0

### New Features

- Add custom startup script support

## 4.3.0

### Improvements

- Prefer Opus over other codecs (by @OnFreund at #331)

### Upgrades

- Upgrade Asterisk from 20.6.0 to 20.8.1
- Upgrade debian-base from 7.3.3 to 7.3.4

## 4.2.1

### Bug Fixes

- Use `friendly_name` instead of `id` as caller id (by @OnFreund at #322)
- Fix `/config/asterisk/custom` files being overwritten on container restart (by @felipecrs at #323, fixes #309)
  - PS: this bug did not affect people running the add-on with Home Assistant Supervisor, only for people running the add-on as a standalone docker container.

## 4.2.0

### New Features

- Include `app_rtsp_sip` in ARM builds

### Upgrades

- Upgrade Asterisk from 20.5.2 to 20.6.0
- Upgrade asterisk-chan-dongle to latest revision
- Upgrade asterisk-googletts to latest revision

## 4.1.2

### Upgrades

- Upgrade Asterisk from 20.4.0 to 20.5.2
- Upgrade hassio-addons/debian-base from 7.0.1 to 7.1.0

## 4.1.1

- Fix missing `libunbound8` library for `res_resolver_unbound`

## 4.1.0

### New Features

- Add `res_resolver_unbound` module, which allows to change the DNS server for Asterisk. Example:

  ```ini
  ; /config/asterisk/custom/resolver_unbound.conf

  [general]
  nameserver = 127.0.0.1
  resolv =
  ```

### Bug Fixes

- Fix Asterisk Mailbox Server missing `lame`
- Ensure Asterisk Mailbox Server is started with `--verbose` if log level is debug or higher
- Fix Asterisk Mailbox Server media directory to `/media/asterisk/voicemail/default/<mailbox-extension>/` for persistency
- Fix Asterisk Mailbox Server cache file to `/data/tmp` for persistency
- Fix to the `/data` directory (and also `/media` when needed) are created on startup, useful when running the add-on as a standalone docker container
- Fix the permissions of downloaded sounds to be `0755` to be as indicated by <https://asterisksounds.org>, although on my tests it was working before as well.

### Upgrades

- Upgrade hassio-addons/debian-base from 6.2.7 to 7.0.1
  - This upgrades Debian 11 to Debian 12
- Upgrade Asterisk from 20.2.1 to 20.4.0

## 4.0.4

- Update asterisk_mbox_server
- Added IPv6 support
- Patch upstream asterisk issue

## 4.0.3

- Upgrade Asterisk from 20.2.0 to 20.2.1
- Upgrade debian-base from 6.2.3 to 6.2.5

## 4.0.2

- Fix add-on not starting for ARM users

## 4.0.1

- Fix `auto_add_secret` validation always failing as if it was net set

## 4.0.0

### Breaking Changes

Some default options for the add-on configuration have been switched:

- `generate_ssl_cert` is now enabled by default.
- `video_support` is now disabled by default. It barely worked anyway.

Make sure to check the add-on configuration page after updating the add-on to ensure your configuration is still correct.

### New Features

Now the add-on can be run as a standalone docker container:

```console
docker pull ghcr.io/tech7fox/asterisk-hass-addon:4.0.0
```

- An example `docker-compose.yml` file is available [here](../docker-compose.yaml).
- Make sure to mount a `config` folder to `/config` and a `media` folder to `/media` to ensure the add-on can access your configuration and media files.
- To configure the add-on options you can use the `/config/config.json` file. The default options can be seen [here](./rootfs/usr/share/asterisk/config.json).
- If you enable `auto_add` to automatically create extensions for every Person in your Home Assistant, make sure to also set:
  - The `HA_TOKEN` environment variable with your Home Assistant long-lived access token
  - The `HA_URL`, unless <https://homeassistant.local:8123> resolves to your Home Assistant instance

Also, you can now use absolute paths in the `certfile` and `keyfile` options.

### Cleanups

The add-on no longer sends discovery information for the Asterisk integration in Home Assistant. This never worked anyway, and if in the future it does, we can restore it.

## 3.2.0

### New Features

There is now a new option for the add-on: _Additional Sounds Languages to Download_.

With this option, you can specify a list of languages to download sounds from <https://www.asterisksounds.org/> on the add-on startup.

These sounds will be downloaded to `/media/asterisk`, and the add-on will not download the sounds in case they were downloaded already.

These sounds will be available to use in Asterisk by changing the language as you would do normally. For example, you can put `pt-BR` in the list of additional sounds to download, and then change the Asterisk configuration to use `pt_BR` as language.

Finally, now the add-on is able to access files on `/media`, which means you can store your custom music and sounds there, and then refer to them in the Asterisk configuration files.

### Changes

All the available options will now appear in the add-on configuration page without having to click in _Show unused options_, which was an actually misleading name.

Also, the default log level is now _INFO_ instead of _NOTICE_, which increases the logging a little bit.

## 3.1.0

### New Features

- The add-on now supports the `hassio.stdin` Home Assistant service to execute any Asterisk CLI commands. For example, to reload changes from `/config/asterisk/custom/extensions.conf`:

  ```yaml
  service: hassio.addon_stdin
    data:
      addon: b35499aa_asterisk
      input: dialplan reload
  ```

  This means that you can now use the full power of Asterisk CLI right from your Home Assistant automations!

### Changes

- Use symbolic links to map custom Asterisk config files

  - Previously, the custom Asterisk config files would be copied over the default files on container startup
  - With the new approach, for example, the Asterisk CLI command to reload extensions after changing the `/config/asterisk/custom/extensions.conf` will work without requiring to restart the whole add-on.

## 3.0.2

- Fix `asterisk_mbox.ini` configuration again

## 3.0.1

- Fix `asterisk_mbox.ini` configuration

## 3.0.0

### Breaking Changes

We changed the way we handle the Asterisk config files and this will require a manual action on your side. Now, Asterisk files you intend to modify should be placed under `/config/asterisk/custom`. For example, if you were previously editing `extensions.conf`, you should move it from `/config/asterisk/extensions.conf` to `/config/asterisk/custom/extensions.conf`.

After moving all the files you need to `/config/asterisk/custom`, you can also cleanup the `/config/asterisk` folder by deleting everything under it, **except for the `custom` folder**.

### New Features

Previously, both the default and custom Asterisk config files were being written and read from `/config/asterisk`, which posed some issues related to upgrading the add-on as the config files written by an old version of the add-on would get read by the new version of the add-on as if they were user customized files. This also meant that, if users wanted to receive the new Asterisk default config files, they would have to delete everything from `/config/asterisk` that was not customized manually before starting the container.

This is no longer required, and now default files will be always upgraded, while still retaining custom files between upgrades. This will require a manual action from you if you are upgrading this add-on from previous versions, see above.

- The default Asterisk config files are now copied to `/config/asterisk/default` on every container start. The files on this folder should be used for reference only, as any changes made in this folder will be overwritten in the container startup.
- The custom Asterisk config files are now read from `/config/asterisk/custom` instead of from `/config/asterisk`.
- You can now override/customize any Asterisk files (previously, the auto-generated Asterisk files could not be overriden).

### Upgrades

- Bump Asterisk from 20.1.0 to 20.2.0
- Bump debian-base from 6.2.0 to 6.2.3

## 2.4.0

- Add `chan_sip` (disabled by default) for Dahua VTO compatibility (by @bdherouville)

### Breaking changes

**Delete the old `sip.conf` and `modules.conf`.** This disables `chan_sip` by default and sets it on another port to prevent conflicts with `pjsip`.

## 2.3.5

- Upgrade Asterisk from 20.0.1 to 20.1.0 (by @felipecrs)
- Fix tmp dir for googletts and speech-recog (by @felipecrs)
  - Now they use `/data/tmp` instead of `tmp`, which is retained between restarts (but deleted upon uninstall) for add-ons.
- Refactor the installation of all patches for easier maintenance (by @felipecrs)

## 2.3.4

- Upgrade Asterisk from 18.15.0 to 20.0.1 (by @felipecrs)
- Upgrade addon-debian-base from 6.1.3 to 6.2.0 (by @felipecrs)

## 2.3.3

- Fix add-on failing to start sometimes (by @felipecrs)
- Upgrade Asterisk from 18.14.0 to 18.15.0 (by @felipecrs)
- Upgrade addon-debian-base from 6.1.1 to 6.1.3 (by @felipecrs)
- Upgrade asterisk-chan-dongle to [503dba8](https://github.com/wdoekes/asterisk-chan-dongle/commit/503dba87d726854b74b49e70679e64e6e86d5812) (by @felipecrs)

## 2.3.2

- Upgrade Asterisk from 18.12.1 to 18.14.0 (by @felipecrs)
- Upgrade addon-debian-base from 6.0.0 to 6.1.1 (by @felipecrs)

## 2.3.1

- Only include rtsp-sip for amd64 and i386 (by @TECH7Fox)

## 2.3.0

- Add php (by @TECH7Fox)
- Add rtsp-sip (by @TECH7Fox)
- Update builder and linter (by @felipecrs)

## 2.2.0

- Add pt-BR translations (by @LeandroIssa)
- Upgrade addon-base from 5.3.0 to 6.0.0 (by @felipecrs)
- Upgrade Asterisk from 18.10.1 to 18.12.1 (by @felipecrs)

## 2.1.5

- Fix domain bug that makes the WS contacts unreachable (by @TECH7Fox)

## 2.1.4

- Increase maximum possible number of SDP formats (#140) (by @nanosonde)

## 2.1.3

- Fix TLS transport
- Set NAT settings
- Include default STUN server

## 2.1.2

- Fix timezone
- Disable qualify for the generated pjsip extensions, because it wasn't used and caused problems

## 2.1.1

- Do not load chan-dongle by default (because it seems to cause lots of errors and warnings when there is no dongle attached)
  - You have to delete the `/config/asterisk/modules.conf` file so that the new one which
    has disabled chan-dongle can be created.

## 2.1.0

- Add [asterisk-chan-dongle](https://github.com/wdoekes/asterisk-chan-dongle)
- Add [asterisk-googletts](https://github.com/zaf/asterisk-googletts)
- Add [asterisk-speech-recog](https://github.com/zaf/asterisk-speech-recog)
- Run Asterisk as root (instead of as asterisk), this is requires so that chan-dongle can properly communicate with the dongle
- Tidy up some minor things

More information at #124.

## 2.0.2

- Fix Asterisk never starting after starting the addon (again, but for a different reason this time)

## 2.0.1

- Fix Asterisk never starting after starting the addon, which started to happen after [v2.0.0](#200) (issue #127, pr #128)

## 2.0.0

- Change base from Alpine to Debian (#116) (by @nanosonde)
  - Addon size has been considerable increased
- Upgrade Asterisk to 18.1.0 (#116) (by @nanosonde)
  - Now we build it from source, so we can always use the latest version and have more control about it
- Migrate from `chan_sip` to `res_pjsip` (#112) (by @nanosonde)
  - This is a breaking change. Check below the upgrade guide.

Lots of issues were fixed by the above.

### Upgrade guide

It's strongly recommended to erase your existing Asterisk configuration before upgrading.

1. Move any customization you have done in `/config/asterisk/` to somewhere else.
2. Delete the `/config/asterisk` folder.
3. Restore your customizations to the `/config/asterisk` folder if you have any.
4. Make sure to convert your extensions from `chan_sip` to `res_pjsip` if you have any.

Then, you can go ahead and upgrade. Next time you start the addon, it will recreate the files at `/config/asterisk`.

## 1.3.3

- Include hint settings and add busylevel to auto generated extensions.

## 1.3.2

- Fix verbose and debug log levels

## 1.3.1

- Add `log_level` option

## 1.3.0

- Remove the initial Ingress support added in 1.2.0.
  - Ingress will not be needed to make the integration and the card work without having to export additional ports or configuring additional reverse proxies (details [here](https://github.com/dermotduffy/frigate-hass-card/issues/331#issuecomment-1043671490)).
- Remove the option to disable SSL (#98)
  - Disabling SSL causes the HA-SIP card not to work anymore.
- Add an option to automatically generate a self-signed certificate (#98)
  - So that, users running Asterisk behind a reverse proxy do not need to bother about managing their own certificate to be used by Asterisk. You can directly proxy `https://<ha-ip>:8089`.

## 1.2.1

- Disable WS protocol wrongly introduced in 1.2.0 which caused issues

## 1.2.0

- Add an option to disable SSL (#66)
  - Useful for setting up Asterisk to work behind a reverse proxy like NGINX. Here is one example on how to configure NGINX to proxy the Asterisk WebSockets interface: https://warlord0blog.wordpress.com/2020/04/16/asterisk-webrtc/
  - PS: This was not tested, so any feedback is welcome.
- Add initial support for Ingress (#57)
  - Work is still required from other components like the integration and the card to effectively be able to use it.
  - Note that the WebUI shown in the addon page is not a GUI page, but rather the WebSocket connection needed by SIP.JS to connect to the SIP server.
- Fix mailbox server not working (#92)
- Disable docker builtin init, to prevent multiple init systems as we already have S6 Overlay (#89)

## 1.1.5

- Fix permission denied error in discovery service (#85)

## 1.1.4

- Send out discovery information.

## 1.1.3

- Add `host` and `port` to discovery.

## 1.1.2

- Optimize when mailbox service is disabled [#80](https://github.com/TECH7Fox/asterisk-hass-addons/pull/80)

## 1.1.1

- Fix translations

## 1.1.0

- Add mailbox server [#68](https://github.com/TECH7Fox/asterisk-hass-addons/pull/68). To use with the Asterisk Mailbox Integration.
- Add discovery for the [Asterisk Integration](https://github.com/TECH7Fox/Asterisk-integration).
- Allow to customize `logging.conf`.

## 1.0.0

- Use parking instead of conference.
- Remove default passwords.
- Update config and docs.

## 0.3.4

- Add default conference room [#54](https://github.com/TECH7Fox/asterisk-hass-addons/pull/54). Now you can join a conference room via 444 (for default user) or 555 (for admin user). This is useful for things like doorbells.
- Add music-on-hold. (moh)

## 0.3.3

- Add video support [#39](https://github.com/TECH7Fox/asterisk-hass-addons/pull/39). This feature comes disabled by default as otherwise the SIP Lovelace Card does not work in the companion app.
- Fix AMI permit. Now use `localhost` as host in the Asterisk integration.
- Add auto_add_secret option [#50](https://github.com/TECH7Fox/asterisk-hass-addons/pull/50). This option is to prevent having a default secret for the auto-added extensions.

## 0.3.2

- Allow custom configs using `/config/asterisk/sip_custom.conf`
- Fix `_displayName` errors from SIP Lovelace Card

## 0.3.1

- Use prebuilt images for faster installation
- Use S6 Overlay to manage the Asterisk service

## 0.3.0 and below

Check the commit history.
