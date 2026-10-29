#!/usr/bin/env bash
# ---------------------------------------------------------------
# Remet le PC dans son état NORMAL après une session de TP.
#
#   sudo bash 98-retour-a-la-normale.sh            # avec confirmation
#   sudo bash 98-retour-a-la-normale.sh -y         # sans confirmation
#   sudo bash 98-retour-a-la-normale.sh -y NOM     # impose le nom d'hôte
#
# Ce qui est remis :
#   1. bind9 arrêté et désactivé   (le paquet reste installé, on y revient)
#   2. /etc/resolv.conf rendu à systemd-resolved
#   3. systemd-resolved démasqué et réactivé
#   4. /etc/NetworkManager/conf.d/99-no-dns.conf supprimé
#   5. les profils Wi-Fi remis en DHCP s'ils portent 192.168.137.x
#   6. l'auto-connexion Wi-Fi réactivée
#   7. le nom d'hôte et /etc/hosts d'origine
#
# Les fichiers de zone (/etc/bind/zones) sont CONSERVÉS : la prochaine
# session de TP repartira de là.
# ---------------------------------------------------------------

set -u

OUI=0
NOM=""
for a in "$@"; do
    case "$a" in
        -y|--yes)  OUI=1 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *)         NOM="$a" ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "À lancer avec sudo : sudo bash $0" >&2
    exit 1
fi

CIBLE="$NOM"
[ -z "$CIBLE" ] && CIBLE="$(awk '/^127\.0\.1\.1/ {print $2; exit}' /etc/hosts 2>/dev/null)"
[ -z "$CIBLE" ] && CIBLE="$(hostname)"

echo "Nom d'hôte d'origine détecté : $CIBLE"
echo
echo "Actions prévues :"
echo "  - arrêt/désactivation de bind9 (paquet conservé)"
echo "  - suppression de /etc/NetworkManager/conf.d/99-no-dns.conf"
echo "  - réactivation de systemd-resolved + résolveur d'origine"
echo "  - profils Wi-Fi en 192.168.137.x remis en DHCP"
echo "  - auto-connexion Wi-Fi réactivée"
echo "  - hostname -> $CIBLE, lignes du labo retirées de /etc/hosts"
echo

if [ "$OUI" -eq 0 ]; then
    printf 'On continue ? [o/N] '
    read -r rep
    case "$rep" in
        o|O|y|Y) ;;
        *) echo "Annulé."; exit 0 ;;
    esac
fi

echo
echo "== 1. bind9 =="
systemctl disable --now bind9 2>/dev/null || true
systemctl disable --now named 2>/dev/null || true
echo "   bind9 : $(systemctl is-active bind9 2>/dev/null || echo inactif)"

echo "== 2. NetworkManager : dns=none =="
rm -f /etc/NetworkManager/conf.d/99-no-dns.conf
echo "   supprimé"

echo "== 3. systemd-resolved =="
systemctl unmask systemd-resolved 2>/dev/null || true
systemctl enable --now systemd-resolved 2>&1 | tail -1
echo "   état : $(systemctl is-active systemd-resolved)"

echo "== 4. /etc/resolv.conf =="
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ls -l /etc/resolv.conf | sed 's/^/   /'

echo "== 5. profils Wi-Fi à remettre en DHCP =="
nmcli -t -f NAME,TYPE connection show 2>/dev/null | while IFS=: read -r n t; do
    [ "$t" = "802-11-wireless" ] || continue
    m="$(nmcli -g ipv4.method connection show "$n" 2>/dev/null)"
    a="$(nmcli -g ipv4.addresses connection show "$n" 2>/dev/null)"
    case "$m:$a" in
        manual:*192.168.137.*)
            nmcli connection modify "$n" ipv4.method auto ipv4.addresses "" \
                  ipv4.gateway "" ipv4.dns "" ipv4.dns-search "" 2>/dev/null \
                && echo "   $n : repassé en DHCP"
            ;;
    esac
done

echo "== 6. auto-connexion Wi-Fi =="
nmcli -t -f NAME,TYPE connection show 2>/dev/null | while IFS=: read -r n t; do
    [ "$t" = "802-11-wireless" ] || continue
    nmcli connection modify "$n" connection.autoconnect yes 2>/dev/null \
        && echo "   $n : autoconnect = yes"
done

echo "== 7. nom d'hôte et /etc/hosts =="
hostnamectl set-hostname "$CIBLE"
# lignes du labo (192.168.137.x) retirées
if grep -q '^192\.168\.137\.' /etc/hosts 2>/dev/null; then
    grep -v -E '^192\.168\.137\.' /etc/hosts > /tmp/hosts.nettoye
    cat /tmp/hosts.nettoye > /etc/hosts
    rm -f /tmp/hosts.nettoye
    echo "   lignes 192.168.137.x retirées de /etc/hosts"
fi
# la ligne 127.0.1.1 doit porter le nom d'origine
if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$CIBLE/" /etc/hosts
fi

echo "== 8. redémarrage de NetworkManager =="
systemctl restart NetworkManager
sleep 3

echo
echo "────────────────────────────────────────────"
echo "VÉRIFICATION"
echo "  hostname          : $(hostname)"
echo "  hostname -f       : $(hostname -f 2>/dev/null)"
echo "  resolv.conf       : $(readlink -f /etc/resolv.conf)"
awk '/^nameserver/ {print "  nameserver        : " $2}' /etc/resolv.conf
echo "  bind9             : $(systemctl is-active bind9 2>/dev/null || echo inactif)"
echo "  resolved          : $(systemctl is-active systemd-resolved 2>/dev/null)"
echo -n "  résolution        : "
getent hosts github.com >/dev/null 2>&1 && echo "OK" || echo "ECHEC"
echo -n "  Internet (HTTP)   : "
curl -sI --max-time 8 https://deb.debian.org >/dev/null 2>&1 && echo "OK" || echo "ECHEC"
echo "────────────────────────────────────────────"
echo
echo "Si l'Internet ne revient pas : reconnecte le Wi-Fi à la main,"
echo "puis  sudo nmcli connection up \"NOM_DU_WIFI\""
