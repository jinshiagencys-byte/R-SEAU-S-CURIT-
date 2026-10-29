#!/usr/bin/env bash
# ---------------------------------------------------------------
# TP Administration Réseau — vérification de la PHASE 1 (socle réseau)
# À lancer sur SRV1 (192.168.137.10) et sur SRV2 (192.168.137.20).
#
#   bash 00-verif-reseau.sh              # IP par défaut = 192.168.137.10
#   bash 00-verif-reseau.sh .20          # sur SRV2
#   bash 00-verif-reseau.sh .10 --isole  # force le mode sans passerelle
#
# Le script s'adapte tout seul à trois situations :
#   - HOTSPOT : passerelle 192.168.137.1 présente     → Internet exigé (apt)
#   - DOUBLE  : labo câblé + Internet par le Wi-Fi    → pas de passerelle de labo
#   - ISOLÉ   : aucune passerelle (doc 10, schéma C)  → Internet non exigé
#
# Code retour : 0 si tout est bon, 1 sinon.
# ---------------------------------------------------------------

set -u

# --- argument d'adresse : ".20" ou l'adresse complète -------------------
case "${1:-}" in
    .10) MOI_IP="192.168.137.10" ;;
    .20) MOI_IP="192.168.137.20" ;;
    "")  MOI_IP="192.168.137.10" ;;
    *)   MOI_IP="$1" ;;
esac

FORCE_ISOLE=0
for a in "$@"; do [ "$a" = "--isole" ] && FORCE_ISOLE=1; done

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
IFACE=""
LIGNE="$(ip -4 -o addr show | grep "inet ${MOI_IP}/24")"
if [ -n "$LIGNE" ]; then
    IFACE="$(echo "$LIGNE" | awk '{print $2}')"
    vert "  [OK]   ${MOI_IP}/24 présente sur $IFACE"
    OK=$((OK+1))
    case "$IFACE" in
        en*)  echo "         → interface filaire (mode câblé, doc 10)" ;;
        wl*)  echo "         → interface Wi-Fi (mode hotspot)" ;;
    esac
else
    rouge "  [ECHEC] ${MOI_IP}/24 absente"
    ip -4 -o addr show | sed 's/^/         /'
    KO=$((KO+1))
fi

titre "3. Passerelle par défaut"
GW="$(ip route | awk '/^default/ {print $3; exit}')"
GWDEV="$(ip route | awk '/^default/ {print $5; exit}')"
if [ "$FORCE_ISOLE" -eq 1 ] || [ -z "$GW" ]; then
    MODE="isole"
    if [ "$FORCE_ISOLE" -eq 1 ]; then
        echo "  [INFO] mode isolé forcé (--isole)"
    else
        echo "  [INFO] aucune passerelle par défaut"
    fi
    echo "         → NORMAL si le labo est câblé en direct (doc 10, schéma C)"
    echo "         → ANORMAL si tu passes par le hotspot Windows : la route a sauté"
    echo "           (réparer : sudo nmcli connection up \"NOM_DU_WIFI\")"
elif [ "$GW" = "$PASSERELLE" ]; then
    MODE="hotspot"
    check "default via" "$PASSERELLE" "$GW"
elif [ -n "$IFACE" ] && [ "$GWDEV" = "$IFACE" ]; then
    MODE="hotspot"
    check "default via" "$PASSERELLE" "$GW"
else
    MODE="double"
    echo "  [INFO] default via $GW dev ${GWDEV:-?} — ce n'est pas $PASSERELLE"
    echo "         → NORMAL si le labo est câblé (${IFACE:-?}) et qu'Internet arrive par le Wi-Fi."
    echo "           Le labo n'a pas de passerelle : rien à réparer."
    echo "         → ANORMAL si tu attendais la passerelle du hotspot : elle a sauté."
fi

titre "4. Serveur DNS configuré"
DNS_RESOLV="$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null)"
DNS_NM="$(nmcli -g IP4.DNS device show 2>/dev/null | head -1 | cut -d'|' -f1)"
echo "  /etc/resolv.conf   : ${DNS_RESOLV:-aucun}   ← c'est celui qui compte"
echo "  nmcli (config)     : ${DNS_NM:-aucun}"
echo "  (192.168.137.1 avant le TP4, 127.0.0.1 après la bascule du doc 07 §3.7)"
echo "  (les deux sont normaux après la bascule : NetworkManager garde son réglage,"
echo "   mais dns=none empêche qu'il réécrive /etc/resolv.conf)"

if [ "$MODE" = "isole" ]; then

    titre "5. Passerelle $PASSERELLE — sans objet en mode isolé"
    echo "  [INFO] aucune passerelle attendue : ce contrôle est sauté."
    echo "         Le PC Windows n'est pas un routeur maîtrisé sur ce montage."

    titre "6. Internet — non exigé en mode isolé"
    if curl -sI --max-time 5 https://deb.debian.org >/dev/null 2>&1; then
        vert "  [OK]   Internet présent malgré l'absence de passerelle par défaut"
        OK=$((OK+1))
    else
        echo "  [INFO] pas d'Internet : c'est le cas normal d'un montage câblé fermé."
        echo "         apt se fait depuis la clé USB :"
        echo "           sudo apt install ./paquets-tp/*.deb"
    fi

else

    if [ "$MODE" = "hotspot" ]; then
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
    else
        titre "5. Passerelle $PASSERELLE — absente, et c'est normal"
        echo "  [INFO] le labo est câblé, Internet passe par ${GWDEV:-une autre interface} :"
        echo "         il ne doit PAS y avoir de route par défaut vers $PASSERELLE."
    fi

    titre "6. Internet (nécessaire pour apt) — test TCP, pas ICMP"
    INTERNET=0
    if curl -sI --max-time 8 https://deb.debian.org >/dev/null 2>&1; then
        vert "  [OK]   https://deb.debian.org répond — apt fonctionnera"
        INTERNET=1
    elif [ "$MODE" = "hotspot" ] && dig +short +time=3 +tries=1 @"$PASSERELLE" deb.debian.org 2>/dev/null | grep -qE '^[0-9]+\.'; then
        vert "  [OK]   DNS résolu via $PASSERELLE — apt fonctionnera"
        INTERNET=1
    elif ping -c2 -W2 8.8.8.8 >/dev/null 2>&1; then
        vert "  [OK]   ICMP vers 8.8.8.8 — Internet présent"
        INTERNET=1
    fi
    if [ "$INTERNET" -eq 0 ]; then
        rouge "  [ECHEC] pas d'Internet : apt échouera"
        echo "         → le hotspot Windows est-il allumé ? (ou le Wi-Fi de la salle)"
        echo "         → VPN/WARP connecté ? (warp-cli disconnect)"
        echo "         → pas d'Internet du tout ? clé USB : scripts/97-paquets-hors-ligne.sh"
        KO=$((KO+1))
    else
        OK=$((OK+1))
    fi
    echo "  (le ping vers 8.8.8.8 peut échouer alors qu'Internet marche : ICMP filtré)"

fi

titre "7. L'autre serveur ($AUTRE_IP) — informatif"
if ping -c2 -W2 "$AUTRE_IP" >/dev/null 2>&1; then
    vert "  [OK]   $AUTRE_IP répond au ping"
    OK=$((OK+1))
else
    echo "  [INFO] pas de réponse ICMP de $AUTRE_IP"
    if [ "$MODE" = "hotspot" ]; then
        echo "         → normal si l'autre machine n'a pas fini sa phase 1"
        echo "         → si elle l'a finie : isolation client du hotspot, ou ufw"
    else
        echo "         → en câblé direct, vérifier le lien physique :"
        echo "           ip neigh show        (une MAC en face = lien bon)"
        echo "           cat /sys/class/net/<iface>/carrier   (1 = câble détecté)"
        echo "         → sur cet agent, ping peut être bloqué même si le réseau est bon :"
        echo "           timeout 3 bash -c \"</dev/tcp/$AUTRE_IP/22\""
    fi
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
    vert "PHASE 1 VALIDÉE — $OK contrôles OK (mode $MODE)"
    exit 0
else
    rouge "PHASE 1 INCOMPLÈTE — $OK OK / $KO échec(s) (mode $MODE)"
    exit 1
fi
