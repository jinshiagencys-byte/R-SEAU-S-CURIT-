# 07 — Ubuntu 24.04 : la version exécutable sur TA machine

**À lire avant les documents 01, 02 et 03.** Ta machine est **Ubuntu 24.04.5 LTS**, pas
CentOS 7. Ce document donne, service par service, la configuration **complète et
copiable** pour Ubuntu, plus le tableau de correspondance CentOS ↔ Ubuntu à recopier dans
les rapports (l'énoncé est rédigé pour CentOS : il faut pouvoir justifier chaque écart).

Les documents 01, 02 et 03 restent la **référence pour la logique et pour le rapport** ;
c'est celui-ci que tu exécutes.

---

## 0. Le tableau à mettre dans chaque rapport

| Besoin | CentOS 7 (énoncé) | Ubuntu 24.04 (réel) |
|---|---|---|
| Paquets | `yum install` | `apt install` |
| Services | `systemctl` | `systemctl` (identique) |
| Réseau | `nmcli` / `ifcfg-eth0` | `nmcli` / **netplan** |
| Résolveur | `/etc/resolv.conf` direct | **systemd-resolved** (à neutraliser) |
| DNS | `bind`, service `named` | `bind9`, service `bind9` |
| Conf DNS | `/etc/named.conf` | `/etc/bind/named.conf.local` + `.options` |
| Zones | `/var/named/` | `/etc/bind/zones/` (ou `/var/cache/bind/`) |
| DHCP | `dhcp` | `isc-dhcp-server` |
| Conf DHCP | `/etc/dhcp/dhcpd.conf` | identique |
| Interface DHCP | `/etc/sysconfig/dhcpd` | `/etc/default/isc-dhcp-server` |
| Web | `httpd` | `apache2` |
| Sites | `/etc/httpd/conf.d/*.conf` | `/etc/apache2/sites-available/` + `a2ensite` |
| Logs web | `/var/log/httpd/` | `/var/log/apache2/` |
| Utilisateur web | `apache` | `www-data` |
| FTP | `vsftpd`, conf `/etc/vsftpd/vsftpd.conf`, liste de refus `/etc/vsftpd/ftpusers` | `vsftpd`, conf `/etc/vsftpd.conf`, liste de refus **`/etc/ftpusers`** |
| Samba | `samba` | `samba` (identique) |
| NFS | `nfs-utils` | `nfs-kernel-server` / `nfs-common` |
| Pare-feu | `firewalld` (`firewall-cmd`) | **`ufw`** |
| Contrôle d'accès | **SELinux** (`setsebool`, `chcon`) | **AppArmor** (`apparmor_parser`) |
| Journal | `/var/log/messages` | `journalctl` |

**Phrase à mettre dans les rapports** : « Le laboratoire réel est sous Ubuntu 24.04 ; les
services demandés (Bind, ISC DHCP, Apache, vsftpd, Samba, NFS) sont les mêmes que sous
CentOS 7. Les différences portent sur les noms de paquets, l'emplacement des fichiers de
configuration et le module de sécurité (AppArmor au lieu de SELinux). Le tableau
d'équivalence ci-dessus donne la correspondance commande par commande. »

---

## 1. Réseau et IP fixe (remplace le doc 00 §5.2)

`nmcli` existe aussi sur Ubuntu (NetworkManager est le backend du bureau). Les commandes du
doc 00 §5.2 fonctionnent telles quelles. Deux différences :

```bash
# Nom du profil = le SSID du hotspot
nmcli -t -f NAME,DEVICE connection show --active

sudo nmcli connection modify "NOM_DU_WIFI" \
     ipv4.method manual ipv4.addresses 192.168.137.10/24 \
     ipv4.gateway 192.168.137.1 \
     ipv4.dns "127.0.0.1,192.168.137.1" ipv4.dns-search "ofppt.local"
sudo nmcli connection up "NOM_DU_WIFI"

hostnamectl set-hostname srv1.ofppt.local      # identique
```

Vérification : `ip -4 a`, `ip r`, `ping -c2 192.168.137.1`.

> Version serveur (sans bureau) : le même réglage se fait en **netplan**, dans
> `/etc/netplan/50-cloud-init.yaml` puis `sudo netplan apply`. À utiliser seulement si
> `nmcli` n'est pas installé.

---

## 2. Le piège n°1 d'Ubuntu : systemd-resolved

Sur Ubuntu, le port 53 est déjà occupé par `systemd-resolved` via l'adresse `127.0.0.53`.
Bind démarre quand même, mais **toutes tes requêtes partent vers resolved, pas vers ton
serveur**. Résultat : `dig` interroge ton bind, mais le navigateur et `ping` non — et tu
crois que la zone est fausse.

```bash
# 1. Écouter ce qui occupe le port 53
sudo ss -lntup | grep :53          # → systemd-resolve sur 127.0.0.53:53

# 2. Neutraliser le stub de systemd-resolved
sudo systemctl disable --now systemd-resolved
sudo systemctl mask systemd-resolved

# 3. Empêcher NetworkManager de réécrire /etc/resolv.conf
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/99-no-dns.conf >/dev/null <<'EOF'
[main]
dns=none
EOF
sudo systemctl restart NetworkManager

# 4. Pointer le résolveur sur NOTRE bind
sudo rm -f /etc/resolv.conf            # c'est un lien symbolique, il faut le supprimer
sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 127.0.0.1
search ofppt.local
EOF

# 5. Contrôle
resolvectl status 2>/dev/null | head -5      # doit échouer : c'est normal
cat /etc/resolv.conf
```

**Retour arrière** (fin de TP, pour rendre la machine à la vie normale) :

```bash
sudo systemctl unmask systemd-resolved && sudo systemctl enable --now systemd-resolved
sudo rm -f /etc/resolv.conf && sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo rm /etc/NetworkManager/conf.d/99-no-dns.conf
```

---

## 3. DNS : bind9 (remplace le doc 01 §2 à §8)

### 3.1 Installation

```bash
# TP4-2 §II : vérifier la présence du paquet
dpkg -l | grep -E '^ii\s+bind9'

sudo apt update
sudo apt install -y bind9 bind9utils bind9-dnsutils
```

| Question TP4-2 §II | Commande Ubuntu |
|---|---|
| §1 le paquet existe ? | `dpkg -l \| grep bind9` |
| §2 install par paquet local | `sudo dpkg -i bind9_*.deb` (rarement utile) |
| §3 install par gestionnaire | `sudo apt install bind9 bind9utils bind9-dnsutils` |
| §4 voir les fichiers | `dpkg -L bind9` |
| §5 port | `sudo ss -lntup \| grep :53` → 53/tcp et 53/udp |

### 3.2 Options générales : `/etc/bind/named.conf.options`

```bash
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.orig
sudo tee /etc/bind/named.conf.options >/dev/null <<'EOF'
options {
    directory "/var/cache/bind";

    listen-on port 53 { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;

    forwarders { 192.168.137.1; 212.217.0.12; };
    dnssec-validation no;   /* pas d'Internet garanti en TP */
};
EOF
```

### 3.3 Déclaration des zones : `/etc/bind/named.conf.local`

```bash
sudo tee /etc/bind/named.conf.local >/dev/null <<'EOF'
zone "ofppt.local" {
    type master;
    file "/etc/bind/zones/ofppt.local.dir";
    allow-transfer { 192.168.137.20; };
    notify yes;
    also-notify { 192.168.137.20; };
    allow-update { none; };
};

zone "ntic.local" {
    type master;
    file "/etc/bind/zones/ntic.local.dir";
    allow-transfer { 192.168.137.20; };
    notify yes;
    allow-update { none; };
};

zone "tri.local" {
    type master;
    file "/etc/bind/zones/tri.local.dir";
    allow-transfer { 192.168.137.20; };
    notify yes;
    allow-update { none; };
};

zone "137.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/192.168.137.rev";
    allow-transfer { 192.168.137.20; };
    notify yes;
    allow-update { 192.168.137.10; };
};
EOF
```

### 3.4 Fichiers de zone

⚠️ Le `directory` de Bind vaut `/var/cache/bind`, mais **les fichiers de zone vont dans
`/etc/bind/zones/`** : c'est le dossier autorisé par le profil AppArmor d'Ubuntu. Ne pas
mettre les zones dans `/var/cache/bind` (elles seraient écrasées / bloquées).

```bash
sudo mkdir -p /etc/bind/zones

sudo tee /etc/bind/zones/ofppt.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN ofppt.local.
@       IN  SOA srv1.ofppt.local. admin.ofppt.local. (
                2026102701 ; serial
                2H         ; refresh  -> TP4-1 §7
                20M        ; retry    -> TP4-1 §7
                1W         ; expire   -> TP4-1 §7
                1H )       ; negative TTL
        IN  NS      srv1.ofppt.local.
        IN  NS      srv2.ofppt.local.
        IN  MX      20 mx1.ofppt.local.

mx1     IN  A       192.168.137.30
        IN  AAAA    2002:db8:a:a::198
smtp    IN  CNAME   mx1
imap    IN  CNAME   mx1
@       IN  A       192.168.137.10
srv1    IN  A       192.168.137.10
srv2    IN  A       192.168.137.20
ldap    IN  A       192.168.137.40
pc01    IN  A       192.168.137.1
centos1 IN  CNAME   srv1
ista    IN  CNAME   srv1
centos2 IN  CNAME   srv2
www     IN  A       192.168.137.20
ftp     IN  A       192.168.137.20
samba   IN  CNAME   srv2
EOF

sudo tee /etc/bind/zones/ntic.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN ntic.local.
@       IN  SOA srv1.ntic.local. admin.ntic.local. ( 2026102701 2H 20M 1W 1H )
        IN  NS      srv1.ntic.local.
        IN  NS      srv2.ntic.local.
srv1    IN  A       192.168.137.10
srv2    IN  A       192.168.137.20
www     IN  A       192.168.137.20
ftp     IN  CNAME   srv2
ldap    IN  A       192.168.137.40
_ldap._tcp  IN SRV  20 200 389 ldap.ntic.local.
@       IN  MX      20 mail.ntic.local.
mail    IN  A       192.168.137.30
        IN  AAAA    2001:660:3006:2::402
EOF

sudo tee /etc/bind/zones/tri.local.dir >/dev/null <<'EOF'
$TTL 1H
$ORIGIN tri.local.
@       IN  SOA srv1.tri.local. admin.tri.local. ( 2026102701 2H 20M 1W 1H )
        IN  NS      srv1.tri.local.
srv1    IN  A       192.168.137.10
srv2    IN  A       192.168.137.20
www     IN  A       192.168.137.20
EOF

sudo tee /etc/bind/zones/192.168.137.rev >/dev/null <<'EOF'
$TTL 1H
$ORIGIN 137.168.192.in-addr.arpa.
@       IN  SOA srv1.ofppt.local. admin.ofppt.local. ( 2026102701 2H 20M 1W 1H )
        IN  NS      srv1.ofppt.local.
        IN  NS      srv2.ofppt.local.
30      IN  PTR     mx1.ofppt.local.
10      IN  PTR     srv1.ofppt.local.
20      IN  PTR     srv2.ofppt.local.
40      IN  PTR     ldap.ofppt.local.
1       IN  PTR     pc01.ofppt.local.
EOF

# Droits : Bind tourne sous l'utilisateur "bind"
sudo chown -R root:bind /etc/bind/zones
sudo chmod 640 /etc/bind/zones/*
```

### 3.5 Contrôle et démarrage

```bash
sudo named-checkconf
sudo named-checkzone ofppt.local        /etc/bind/zones/ofppt.local.dir
sudo named-checkzone ntic.local         /etc/bind/zones/ntic.local.dir
sudo named-checkzone tri.local          /etc/bind/zones/tri.local.dir
sudo named-checkzone 137.168.192.in-addr.arpa /etc/bind/zones/192.168.137.rev

sudo systemctl enable --now bind9
sudo systemctl status bind9 --no-pager
sudo ss -lntup | grep :53

sudo ufw allow 53        # ufw est inactif par défaut sur Ubuntu, mais autant être prêt
```

> `systemctl status bind9` affiche `named.service` : c'est normal, `bind9` est un alias.

### 3.6 Les tests du doc 01 §8 restent valables

```bash
dig @127.0.0.1 srv1.ofppt.local +short
dig @127.0.0.1 ofppt.local MX +short
dig @127.0.0.1 smtp.ofppt.local +short
dig @127.0.0.1 -x 192.168.137.30 +short
dig @127.0.0.1 www.ntic.local +short
dig @127.0.0.1 _ldap._tcp.ntic.local SRV +short
```

**Toujours mettre `@127.0.0.1` explicite** tant que tu n'as pas fait le §2 de ce document.
Sans ça tu interroges `systemd-resolved` et tu crois que Bind est cassé.

---

## 4. DHCP : isc-dhcp-server (pour le TP3, si tu le fais sur ta machine)

Le doc 04 (VirtualBox + CentOS 7) reste la méthode recommandée pour le TP3. Si tu veux le
faire en local sous Ubuntu :

```bash
sudo apt install -y isc-dhcp-server

# Quelle interface ? (le nom n'est pas "eth0" sur Ubuntu récent)
ip -br a

sudo tee /etc/default/isc-dhcp-server >/dev/null <<'EOF'
INTERFACESv4="enp3s0"
INTERFACESv6=""
EOF

# /etc/dhcp/dhcpd.conf : reprendre exactement le contenu du doc 04 §C.1

sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf     # contrôle de syntaxe (identique)
sudo systemctl enable --now isc-dhcp-server
sudo systemctl status isc-dhcp-server --no-pager
journalctl -u isc-dhcp-server -f
cat /var/lib/dhcp/dhcpd.leases
```

Trois pièges Ubuntu :

1. **Le nom d'interface** : `enp3s0`, `wlp2s0`, `enx…`. `DHCPDARGS` devient
   `INTERFACESv4` dans `/etc/default/isc-dhcp-server`.
2. **AppArmor** : le profil `usr.sbin.dhcpd` limite les chemins. Si le bail n'est pas écrit :
   `sudo aa-complain /usr/sbin/dhcpd`, relancer, refaire le test, puis `aa-enforce`.
3. **Le service refuse de démarrer** si l'interface listée n'a pas d'IP dans le sous-réseau
   déclaré : `journalctl -u isc-dhcp-server`.

---

## 5. Apache2 (remplace le doc 02 §A)

### 5.1 Installation et modules

```bash
dpkg -l | grep -E '^ii\s+apache2'
sudo apt install -y apache2
sudo a2enmod ssl
sudo a2dissite 000-default
```

Le `Listen 443` est déjà géré par `/etc/apache2/ports.conf` (bloc `IfModule ssl_module`) :
**ne pas** l'ajouter à la main, contrairement à CentOS.

### 5.2 Les sites

```bash
sudo mkdir -p /var/www/html/tri /var/www/html/ntic
sudo mkdir -p /var/log/apache2/tri /var/log/apache2/ntic

sudo tee /etc/apache2/sites-available/tri.conf >/dev/null <<'EOF'
<VirtualHost *:80>
    ServerName    www.tri.local
    ServerAlias   tri.local
    DocumentRoot  /var/www/html/tri
    ErrorLog      /var/log/apache2/tri/error.log
    CustomLog     /var/log/apache2/tri/access.log combined
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/ntic.conf >/dev/null <<'EOF'
<VirtualHost *:80>
    ServerName    www.ntic.local
    ServerAlias   ntic.local
    DocumentRoot  /var/www/html/ntic
    ErrorLog      /var/log/apache2/ntic/error.log
    CustomLog     /var/log/apache2/ntic/access.log combined
    Redirect permanent / https://www.ntic.local/
</VirtualHost>

<VirtualHost *:443>
    ServerName    www.ntic.local
    DocumentRoot  /var/www/html/ntic
    ErrorLog      /var/log/apache2/ntic/error.log
    CustomLog     /var/log/apache2/ntic/access.log combined
    SSLEngine             on
    SSLCertificateFile    /etc/apache2/ssl/server.crt
    SSLCertificateKeyFile /etc/apache2/ssl/server.key
    SSLProtocol           -all +TLSv1.2
</VirtualHost>
EOF

sudo a2ensite tri.conf ntic.conf
```

Les deux `index.html` sont identiques au doc 02 §A.4 (mêmes fichiers, mêmes chemins).

### 5.3 Certificat

```bash
sudo mkdir -p /etc/apache2/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -out /etc/apache2/ssl/server.crt -keyout /etc/apache2/ssl/server.key \
     -subj "/C=MA/ST=Oujda/L=Oujda/O=OFPPT/OU=TRI/CN=www.ntic.local"
```

### 5.4 Contrôle

```bash
sudo apache2ctl configtest        # doit afficher Syntax OK
sudo systemctl reload apache2
sudo systemctl status apache2 --no-pager
sudo ss -lntp | grep -E ':(80|443)'

sudo ufw allow 'Apache Full'
```

> Sur Ubuntu, le serveur tourne sous `www-data` et `/var/www` est déjà autorisé par
> AppArmor : contrairement à CentOS, **il n'y a pas de `chcon` à faire**.

---

## 6. vsftpd (remplace le doc 02 §B)

```bash
dpkg -l | grep vsftpd || sudo apt install -y vsftpd
getent group ftp ; getent passwd ftp     # Ubuntu crée aussi ftp:nogroup
```

Le fichier de configuration est **`/etc/vsftpd.conf`** (et non `/etc/vsftpd/vsftpd.conf`).
Le contenu du doc 02 §B.2 est valable **à une exception près** : la liste de refus PAM.

| Élément | CentOS 7 | Ubuntu 24.04 |
|---|---|---|
| Conf | `/etc/vsftpd/vsftpd.conf` | `/etc/vsftpd.conf` |
| Liste de refus PAM (§P4-4) | `/etc/vsftpd/ftpusers` | **`/etc/ftpusers`** |
| Liste `user_list` | `/etc/vsftpd/user_list` | `/etc/vsftpd.user_list` |
| Utilisateur du service | `root` | `root` |

Donc, pour bloquer `ftpaccess` :

```bash
echo 'ftpaccess' | sudo tee -a /etc/ftpusers
```

Et dans `/etc/vsftpd.conf`, remplacer `userlist_file=/etc/vsftpd/user_list` par
`userlist_file=/etc/vsftpd.user_list`.

Pare-feu et AppArmor :

```bash
sudo ufw allow 21/tcp
sudo ufw allow 30000:30100/tcp
sudo aa-status | grep vsftpd      # très souvent en mode "complain" par défaut : rien à faire
```

Le reste (remplacement de `vsftpd.conf`, comptes, chroot, tests) est **identique** au doc 02.

---

## 7. Samba (remplace le doc 02 §C)

Mêmes paquets, même `/etc/samba/smb.conf`, mêmes commandes (`testparm`, `smbpasswd -a`,
`pdbedit -L`, `smbclient`). Trois différences :

```bash
sudo apt install -y samba samba-client cifs-utils
sudo systemctl enable --now smbd nmbd        # noms de service identiques

sudo ufw allow Samba
```

**Le remplacement de SELinux = AppArmor.** Par défaut, le profil `smbd` d'Ubuntu n'autorise
que `/home`, `/srv`, `/var`, `/tmp`… Un partage dans `/decouverte` est **refusé** sans
message clair côté client (`NT_STATUS_ACCESS_DENIED`). Il faut déclarer le chemin :

```bash
sudo mkdir -p /etc/apparmor.d/local
sudo tee -a /etc/apparmor.d/local/usr.sbin.smbd >/dev/null <<'EOF'

# TP9 - partage /decouverte
/decouverte/ rwk,
/decouverte/** rwk,
EOF

sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.smbd
sudo systemctl restart smbd

# vérification
sudo aa-status | grep smbd
sudo dmesg | grep -i apparmor | tail -5      # les refus éventuels
```

> C'est l'équivalent exact de `chcon -Rt samba_share_t /decouverte` +
> `setsebool -P samba_export_all_rw on` sous CentOS. À expliquer dans le rapport : c'est
> le seul écart vraiment technique entre les deux distributions.

---

## 8. NFS (remplace le doc 03)

```bash
# Serveur (SRV2)
sudo apt install -y nfs-kernel-server
sudo systemctl enable --now nfs-kernel-server

# /etc/exports : contenu identique au doc 03 §2.3
sudo exportfs -rav
sudo exportfs -v
showmount -e localhost

# Client (SRV1)
sudo apt install -y nfs-common
```

Pare-feu (à la place des services `nfs mountd rpc-bind`) :

```bash
sudo ufw allow from 192.168.137.0/24 to any port 2049 proto tcp
sudo ufw allow from 192.168.137.0/24 to any port 2049 proto udp
sudo ufw allow from 192.168.137.0/24 to any port 111  proto tcp
sudo ufw allow from 192.168.137.0/24 to any port 111  proto udp
sudo ufw allow from 192.168.137.0/24 to any port 20048
```

Pas de `setsebool` : Ubuntu n'a pas de SELinux. Le reste (montages, `fstab`, tests,
problème d'UID de `khadija`) est **identique** au doc 03.

---

## 9. ufw : le tableau de conversion

`ufw` est **inactif par défaut** sur Ubuntu : tant que tu ne l'actives pas, rien n'est
bloqué. Si tu l'actives pour le rapport (`sudo ufw enable`), ouvre d'abord SSH si tu es à
distance (pas ton cas).

| Service | CentOS (`firewall-cmd`) | Ubuntu (`ufw`) |
|---|---|---|
| DNS | `--add-service=dns` | `ufw allow 53` |
| HTTP | `--add-service=http` | `ufw allow 80/tcp` |
| HTTPS | `--add-service=https` | `ufw allow 443/tcp` |
| Apache (les deux) | — | `ufw allow 'Apache Full'` |
| FTP | `--add-service=ftp` | `ufw allow 21/tcp` |
| FTP passif | `--add-port=30000-30100/tcp` | `ufw allow 30000:30100/tcp` |
| Samba | `--add-service=samba` | `ufw allow Samba` |
| NFS | `--add-service=nfs` | `ufw allow from 192.168.137.0/24 to any port 2049` |
| État | `firewall-cmd --list-all` | `ufw status verbose` |

---

## 10. AppArmor : ce qu'il faut savoir pour le rapport

| | SELinux (CentOS) | AppArmor (Ubuntu) |
|---|---|---|
| Modèle | étiquettes sur les fichiers | chemins autorisés par profil |
| Voir l'état | `getenforce` | `aa-status` |
| Contexte d'un fichier | `ls -Z` | — (pas de contexte) |
| Autoriser un partage Samba | `chcon -t samba_share_t` + `setsebool -P samba_export_all_rw on` | ajout de chemin dans `/etc/apparmor.d/local/usr.sbin.smbd` + `apparmor_parser -r` |
| Autoriser un export NFS | `setsebool -P nfs_export_all_rw on` | rien à faire |
| Contexte web | `chcon -t httpd_sys_content_t` | rien à faire (`/var/www` déjà autorisé) |
| Mode permissif | `setenforce 0` | `aa-complain /usr/sbin/<service>` |

C'est exactement l'argument à écrire quand l'énoncé dit « désactiver SELinux » : sous
Ubuntu, il n'y a pas de SELinux, et la bonne pratique est de garder AppArmor actif.

---

## 11. Ce qui change dans la répartition

| Qui | Machine | Système | Docs à utiliser |
|---|---|---|---|
| Linux A (toi) | SRV1 | **Ubuntu 24.04** | `00` + `07` §1-3 + `01` (logique/rapport) |
| Linux B | SRV2 | Ubuntu ou CentOS — à préciser | `00` + `07` (si Ubuntu) ou `02` tel quel (si CentOS) |
| Windows | PC01 | Windows | `04` (VM CentOS 7, indépendant de l'hôte) |

**Demande à Linux B son `cat /etc/os-release` avant de lui envoyer le doc 02.** S'il est
sous Ubuntu, il utilise `07` ; sous CentOS, `02` directement.

---

## 12. Récapitulatif des paquets à installer

```bash
# SRV1 (DNS)
sudo apt install -y bind9 bind9utils bind9-dnsutils

# SRV2 (services)
sudo apt install -y apache2 vsftpd samba samba-client cifs-utils nfs-kernel-server nfs-common

# Utilitaires utiles partout
sudo apt install -y net-tools dnsutils curl tcpdump openssh-server
```

Une seule commande pour tout installer sur une machine qui fait les deux rôles :

```bash
sudo apt update && sudo apt install -y \
  bind9 bind9utils bind9-dnsutils \
  apache2 vsftpd samba samba-client cifs-utils \
  nfs-kernel-server nfs-common \
  net-tools dnsutils curl tcpdump
```
