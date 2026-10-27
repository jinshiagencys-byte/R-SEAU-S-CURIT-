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
DNS="$(nmcli -g IP4.DNS device show 2>/dev/null | head -1 | cut -d'|' -f1)"
[ -z "$DNS" ] && DNS="$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)"
echo "  DNS actuel : ${DNS:-aucun}"
echo "  (192.168.137.1 attendu avant le TP4, 127.0.0.1 après)"

titre "5. Ping passerelle"
if ping -c2 -W2 "$PASSERELLE" >/dev/null 2>&1; then
    vert "  [OK]   $PASSERELLE répond"
    OK=$((OK+1))
else
    rouge "  [ECHEC] $PASSERELLE ne répond pas"
    KO=$((KO+1))
fi

titre "6. Internet (nécessaire pour apt)"
if ping -c2 -W2 8.8.8.8 >/dev/null 2>&1; then
    vert "  [OK]   8.8.8.8 répond — apt fonctionnera"
    OK=$((OK+1))
else
    rouge "  [ECHEC] pas d'Internet : apt échouera"
    KO=$((KO+1))
fi

titre "7. Ping de l'autre serveur ($AUTRE_IP)"
if ping -c2 -W2 "$AUTRE_IP" >/dev/null 2>&1; then
    vert "  [OK]   $AUTRE_IP répond — le LAN est bon"
    OK=$((OK+1))
else
    rouge "  [INFO] $AUTRE_IP ne répond pas encore"
    echo "         → normal si l'autre machine n'a pas fini sa phase 1"
    echo "         → si elle l'a finie : isolation client du hotspot, ou ufw"
fi

titre "8. Résolution de nom locale"
if getent hosts srv1.ofppt.local >/dev/null 2>&1; then
    vert "  [OK]   /etc/hosts contient srv1.ofppt.local"
    OK=$((OK+1))
else
    rouge "  [ECHEC] /etc/hosts incomplet"
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
