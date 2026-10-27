#!/usr/bin/env bash
# ---------------------------------------------------------------
# Collecte : produit UN bloc de texte prêt à coller dans une Issue
# GitHub (ou dans le groupe). Chaque machine le lance quand elle a
# terminé une phase, ou quand elle est bloquée.
#
#   bash 90-collecte.sh            → tout
#   bash 90-collecte.sh "SRV2"     → étiquette le rapport
#
# Aucune donnée sensible : ni mot de passe, ni token.
# ---------------------------------------------------------------

set -u

ETIQUETTE="${1:-$(hostname -s 2>/dev/null || echo machine)}"
SEP="────────────────────────────────────────"

ligne() { printf '%s\n' "$@"; }

ligne "### RAPPORT TP — ${ETIQUETTE} — $(date '+%Y-%m-%d %H:%M')"
ligne ""
ligne "*Système*"
ligne "- hostname -f : $(hostname -f 2>/dev/null || echo '(échec)')"
ligne "- OS          : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -srm)"
ligne "- noyau       : $(uname -r)"
ligne ""

ligne "*Réseau*"
ligne '```'
ip -4 -o addr show 2>/dev/null | grep -v ' lo ' || true
ligne "--- route ---"
ip route 2>/dev/null || true
ligne "--- resolv.conf ---"
(grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$') || echo "(absent)"
ligne '```'
ligne ""

ligne "*Profil NetworkManager actif*"
ligne '```'
(nmcli -g NAME,UUID,TYPE connection show --active 2>/dev/null \
    | grep ':802-11-wireless$') || echo "(pas de Wi-Fi / nmcli absent)"
ligne '```'
ligne ""

ligne "*Connectivité*"
ligne '```'
for cible in 192.168.137.1 192.168.137.10 192.168.137.20 8.8.8.8; do
    if ping -c1 -W2 "$cible" >/dev/null 2>&1; then
        ligne "ping ${cible} : OK"
    else
        ligne "ping ${cible} : ECHEC"
    fi
done
ligne "arp/voisin 192.168.137.1 : $(ip neigh show 192.168.137.1 2>/dev/null || echo '(vide)')"
ligne "--- résolution par le système (sans @) ---"
getent hosts srv1.ofppt.local 2>/dev/null || ligne "getent srv1.ofppt.local : ECHEC"
ligne '```'
ligne ""

ligne "*Services*"
ligne '```'
for svc in bind9 apache2 vsftpd smbd nmbd nfs-kernel-server systemd-resolved; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
        ligne "${svc} : $(systemctl is-active "$svc" 2>/dev/null)"
    fi
done
ligne "--- ports en écoute ---"
(ss -lntu 2>/dev/null | grep -E ':(21|22|53|80|443|139|445|111|2049|30000) ') || ligne "(aucun port attendu)"
ligne '```'
ligne ""

ligne "*DNS (si bind9 est là)*"
ligne '```'
if command -v dig >/dev/null 2>&1; then
    for q in "srv1.ofppt.local A" "www.ntic.local A" "www.tri.local A" \
             "-x 192.168.137.30" "ofppt.local MX" "_ldap._tcp.ntic.local SRV"; do
        rep="$(dig +short +time=2 +tries=1 @127.0.0.1 $q 2>/dev/null | tr '\n' ' ')"
        ligne "dig @127.0.0.1 ${q} -> ${rep:-RIEN}"
    done
else
    ligne "dig absent (apt install bind9-dnsutils)"
fi
ligne '```'
ligne ""

ligne "*Dernières erreurs utiles*"
ligne '```'
for svc in bind9 apache2 vsftpd smbd nfs-kernel-server; do
    if systemctl is-active "$svc" >/dev/null 2>&1; then continue; fi
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
        ligne "== ${svc} =="
        journalctl -u "$svc" -n 8 --no-pager 2>/dev/null | tail -8
    fi
done
ligne "== pare-feu =="
(ufw status 2>/dev/null || ligne "ufw absent") | head -8
ligne '```'
ligne ""
ligne "${SEP}"
ligne "Fin du rapport ${ETIQUETTE}"
