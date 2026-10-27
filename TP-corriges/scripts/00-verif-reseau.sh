#!/usr/bin/env bash
# ---------------------------------------------------------------
# TP Administration Réseau — vérification de la PHASE 1 (socle réseau)
# À lancer sur SRV1 (192.168.137.10) et sur SRV2 (192.168.137.20).
#
#   bash 00-verif-reseau.sh
#
# Code retour : 0 si tout est bon, 1 sinon.
# ---------------------------------------------------------------

set -u

MOI_IP="${1:-192.168.137.10}"
AUTRE_IP="192.168.137.20"
if [ "$MOI_IP" = "192.168.137.20" ]; then
    AUTRE_IP="192.168.137.10"
    ATTENDU="srv2.ofppt.local"
else
    ATTENDU="srv1.ofppt.local"
fi
PASSERELLE="192.168.137.1"

OK=0
KO=0

vert()  { printf '\033[32m%s\033[0m\n' "$*"; }
rouge() { printf '\033[31m%s\033[0m\n' "$*"; }
titre() { printf '\n\033[1m%s\033[0m\n' "$*"; }

check() { # $1 intitulé, $2 attendu, $3 obtenu
    if [ "$2" = "$3" ]; then
        vert "  [OK]   $1 → $3"
        OK=$((OK+1))
    else
        rouge "  [ECHEC] $1"
        rouge "         attendu : $2"
        rouge "         obtenu  : $3"
        KO=$((KO+1))
    fi
}

titre "1. Nom de la machine"
check "hostname -f" "$ATTENDU" "$(hostname -f 2>/dev/null || echo '(inconnu)')"

titre "2. Adresse IP"
if ip -4 -o addr show | grep -q "inet ${MOI_IP}/24"; then
    vert "  [OK]   ${MOI_IP}/24 présente sur $(ip -4 -o addr show | grep "inet ${MOI_IP}/24" | awk '{print $2}')"
    OK=$((OK+1))
else
    rouge "  [ECHEC] ${MOI_IP}/24 absente"
    ip -4 -o addr show | sed 's/^/         /'
    KO=$((KO+1))
fi

titre "3. Passerelle par défaut"
GW="$(ip route | awk '/^default/ {print $3; exit}')"
check "default via" "$PASSERELLE" "${GW:-aucune}"

titre "4. Serveur DNS configuré"
DNS_RESOLV="$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)"
DNS_NM="$(nmcli -g IP4.DNS device show 2>/dev/null | head -1 | cut -d'|' -f1)"
echo "  /etc/resolv.conf   : ${DNS_RESOLV:-aucun}   ← c'est celui qui compte"
echo "  nmcli (config)     : ${DNS_NM:-aucun}"
echo "  (192.168.137.1 avant le TP4, 127.0.0.1 après la bascule du doc 07 §3.7)"
echo "  (les deux sont normaux après la bascule : NetworkManager garde son réglage,"
echo "   mais dns=none empêche qu'il réécrive /etc/resolv.conf)"

titre "5. Passerelle $PASSERELLE (ICMP — informatif)"
if ping -c2 -W2 "$PASSERELLE" >/dev/null 2>&1; then
    vert "  [OK]   $PASSERELLE répond au ping"
    OK=$((OK+1))
else
    echo "  [INFO] pas de réponse ICMP — ce n'est PAS une panne."
    echo "         Windows bloque les échos sur le partage de connexion (profil Public)."
    NEIGH="$(ip neigh show "$PASSERELLE" 2>/dev/null)"
    if [ -n "$NEIGH" ]; then
        vert "         mais la machine est bien là : $NEIGH"
    else
        rouge "         et aucune entrée ARP : cette adresse n'existe pas sur ce réseau"
        KO=$((KO+1))
    fi
fi

titre "6. Internet (nécessaire pour apt) — test TCP, pas ICMP"
INTERNET=0
if curl -sI --max-time 8 https://deb.debian.org >/dev/null 2>&1; then
    vert "  [OK]   https://deb.debian.org répond — apt fonctionnera"
    INTERNET=1
elif dig +short +time=3 +tries=1 @"$PASSERELLE" deb.debian.org 2>/dev/null | grep -qE '^[0-9]+\.'; then
    vert "  [OK]   DNS résolu via $PASSERELLE — apt fonctionnera"
    INTERNET=1
elif ping -c2 -W2 8.8.8.8 >/dev/null 2>&1; then
    vert "  [OK]   ICMP vers 8.8.8.8 — Internet présent"
    INTERNET=1
fi
if [ "$INTERNET" -eq 0 ]; then
    rouge "  [ECHEC] pas d'Internet : apt échouera"
    echo "         → le hotspot Windows est-il allumé ?"
    echo "         → VPN/WARP connecté ? (warp-cli disconnect)"
    KO=$((KO+1))
else
    OK=$((OK+1))
fi
echo "  (le ping vers 8.8.8.8 peut échouer alors qu'Internet marche : ICMP filtré)"

titre "7. L'autre serveur ($AUTRE_IP) — informatif"
if ping -c2 -W2 "$AUTRE_IP" >/dev/null 2>&1; then
    vert "  [OK]   $AUTRE_IP répond au ping"
    OK=$((OK+1))
else
    echo "  [INFO] pas de réponse ICMP de $AUTRE_IP"
    echo "         → normal si l'autre machine n'a pas fini sa phase 1"
    echo "         → si elle l'a finie : isolation client du hotspot, ou ufw"
    echo "         → test TCP plus fiable :  timeout 3 bash -c \"</dev/tcp/$AUTRE_IP/22\" "
fi

titre "8. Résolution de nom locale"
if getent hosts "$ATTENDU" >/dev/null 2>&1; then
    vert "  [OK]   /etc/hosts contient $ATTENDU"
    OK=$((OK+1))
else
    rouge "  [ECHEC] /etc/hosts incomplet (ligne manquante pour $ATTENDU)"
    KO=$((KO+1))
fi

printf '\n────────────────────────────────\n'
if [ "$KO" -eq 0 ]; then
    vert "PHASE 1 VALIDÉE — $OK contrôles OK"
    exit 0
else
    rouge "PHASE 1 INCOMPLÈTE — $OK OK / $KO échec(s)"
    exit 1
fi
