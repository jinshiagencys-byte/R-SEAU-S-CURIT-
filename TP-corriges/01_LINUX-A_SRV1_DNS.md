# 01 — Linux A / SRV1 : serveur DNS (Bind)

**Couvre :** TP4-1 en entier · TP4-2 §II et §III (serveur primaire) · TP5 partie 1 ·
TP6 partie 1.

**Machine :** `srv1.ofppt.local` — `192.168.137.10/24` — passerelle `192.168.137.1`.

**Durée :** ~1 h 30. **À faire en premier** : tout le reste en dépend.

> ## 🚨 SRV1 EST SOUS UBUNTU 24.04
>
> **Ce document n'est pas à exécuter tel quel** : il est écrit pour CentOS 7 et sert de
> **référence pour le rapport**. Les commandes réelles sont dans **`07_UBUNTU-24.04.md`** :
>
> | Étape | CentOS (ici) | Ubuntu (à exécuter) |
> |---|---|---|
> | Réseau, hostname | §1 | `07` **§1** |
> | Installation | `yum install bind bind-utils` | `07` **§3.1** (`apt install bind9 bind9utils bind9-dnsutils`) |
> | Config générale | `/etc/named.conf` §3 | `07` **§3.2** (`/etc/bind/named.conf.options`) |
> | Déclaration des zones | §3 | `07` **§3.3** (`/etc/bind/named.conf.local`) |
> | Fichiers de zone | `/var/named/` §4-5 | `07` **§3.4** (`/etc/bind/zones/`) |
> | Contrôles | §6 | `07` **§3.5** (identiques) |
> | Tests | §8 | `07` **§3.6** (ajouter `@127.0.0.1`) |
>
> Le contenu des zones est **identique** ; le piège Ubuntu est `systemd-resolved` qui occupe
> déjà le port 53 (`07` §2).



> Ne pas oublier : `script ScTP5.txt` si vous voulez aussi la trace pour le TP5 (le TP4 n'en
> demande pas). Le journal `script` dure tout le TP, ne le relancez pas entre deux commandes.

---

## 1. Préparation (TP4-1 §1-2-3, TP5 P1 §1-2, TP6 P1 §1-2)

Les trois énoncés demandent de renommer la machine (`ista`, `srv1.ntic.local`,
`centos1.ofppt.local`) et de lui donner une IP différente à chaque fois. **On fait une seule
fois** : nom `srv1.ofppt.local`, et les autres noms deviennent des alias DNS (CNAME) — voir §4.
À écrire dans le rapport, avec le tableau de correspondance.

```bash
# Nom d'hôte
sudo hostnamectl set-hostname srv1.ofppt.local

# IP fixe (adapter le nom de connexion Wi-Fi)
nmcli -t -f NAME,DEVICE connection show --active
sudo nmcli connection modify "NOM_DU_WIFI" \
     ipv4.method manual ipv4.addresses 192.168.137.10/24 \
     ipv4.gateway 192.168.137.1 ipv4.dns 192.168.137.1 ipv4.dns-search ofppt.local
sudo nmcli connection up "NOM_DU_WIFI"

# /etc/hosts
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
EOF

# Vérifications
hostname -f                       # → srv1.ofppt.local
ip -4 addr show | grep 192.168
ip route | grep default           # → default via 192.168.137.1
```

**Q. « Démarrer ou redémarrer le service réseau »** (TP4-1 §3, à mettre dans le rapport) :

- CentOS 7 (NetworkManager) : `sudo systemctl restart NetworkManager`
- ancienne syntaxe demandée par l'énoncé : `sudo service network restart`
- équivalent moderne : `sudo nmcli connection up "NOM_DU_WIFI"`

---

## 2. Installation de Bind (TP4-1 §4, TP4-2 §II)

```bash
# Q1 : le paquet est-il déjà là ?
rpm -qa | grep -i '^bind'

# Q2 : installation par rpm (si vous avez les .rpm en local)
#       rpm -ivh bind-9.11.4-26.P2.el7_9.x86_64.rpm bind-utils-9.11.4-26.P2.el7_9.x86_64.rpm

# Q3 : installation par yum (ce qu'on utilise)
sudo yum install -y bind bind-utils

# Q4 : visualiser les fichiers installés
rpm -ql bind | head -40
rpm -ql bind-utils

# Q5 : port du service DNS
sudo ss -lntup | grep :53        # ou : grep -w domain /etc/services   → 53/tcp et 53/udp
```

> ⚠️ Si `yum` renvoie des erreurs 404 / « Cannot find a valid baseurl » : CentOS 7 est en fin
> de vie, voir `00_PLAN_ET_RESEAU.md` §6.1.

Fichiers utiles à connaître (TP4-2 §II.4 demande de les citer) :

| Fichier | Rôle |
|---|---|
| `/etc/named.conf` | configuration générale + déclaration des zones |
| `/var/named/` | fichiers de zone |
| `/var/named/named.ca` | racines (inutile si `forwarders`, mais présent) |
| `/etc/rndc.key` | clé de contrôle `rndc` |
| `/var/log/messages` | journaux de `named` |

---

## 3. Configuration générale (`/etc/named.conf`)

Sauvegarde puis remplacement complet :

```bash
sudo cp /etc/named.conf /etc/named.conf.orig
sudo tee /etc/named.conf >/dev/null <<'EOF'
options {
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    directory      "/var/named";
    dump-file      "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    recursing-file "/var/named/data/named.recursing";
    secroots-file  "/var/named/data/named.secroots";

    allow-query     { any; };
    recursion yes;

    /* TP4-2 §III.1 : rediriger les noms non résolus vers un résolveur amont.
       Ici : la passerelle du partage de connexion Windows + l'adresse de l'énoncé. */
    forwarders { 192.168.137.1; 212.217.0.12; };

    /* Pas d'Internet garanti en TP : sinon les réponses légitimes finissent en SERVFAIL */
    dnssec-validation no;
};

/* ---------- Zones directes ---------- */

zone "ofppt.local" IN {                 /* TP4-1 §5 + TP6 P1 §4 */
    type master;
    file "ofppt.local.dir";
    allow-transfer { 192.168.137.20; }; /* TP4-1 §5 : autoriser le transfert vers le 2ndaire */
    notify yes;                         /* TP4-1 §5 : permettre la notification          */
    also-notify { 192.168.137.20; };
    allow-update { none; };             /* TP6 P1 §4 : pas de mise à jour dynamique      */
};

zone "ntic.local" IN {                  /* TP5 P1 §4 */
    type master;
    file "ntic.local.dir";
    allow-transfer { 192.168.137.20; };
    notify yes;
    allow-update { none; };
};

zone "tri.local" IN {                   /* TP5 P1 §5 */
    type master;
    file "tri.local.dir";
    allow-transfer { 192.168.137.20; };
    notify yes;
    allow-update { none; };
};

/* ---------- Zone inverse ---------- */

zone "137.168.192.in-addr.arpa" IN {    /* TP4-1 §8 transposé : réseau 192.168.137.0/24 */
    type master;
    file "192.168.137.rev";
    allow-transfer { 192.168.137.20; };
    notify yes;
    /* TP4-1 §8 : mise à jour dynamique autorisée pour le serveur lui-même.
       (Syntaxe acceptée par Bind, mais non sécurisée : la bonne méthode est une
       clé TSIG — voir doc 04 partie E pour la version « propre » du DDNS.) */
    allow-update { 192.168.137.10; };
};
EOF
```

> **Écart assumé à expliquer dans le rapport** : TP4-1 §8 demande une zone inverse pour
> `10.0.0.0/8` (fichier `10.in-addr.arpa`) avec transfert et mise à jour dynamique depuis
> `10.10.0.196`. Notre réseau réel étant `192.168.137.0/24`, la zone inverse est
> `137.168.192.in-addr.arpa` et le serveur autorisé est `192.168.137.20`. La logique est
> identique, seuls les octets changent.

---

## 4. Fichier de zone `ofppt.local.dir` (TP4-1 §6 et §7, TP6 P1 §5)

Enregistrements exigés, transposés :

| Énoncé | Ici | Type |
|---|---|---|
| MX1 = 10.10.0.198 | `mx1` = 192.168.137.30 | A |
| MX1 IPv6 2002:DB8:A:A::198 | idem | AAAA |
| MX1 serveur de messagerie, priorité 20 | `@ MX 20 mx1` | MX |
| alias smtp / imap | `smtp`, `imap` | CNAME |
| Ldap = 10.10.0.194 | `ldap` = 192.168.137.40 | A |
| — (TP4-1 §7) | SOA : refresh 2H, retry 20M, expire 1W | SOA |
| TP6 P1 §8 : centos1 + ftp | `centos1` (CNAME), `ftp` (A) | — |

```bash
sudo tee /var/named/ofppt.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN ofppt.local.
@       IN  SOA srv1.ofppt.local. admin.ofppt.local. (
                2026102701 ; serial   (à incrémenter à chaque modification)
                2H         ; refresh  -> TP4-1 §7 : les secondaires nous contactent toutes les 2H
                20M        ; retry    -> TP4-1 §7 : réessai toutes les 20 min
                1W         ; expire   -> TP4-1 §7 : 1 semaine de service sans le maître
                1H )       ; negative TTL

; --- Serveurs de noms ---
@           IN  NS      srv1.ofppt.local.
@           IN  NS      srv2.ofppt.local.

; --- Messagerie : MX1 priorité 20 + alias smtp / imap ---
@           IN  MX      20 mx1.ofppt.local.
mx1         IN  A       192.168.137.30
            IN  AAAA    2002:db8:a:a::198
smtp        IN  CNAME   mx1
imap        IN  CNAME   mx1

; --- Hôtes ---
@           IN  A       192.168.137.10
srv1        IN  A       192.168.137.10
srv2        IN  A       192.168.137.20
ldap        IN  A       192.168.137.40
pc01        IN  A       192.168.137.1

; --- Alias imposés par les autres TP (un seul serveur, plusieurs noms) ---
centos1     IN  CNAME   srv1        ; TP6 P1 §1
ista        IN  CNAME   srv1        ; TP4-1 §1
centos2     IN  CNAME   srv2        ; TP6 P2 §1
www         IN  A       192.168.137.20
ftp         IN  A       192.168.137.20
samba       IN  CNAME   srv2
EOF
```

### Fichier de zone inverse `192.168.137.rev` (TP4-1 §9)

```bash
sudo tee /var/named/192.168.137.rev >/dev/null <<'EOF'
$TTL 1H
$ORIGIN 137.168.192.in-addr.arpa.
@       IN  SOA srv1.ofppt.local. admin.ofppt.local. (
                2026102701 ; serial
                2H 20M 1W 1H )
        IN  NS      srv1.ofppt.local.
        IN  NS      srv2.ofppt.local.

; TP4-1 §9 : au moins le PTR du serveur MX1
30      IN  PTR     mx1.ofppt.local.
10      IN  PTR     srv1.ofppt.local.
20      IN  PTR     srv2.ofppt.local.
40      IN  PTR     ldap.ofppt.local.
1       IN  PTR     pc01.ofppt.local.
EOF
```

---

## 5. Zones du TP5 : `ntic.local.dir` et `tri.local.dir`

TP5 P1 demande deux zones directes. TP5 P1 §7 écrit « fichier de zone `.local.dir` » : c'est
une coquille de l'énoncé, il s'agit de `tri.local.dir` (la zone déclarée juste avant). À
signaler dans le rapport.

```bash
sudo tee /var/named/ntic.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN ntic.local.
@       IN  SOA srv1.ntic.local. admin.ntic.local. (
                2026102701 ; serial
                2H 20M 1W 1H )
        IN  NS      srv1.ntic.local.
        IN  NS      srv2.ntic.local.

srv1    IN  A       192.168.137.10
srv2    IN  A       192.168.137.20
www     IN  A       192.168.137.20     ; TP5 : www.ntic.local = serveur web
ftp     IN  CNAME   srv2

; TP4-2 §III.3 : LDAP priorité 20, poids 200 -> c'est un enregistrement SRV
_ldap._tcp  IN SRV  20 200 389 ldap.ntic.local.
ldap        IN  A   192.168.137.40

; TP4-2 §III.3 : MAIL priorité 20 + adresse IPv6
@       IN  MX      20 mail.ntic.local.
mail    IN  A       192.168.137.30
        IN  AAAA    2001:660:3006:2::402
EOF

sudo tee /var/named/tri.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN tri.local.
@       IN  SOA srv1.tri.local. admin.tri.local. (
                2026102701 ; serial
                2H 20M 1W 1H )
        IN  NS      srv1.tri.local.

srv1    IN  A       192.168.137.10
srv2    IN  A       192.168.137.20
www     IN  A       192.168.137.20     ; TP5 : www.tri.local = serveur web
EOF
```

---

## 6. Contrôles avant démarrage (TP4-1 §10, TP5 P1 §8, TP6 P1 §6)

```bash
# 1. Droits et contexte SELinux (sinon Bind démarre mais ne lit pas les zones)
sudo chown root:named /var/named/*.dir /var/named/*.rev
sudo chmod 640 /var/named/*.dir /var/named/*.rev
sudo restorecon -Rv /var/named /var/log/named

# 2. Syntaxe de la configuration
sudo named-checkconf -z
#    -z vérifie aussi le chargement de toutes les zones

# 3. Syntaxe de chaque zone (le nom du fichier doit correspondre au $ORIGIN)
sudo named-checkzone ofppt.local /var/named/ofppt.local.dir
sudo named-checkzone ntic.local  /var/named/ntic.local.dir
sudo named-checkzone tri.local   /var/named/tri.local.dir
sudo named-checkzone 137.168.192.in-addr.arpa /var/named/192.168.137.rev
#    attendu pour chacune : "OK"
```

Si une erreur « serial number » ou « no valid hostname » apparaît, c'est presque toujours un
point final manquant : dans Bind, `srv1` est relatif, `srv1.ofppt.local.` est absolu.

## 7. Démarrage (TP4-1 §10)

```bash
sudo systemctl enable --now named
sudo systemctl status named --no-pager

# Pare-feu
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload

# Écoute
sudo ss -lntup | grep :53

# Bascule du DNS local vers Bind (maintenant, et pas avant)
sudo nmcli connection modify "NOM_DU_WIFI" ipv4.dns "127.0.0.1,192.168.137.1"
sudo nmcli connection up "NOM_DU_WIFI"
cat /etc/resolv.conf
```

---

## 8. Tests de résolution (TP4-1 §11, TP4-2 §III.9, TP5 P1 §10, TP6 P1 §8)

À copier **avec les sorties** dans le rapport : c'est la partie notée.

```bash
# A / SOA / NS
dig srv1.ofppt.local A +short                 # 192.168.137.10
dig ofppt.local SOA +short
dig ofppt.local NS +short

# MX + priorité 20
dig ofppt.local MX +short                     # 20 mx1.ofppt.local.

# CNAME smtp / imap
dig smtp.ofppt.local +short                   # mx1.ofppt.local. puis 192.168.137.30
dig imap.ofppt.local CNAME +short

# AAAA
dig mx1.ofppt.local AAAA +short               # 2002:db8:a:a::198

# PTR (zone inverse)
dig -x 192.168.137.30 +short                  # mx1.ofppt.local.

# Zones du TP5
dig www.ntic.local +short                     # 192.168.137.20
dig www.tri.local  +short                     # 192.168.137.20
dig _ldap._tcp.ntic.local SRV +short          # 20 200 389 ldap.ntic.local.

# TP6
dig centos1.ofppt.local +short                # 192.168.137.10
dig ftp.ofppt.local +short                    # 192.168.137.20

# Mêmes tests avec les deux autres outils demandés
nslookup www.ntic.local
host -t MX ofppt.local
host 192.168.137.30
```

**Test depuis un client (TP4-2 §III.9)** — à faire tourner depuis Linux B et depuis Windows :

```bash
# Linux B
nslookup www.ntic.local 192.168.137.10
dig @192.168.137.10 ftp.ofppt.local +short
```

```powershell
# Windows
nslookup www.ntic.local 192.168.137.10
nslookup -type=MX ofppt.local 192.168.137.10
```

Si `dig` répond mais que le client tombe en timeout : c'est le pare-feu de SRV1
(`firewall-cmd --add-service=dns`), pas Bind.

---

## 9. Ce qui doit figurer dans `TP4.doc`

- Le tableau de correspondance d'adressage (doc 00 §3).
- Pour chaque question numérotée : la commande **et** sa sortie réelle.
- Les 5 fichiers : `named.conf`, `ofppt.local.dir`, `192.168.137.rev`, `ntic.local.dir`,
  `tri.local.dir` (en annexe, avec les captures de `named-checkconf` / `named-checkzone`).
- Un paragraphe sur les **3 temporisations SOA** : refresh 2H = le secondaire demande « as-tu
  changé ? » toutes les 2 h ; retry 20M = si le maître ne répond pas, il réessaie toutes les
  20 min ; expire 1W = après une semaine sans maître, il cesse de répondre aux clients
  (pour ne pas servir des données périmées) ; negative TTL 1H = durée de cache d'un « ce nom
  n'existe pas ».
- Les écarts assumés : adressage transposé, zone inverse 192.168.137.0/24 au lieu de
  10.0.0.0/8, alias CNAME pour couvrir les 3 énoncés sur une seule machine.

---

## 10. Dépannage express

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `named` refuse de démarrer | syntaxe `named.conf` | `named-checkconf -z`, lire `/var/log/messages` |
| Bind démarre mais tout est `SERVFAIL` | `dnssec-validation` + pas d'accès Internet | déjà mis à `no` |
| `dig` → `connection timed out` | `firewalld` | `firewall-cmd --add-service=dns --reload` |
| `dig` → `REFUSED` | `allow-query` | remettre `{ any; };` |
| La zone ne se charge pas sans erreur visible | SELinux | `restorecon -Rv /var/named`, `ls -Z /var/named` |
| Le transfert de zone échoue depuis SRV2 | `allow-transfer` | vérifier l'IP source, `named-checkconf` |
| Perte d'Internet après bascule DNS | Bind arrêté ou forwarders faux | `systemctl status named`, tester `dig google.com @127.0.0.1` |
