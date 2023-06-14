# Factorio Auto Update Scripts
This set of scripts automates the update process for Factorio and mods on linux using bash scripts.
These scripts use the Factorio mod and version API to determine if you are currently running the latest version of Factorio and each mode.

The mod update script tries to take into account dependency checking of the base game, to ensure you don't have issues if a mod has been updated for an experimental version, while you are still using stable for example. This dependency check is non-exhaustive.

## Prerequisites
This bash script library requires `jq` be installed. You can install it on Ubuntu using the following command.
```bash
sudo apt-get update && apt-get install jq
```

This setup guide will assume your Factorio is/will be installed in `/opt/factorio` you should change the service and other parameters accordingly if your's will be install elsewhere.

## Setup
It is not required to have already installed Factorio to use this script, if you have not installed Factorio yet, the script can be used to auto download and install Factorio for you.

## Copy scripts and setup set permissions

Copy the `updateFactorio.sh`, `updateMods.sh`, and `updateFunctions.sh` to the root of your Factorio folder, eg `/op/factorio`. _Ensure these scripts have execute permissions._

## Setup factorio.service

[This](./factorio.service) is an example systemd service file you can use to make Factorio auto start and update.
You'll want to place this service in `/etc/systemd/system/factorio.service`.

If you haven't created a service yet and want to just copy/paste the contents into Terminal you can use the following command to create it.
```shell
sudo nano /etc/systemd/system/factorio.service
```


Setting the `WorkingDirectory` is important for the scripts to be able to work.
```shell
...
WorkingDirectory=/opt/factorio
ExecStartPre=/opt/factorio/updateFactorio.sh
ExecStartPre=/opt/factorio/updateMods.sh --server-settings "/opt/factorio/data/saves/YourSaveGame.json" --basePath "/opt/factorio"
ExecStart=/opt/factorio/bin/x64/factorio --start-server "/opt/factorio/data/saves/YourSaveGame.zip" --server-settings "/opt/factorio/data/saves/YourSaveGame.json"
...
```

Make sure the service is enabled so you can start it later and allow it to auto start on system reboot.
```shell
sudo systemctl enable factorio
```

Other helpful commands
* Show the output from your factorio service
```shell
sudo journalctl -f -u factorio --since "30 minutes ago"
```
* Start/Stop the service
```shell
sudo systemctl start factorio
```
```shell
sudo systemctl status factorio
```
## 