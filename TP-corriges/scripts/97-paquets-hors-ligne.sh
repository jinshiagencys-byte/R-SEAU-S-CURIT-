#!/usr/bin/env bash
# ---------------------------------------------------------------
# Prépare le TP pour une salle SANS Internet.
#
#   ÉTAPE 1 — à la maison, sur une Ubuntu 24.04 AVEC Internet :
#       bash 97-paquets-hors-ligne.sh
#       → crée ./paquets-tp/ avec tous les .deb
#       → copier ce dossier sur une clé USB (ou le laisser sur le disque)
#
#   ÉTAPE 2 — en salle, sans Internet :
#       sudo apt install ./paquets-tp/*.deb
#       (apt résout les dépendances entre les fichiers locaux, sans réseau)
#
# Le script télécharge l'union des paquets de SRV1 et SRV2.
# ---------------------------------------------------------------

set -u

DEST="${1:-$PWD/paquets-tp}"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

PKGS_SRV1="bind9 bind9utils bind9-dnsutils nfs-common dnsutils net-tools git curl openssl"
PKGS_SRV2="apache2 vsftpd samba samba-client cifs-utils nfs-kernel-server nfs-common dnsutils net-tools curl git openssl"

TOUS="$(printf '%s\n%s\n' "$PKGS_SRV1" "$PKGS_SRV2" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')"

echo "Distribution : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Dossier      : $DEST"
echo "Paquets      : $TOUS"
echo

sudo apt-get update || { echo "Pas d'Internet : ce script doit tourner sur une machine connectée." >&2; exit 1; }

echo "== Téléchargement (cela peut prendre quelques minutes) =="
# --reinstall : force le téléchargement même si le paquet est déjà installé
sudo apt-get install --download-only --reinstall -y \
     -o Dir::Cache::archives="$DEST" $TOUS

# certains .deb atterrissent dans un sous-dossier partial/
find "$DEST" -mindepth 2 -name '*.deb' -exec mv -n {} "$DEST/" \; 2>/dev/null
rmdir "$DEST/partial" 2>/dev/null || true
sudo chown "$(id -u):$(id -g)" "$DEST"/*.deb 2>/dev/null || true

NB=$(ls -1 "$DEST"/*.deb 2>/dev/null | wc -l)
echo
echo "────────────────────────────────────────────"
echo "$NB fichiers .deb téléchargés"
du -sh "$DEST" 2>/dev/null
echo "────────────────────────────────────────────"
echo
echo "En salle, sans Internet :"
echo "  sudo apt install $DEST/*.deb"
echo
echo "Puis vérifier :"
echo "  dpkg -l bind9 apache2 vsftpd samba nfs-kernel-server nfs-common | grep ^ii"
