#!/usr/bin/env bash

((!DETACHED)) && DETACHED=1 exec setsid --fork "$SHELL" "$0" "$@"

set -eu -o pipefail

: "${ISO_PATH:=/dev/sr0}"

source <(isoinfo -i "$ISO_PATH" -R -x /context.sh)

: "${HYDRA_HOST:=http://$ETH0_IP:3000}"
: "${HYDRA_USER:=admin}"
: "${HYDRA_PASSWORD:=asd}"
: "${HYDRA_PROJECT_ID:=hydra-research}"
: "${HYDRA_FLAKE_URL:=https://github.com/sk4zuzu-nix/hydra-research.git}"

install -o 0 -g 0 -m u=rw,go=r /dev/fd/0 /etc/nixos/configuration.nix.d/01-hydra.nix <<NIX
{ config, pkgs, lib, ... }: {
  nix.settings.experimental-features = "nix-command flakes";
  services.hydra = {
    enable = true;
    hydraURL = "$HYDRA_HOST";
    notificationSender = "hydra@localhost";
    buildMachinesFiles = [];
    useSubstitutes = true;
  };
  networking.hostName = "$SET_HOSTNAME";
}
NIX

nixos-rebuild switch

RETRY=60
while ! sudo -u hydra hydra-create-user "$HYDRA_USER" --password "$HYDRA_PASSWORD" --role admin; do
    ((--RETRY))
    sleep 5
done

RETRY=60
while ! curl -fsSL -H 'Accept: application/json' "$HYDRA_HOST/"; do
    ((--RETRY))
    sleep 5
done

read -r -d "#\n" LOGIN_JSON <<JSON
{
  "username": "$HYDRA_USER",
  "password": "$HYDRA_PASSWORD"
}#
JSON

read -r -d "#\n" PROJECT_JSON <<JSON
{
  "displayname": "$HYDRA_PROJECT_ID",
  "enabled": true,
  "hidden": false,
  "declarative": {
    "type": "git",
    "file": "spec.json",
    "value": "$HYDRA_FLAKE_URL"
  }
}#
JSON

curl --fail-early --show-error \
--silent \
-X POST --referer "$HYDRA_HOST" "$HYDRA_HOST/login" \
--cookie-jar ~/hydra-session \
--json "$LOGIN_JSON" \
-: \
--silent \
-X PUT --referer "$HYDRA_HOST/login" "$HYDRA_HOST/project/$HYDRA_PROJECT_ID" \
--cookie ~/hydra-session \
--json "$PROJECT_JSON"

rm -f ~/hydra-session

sync
