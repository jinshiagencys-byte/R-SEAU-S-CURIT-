#!/usr/bin/env bash
# ---------------------------------------------------------------
# TP Administration Réseau — vérification du serveur DNS (TP4)
# Porte de sortie de la PHASE 2. À lancer sur SRV1 après avoir démarré bind9.
#
#   bash 01-verif-dns.sh              # interroge 127.0.0.1
#   bash 01-verif-dns.sh 192.168.137.10
#
# Chaque test affiche la valeur attendue et la valeur obtenue.
# Code retour : 0 si tout est bon, 1 sinon.
# ---------------------------------------------------------------

set -u

SRV="${1:-127.0.0.1}"
OK=0
KO=0

vert()  { printf '\033[32m%s\033[0m\n' "$*"; }
rouge() { printf '\033[31m%s\033[0m\n' "$*"; }
titre() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# check <intitulé> <valeur attendue> <requête...>
check() {
    local libelle="$1" attendu="$2"; shift 2
    local obtenu
    obtenu="$(dig +short +time=2 +tries=1 @${SRV} "$@" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"

    if [ "$obtenu" = "$attendu" ]; then
        vert "  [OK]    ${libelle} → ${obtenu}"
        OK=$((OK+1))
    else
        rouge "  [ECHEC] ${libelle}"
        rouge "          attendu : '${attendu}'"
        rouge "          obtenu  : '${obtenu:-rien}'"
        KO=$((KO+1))
    fi
}

# contient <intitulé> <motif> <requête...>   (pour les réponses multi-lignes)
contient() {
    local libelle="$1" motif="$2"; shift 2
    local obtenu
    obtenu="$(dig +short +time=2 +tries=1 @${SRV} "$@" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"

    if printf '%s' "$obtenu" | grep -q -- "$motif"; then
        vert "  [OK]    ${libelle} → ${obtenu}"
        OK=$((OK+1))
    else
        rouge "  [ECHEC] ${libelle}"
        rouge "          motif attendu : '${motif}'"
        rouge "          obtenu        : '${obtenu:-rien}'"
        KO=$((KO+1))
    fi
}

# verifie <intitulé> <attendu> <obtenu>   (comparaison de deux chaînes déjà calculées)
verifie() {
    local libelle="$1" attendu="$2" obtenu="$3"

    if [ "$obtenu" = "$attendu" ]; then
        vert "  [OK]    ${libelle} → ${obtenu}"
        OK=$((OK+1))
    else
        rouge "  [ECHEC] ${libelle}"
        rouge "          attendu : '${attendu}'"
        rouge "          obtenu  : '${obtenu:-rien}'"
        KO=$((KO+1))
    fi
}

titre "0. Service"
if systemctl is-active --quiet bind9 2>/dev/null || systemctl is-active --quiet named 2>/dev/null; then
    vert "  [OK]    bind9 est actif"
    OK=$((OK+1))
else
    rouge "  [ECHEC] bind9 n'est pas actif (systemctl status bind9)"
    KO=$((KO+1))
fi
if ss -lntu 2>/dev/null | grep -q ':53 '; then
    vert "  [OK]    le port 53 écoute"
    OK=$((OK+1))
else
    rouge "  [ECHEC] rien n'écoute sur le port 53"
    KO=$((KO+1))
fi
echo "  Serveur interrogé : ${SRV}"

titre "1. Zone directe ofppt.local — enregistrements A"
check "srv1.ofppt.local"            "192.168.137.10"  srv1.ofppt.local A
check "srv2.ofppt.local"            "192.168.137.20"  srv2.ofppt.local A
check "mx1.ofppt.local"             "192.168.137.30"  mx1.ofppt.local A
check "ldap.ofppt.local"            "192.168.137.40"  ldap.ofppt.local A
check "www.ofppt.local"             "192.168.137.20"  www.ofppt.local A
check "pc01.ofppt.local"            "192.168.137.1"   pc01.ofppt.local A

titre "2. Alias CNAME (un serveur, plusieurs noms d'énoncés)"
check "centos1 → srv1"   "srv1.ofppt.local."  centos1.ofppt.local CNAME
check "ista → srv1"      "srv1.ofppt.local."  ista.ofppt.local CNAME
check "centos2 → srv2"   "srv2.ofppt.local."  centos2.ofppt.local CNAME
check "smtp → mx1"       "mx1.ofppt.local."   smtp.ofppt.local CNAME
check "imap → mx1"       "mx1.ofppt.local."   imap.ofppt.local CNAME

titre "3. Messagerie et IPv6 (TP4-1 §6)"
contient "MX de ofppt.local (priorité 20)" "20 mx1.ofppt.local." ofppt.local MX
check    "mx1 AAAA"     "2002:db8:a:a::198"  mx1.ofppt.local AAAA

titre "4. Serveurs de noms (NS)"
contient "NS srv1" "srv1.ofppt.local." ofppt.local NS
contient "NS srv2" "srv2.ofppt.local." ofppt.local NS

titre "5. Zone inverse (PTR — TP4-1 §9)"
check "192.168.137.30 → mx1"  "mx1.ofppt.local."   -x 192.168.137.30
check "192.168.137.10 → srv1" "srv1.ofppt.local."  -x 192.168.137.10
check "192.168.137.20 → srv2" "srv2.ofppt.local."  -x 192.168.137.20

titre "6. Temporisations SOA (TP4-1 §7)"
SOA="$(dig +short +time=2 +tries=1 @${SRV} ofppt.local SOA 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
[ -n "$SOA" ] && echo "  SOA : ${SOA}"
REFRESH="$(printf '%s' "$SOA" | awk '{print $4}')"
RETRY="$(printf '%s' "$SOA" | awk '{print $5}')"
EXPIRE="$(printf '%s' "$SOA" | awk '{print $6}')"
verifie "refresh (2H)"  "7200"    "${REFRESH:-}"
verifie "retry (20M)"   "1200"    "${RETRY:-}"
verifie "expire (1W)"   "604800"  "${EXPIRE:-}"

titre "7. Zones du TP5 (ntic.local / tri.local)"
check "www.ntic.local" "192.168.137.20" www.ntic.local A
check "www.tri.local"  "192.168.137.20" www.tri.local A
contient "SRV _ldap._tcp (20 200 389)" "20 200 389 ldap.ntic.local." _ldap._tcp.ntic.local SRV
contient "MX de ntic.local" "20 mail.ntic.local." ntic.local MX

titre "8. Enregistrements du TP6"
# centos1 est un CNAME : +short renvoie la cible PUIS l'A résolu, d'où "contient"
contient "centos1.ofppt.local (CNAME → 192.168.137.10)" "192.168.137.10" centos1.ofppt.local A
check    "ftp.ofppt.local"                             "192.168.137.20" ftp.ofppt.local A

printf '\n────────────────────────────────\n'
printf 'Serveur : %s\n' "$SRV"
if [ "$KO" -eq 0 ]; then
    vert "PHASE 2 VALIDÉE — $OK contrôles OK"
    echo
    echo "Étape suivante : fige le résolveur système (doc 07 §3.7),"
    echo "puis annonce au groupe que le DNS est opérationnel."
    exit 0
else
    rouge "PHASE 2 INCOMPLÈTE — $OK OK / $KO échec(s)"
    echo
    echo "Pistes :"
    echo "  - 'connection timed out'  → systemd-resolved écoute encore, ou bind9 arrêté"
    echo "  - 'REFUSED'               → allow-query dans named.conf.options"
    echo "  - 'SERVFAIL' en série     → dnssec-validation no manquant"
    echo "  - fichier ignoré          → droits : chown -R root:bind /etc/bind/zones"
    echo "  - zone absente           → named-checkconf puis journalctl -u bind9 -n 30"
    exit 1
fi
