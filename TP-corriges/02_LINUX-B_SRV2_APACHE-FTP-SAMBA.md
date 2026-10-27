# 02 — Linux B / SRV2 : Apache, FTP, Samba (+ DNS esclave)

> ## 🚨 SRV2 EST SOUS UBUNTU 24.04
>
> **Ce document n'est pas à exécuter tel quel.** Il est écrit pour CentOS 7 : il sert de
> **référence pour la rédaction du rapport** (logique, contenu des fichiers, questions).
>
> Les commandes à taper réellement sont dans **`07_UBUNTU-24.04.md`** :
>
> | Partie | Sujet | Où exécuter |
> |---|---|---|
> | A | Apache + SSL (TP5 p.2-4) | `07` **§5** |
> | B | vsftpd (TP6 p.2-4) | `07` **§6** |
> | C | Samba (TP9) | `07` **§7** |
> | D | DNS esclave (TP4-2 §IV) | `07` **§3** (adapter en `type slave`) |
> | — | Pare-feu | `07` **§9** (ufw, pas firewalld) |
> | — | Sécurité | `07` **§10** (AppArmor, pas SELinux) |
>
> Le contenu des fichiers de configuration (`smb.conf`, `vsftpd.conf`, `vhosts`) est
> **identique** : seuls les chemins, les noms de paquets et le module de sécurité changent.
> Le déroulé complet, dans l'ordre, est en **`07` §13**.

**Couvre :** TP5 parties 2, 3 et 4 (Apache + SSL) · TP6 parties 2, 3 et 4 (FTP) ·
TP9 (Samba) · TP4-2 §IV (DNS secondaire, bonus).

**Machine :** `srv2.ofppt.local` — `192.168.137.20/24` — passerelle `192.168.137.1` —
DNS `192.168.137.10` — **Ubuntu 24.04.5 LTS**.

**À faire après le document 01** : SRV1 doit déjà répondre pour `www.tri.local`,
`www.ntic.local`, `ftp.ofppt.local`.


---

## 0. Préparation

```bash
sudo hostnamectl set-hostname srv2.ofppt.local

# NOM_DU_WIFI = nom du profil NetworkManager (voir doc 00 §5.2)
CON="$(nmcli -g NAME,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
sudo nmcli connection modify "$CON" \
     ipv4.method manual ipv4.addresses 192.168.137.20/24 \
     ipv4.gateway 192.168.137.1 ipv4.dns "192.168.137.1" \
     ipv4.dns-search "ofppt.local"
sudo nmcli connection up "$CON"

sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
EOF

# Contrôle : Internet (indispensable pour apt)
# Attention : ping 8.8.8.8 échoue sur ce réseau même quand tout marche (ICMP filtré).
curl -sI --max-time 8 https://deb.debian.org | head -1
```

> ⚠️ **DNS : `192.168.137.1` pour l'instant.** Tant que le Bind de SRV1 n'est pas démarré,
> mettre `192.168.137.10` en premier DNS fait attendre 5 s à chaque résolution (et ralentit
> `apt`). Dès que 🅰 annonce que le DNS est opérationnel, bascule :
>
> ```bash
> sudo nmcli connection modify "$CON" ipv4.dns "192.168.137.10,192.168.137.1"
> sudo nmcli connection up "$CON"
> dig www.ntic.local +short        # doit renvoyer 192.168.137.20
> ```
>
> Ne **coupe pas** `systemd-resolved` sur SRV2 : c'est un client, pas le serveur.

Rappel CentOS 7 en fin de vie (si `yum` échoue) : voir `00_PLAN_ET_RESEAU.md` §6.1.

---

# PARTIE A — TP5 : serveur Web Apache + SSL

## A.1 Installation

```bash
# TP5 P2 §3 : le paquet est-il là ?
rpm -qa | grep -i httpd
sudo yum install -y httpd mod_ssl
```

## A.2 Arborescence (TP5 P2 §4-5, §7-8)

```bash
# Répertoires racine des 2 sites
sudo mkdir -p /var/www/html/tri /var/www/html/ntic

# Répertoires de logs des 2 sites
sudo mkdir -p /var/log/httpd/tri /var/log/httpd/ntic
sudo chown -R root:root /var/log/httpd/tri /var/log/httpd/ntic
```

> **Écart assumé** : l'énoncé donne comme « chemin de journal des erreurs »
> `/var/log/httpd/tri`. Une directive `ErrorLog` d'Apache attend un **fichier**, pas un
> répertoire : on crée un répertoire par site et on logue dans
> `/var/log/httpd/tri/error.log` et `/var/log/httpd/ntic/error.log`. À signaler dans le
> rapport — c'est le genre de détail qui montre que vous avez compris la directive.

## A.3 Les deux hôtes virtuels (TP5 P2 §6)

TP5 P2 §6 demande « la même adresse IP (172.30.3.3) et le même port 80 » pour les deux sites :
c'est du **virtual hosting par nom**, et l'IP 172.30.3.3 devient 192.168.137.20.

```bash
sudo tee /etc/httpd/conf.d/vhosts.conf >/dev/null <<'EOF'
Listen 443

# ---- www.tri.local : HTTP simple ----
<VirtualHost *:80>
    ServerName    www.tri.local
    ServerAlias   tri.local
    DocumentRoot  /var/www/html/tri
    ErrorLog      /var/log/httpd/tri/error.log
    CustomLog     /var/log/httpd/tri/access.log combined
</VirtualHost>

# ---- www.ntic.local : HTTP, redirigé vers HTTPS (TP5 P4 §3) ----
<VirtualHost *:80>
    ServerName    www.ntic.local
    ServerAlias   ntic.local
    DocumentRoot  /var/www/html/ntic
    ErrorLog      /var/log/httpd/ntic/error.log
    CustomLog     /var/log/httpd/ntic/access.log combined
    Redirect permanent / https://www.ntic.local/
</VirtualHost>

# ---- www.ntic.local : HTTPS (TP5 P4) ----
<VirtualHost *:443>
    ServerName    www.ntic.local
    DocumentRoot  /var/www/html/ntic
    ErrorLog      /var/log/httpd/ntic/error.log
    CustomLog     /var/log/httpd/ntic/access.log combined

    SSLEngine             on
    SSLCertificateFile    /etc/httpd/server.crt
    SSLCertificateKeyFile /etc/httpd/server.key
    SSLProtocol           -all +TLSv1.2
</VirtualHost>
EOF
```

Désactiver le vhost 443 par défaut livré avec `mod_ssl`, sinon il peut capter les requêtes :

```bash
sudo mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.desactive
```

(`Listen 443` a été ajouté en tête de `vhosts.conf`, sinon Apache n'ouvrirait pas le port.)

## A.4 Pages d'accueil (TP5 P2 §7-8)

```bash
# www.tri.local — texte imposé par l'énoncé
sudo tee /var/www/html/tri/index.html >/dev/null <<'EOF'
<html><head><title>TRI Offshore</title></head>
<body><h1>Bienvenue sur le site TRI Offshore</h1></body></html>
EOF

# www.ntic.local — page imposée par l'énoncé (recopiée telle quelle)
sudo tee /var/www/html/ntic/index.html >/dev/null <<'EOF'
<html>
  <head>
    <title>Welcome to ntic.local</title>
    <style>
      body {
        color: blue;
        text-decoration: underline;
        font-size: 42px;
      }
    </style>
  </head>
  <body>
    <p>l’Exemple de virtual host NTIC fonctionne </p>
  </body>
</html>
EOF
```

## A.5 Certificat SSL (TP5 P4 §2)

```bash
# Le mode SSL est-il présent ?
rpm -qa | grep mod_ssl          # sinon : sudo yum install -y mod_ssl

# Génération du certificat auto-signé (commande de l'énoncé)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -out /etc/httpd/server.crt -keyout /etc/httpd/server.key \
     -subj "/C=MA/ST=Oujda/L=Oujda/O=OFPPT/OU=TRI/CN=www.ntic.local"
```

> **Écart assumé** : l'énoncé impose `rsa:1024`. Cette taille est aujourd'hui refusée par les
> navigateurs récents et par TLS 1.2 moderne. On utilise **2048 bits** et on explique
> pourquoi dans le rapport. (Si le prof tient à 1024, la commande d'origine marche toujours
> pour Apache, mais Firefox/Chrome afficheront une erreur.)

## A.6 Contexte SELinux et pare-feu

```bash
# Contexte des contenus web + des logs
sudo restorecon -Rv /var/www/html
sudo chcon -Rv -t httpd_sys_content_t /var/www/html/tri /var/www/html/ntic
sudo chcon -Rv -t httpd_log_t /var/log/httpd/tri /var/log/httpd/ntic

# Certificat lisible par Apache
sudo chown root:root /etc/httpd/server.key && sudo chmod 400 /etc/httpd/server.key

# Ports
sudo firewall-cmd --permanent --add-service=http --add-service=https
sudo firewall-cmd --reload
```

## A.7 Vérification et démarrage (TP5 P2 §9-10)

```bash
sudo apachectl configtest        # attendu : Syntax OK
sudo systemctl enable --now httpd
sudo systemctl status httpd --no-pager

sudo ss -lntp | grep -E ':(80|443)'
```

## A.8 Tests (TP5 P3)

Depuis SRV2 :

```bash
curl -s http://www.tri.local | grep -o 'Bienvenue.*Offshore'
curl -sI http://www.ntic.local | head -3        # doit renvoyer 301 -> https://www.ntic.local/
curl -sk https://www.ntic.local | grep -o 'virtual host NTIC fonctionne'
```

Depuis PC01 (Windows) — **c'est PC01 qui est noté pour le TP5 P3** :

1. Mettre le DNS de la carte à `192.168.137.10` (§5.3 du doc 00).
2. Navigateur → `http://www.tri.local` → « Bienvenue sur le site TRI Offshore ».
3. Navigateur → `http://www.ntic.local` → doit **basculer tout seul** en `https://`
   (avertissement de certificat : « Avancé » → « Continuer »), page bleue soulignée.
4. `nslookup www.tri.local 192.168.137.10` dans un cmd → 192.168.137.20.

Captures à faire : les deux pages, l'URL en `https://`, l'avertissement du certificat, et
l'alerte « Nom d'hôte dans le journal des erreurs » si vous la montrez.

## A.9 Dépannage Apache

| Symptôme | Cause | Correctif |
|---|---|---|
| `403 Forbidden` | SELinux | `ls -Z /var/www/html/tri`, `restorecon -Rv`, `chcon -t httpd_sys_content_t` |
| Le mauvais site s'affiche pour les deux noms | vhost par défaut | `httpd -S` pour voir l'ordre de résolution |
| `http://www.ntic.local` ne redirige pas | `ssl.conf` encore actif | le neutraliser : `mv ssl.conf ssl.conf.desactive` |
| Accès depuis Windows KO mais OK en local | `firewalld` | `firewall-cmd --list-services` |
| `AH00526: Syntax error` sur `SSLProtocol` | vieux mod_ssl | `SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1` |

---

# PARTIE B — TP6 : serveur FTP (vsftpd)

> ⚠️ **Lancer `script` maintenant** : `script ScTP6.txt`. Tout le TP6 doit être enregistré,
> c'est explicitement demandé par l'énoncé. Ne l'arrêtez qu'à la fin de la partie C.

## B.1 Installation et prérequis

```bash
# TP6 P2 §3
rpm -qa | grep -i vsftpd || sudo yum install -y vsftpd

# TP6 P2 §4 : le groupe et l'utilisateur ftp existent-ils ?
getent group ftp
getent passwd ftp
```

## B.2 Configuration `/etc/vsftpd/vsftpd.conf` (TP6 P2 §5)

Correspondance avec les 9 exigences de l'énoncé :

| Question | Directive |
|---|---|
| a. port 21 | `listen_port=21` (défaut) |
| b. pas d'accès anonyme | `anonymous_enable=NO` |
| c. bannière | `ftpd_banner=...` |
| d. utilisateurs locaux | `local_enable=YES` |
| e. 30 connexions max | `max_clients=30` |
| f. répertoires en 755 | `local_umask=022` |
| g. 6 connexions max par IP | `max_per_ip=6` |
| h. root interdit | `root` est déjà dans `/etc/vsftpd/ftpusers` |
| i. pas de `mkdir` anonyme | `anon_mkdir_write_enable=NO` |

```bash
sudo cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.orig
sudo tee /etc/vsftpd/vsftpd.conf >/dev/null <<'EOF'
# --- Écoute (a) ---
listen=YES
listen_ipv6=NO
listen_port=21

# --- Accès (b, d) ---
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022            # (f) : répertoires créés en 755, fichiers en 644

# --- Limites (e, g) ---
max_clients=30
max_per_ip=6

# --- Bannière (c) ---
ftpd_banner=Tout acces non autorise est interdit

# --- Journalisation ---
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
vsftpd_log_file=/var/log/vsftpd.log

# --- Sécurité : enfermer les utilisateurs chez eux (P4 §1) ---
chroot_local_user=YES
allow_writeable_chroot=YES
chroot_list_enable=NO

# --- Anonymes (i) ---
anon_mkdir_write_enable=NO
anon_upload_enable=NO
anon_other_write_enable=NO

# --- Listes d'accès utilisées en P4 §4 ---
userlist_enable=YES
userlist_deny=YES
userlist_file=/etc/vsftpd/user_list

# --- Mode passif (indispensable derrière un pare-feu) ---
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30100

pam_service_name=vsftpd
ssl_enable=NO
EOF
```

**Question h (root interdit)** : c'est déjà le cas par défaut, `root` figure dans
`/etc/vsftpd/ftpusers` (liste PAM « refusés »). On le vérifie, on ne le configure pas :

```bash
grep -w root /etc/vsftpd/ftpusers
```

## B.3 Comptes (TP6 P2 §7, P4 §3-4)

```bash
# ftpaccess / eff2017v31
sudo useradd -m -s /bin/bash ftpaccess
echo 'ftpaccess:eff2017v31' | sudo chpasswd

# P4 §3 : tri et ntic / ofppt
sudo useradd -m -s /bin/bash tri
sudo useradd -m -s /bin/bash ntic
echo 'tri:ofppt'  | sudo chpasswd
echo 'ntic:ofppt' | sudo chpasswd

# P4 §4 : bloquer ftpaccess -> on l'ajoute à la liste de refus PAM
echo 'ftpaccess' | sudo tee -a /etc/vsftpd/ftpusers
```

> **Remarque à mettre dans le rapport** : l'énoncé dit « bloquer l'accès à ftpaccess ». Le
> piège serait de l'ajouter à `user_list` (qui est la liste des autorisés/interdits de
> vsftpd) ; en `userlist_deny=YES` l'effet serait le même, mais `/etc/vsftpd/ftpusers` est
> la liste officielle de refus au niveau PAM : c'est la bonne méthode. En plus elle donne un
> message d'erreur propre (`530 Permission denied`).

## B.4 SELinux et pare-feu

```bash
# Autoriser l'accès FTP aux répertoires personnels
sudo setsebool -P ftp_home_dir on
sudo setsebool -P ftpd_full_access on      # à n'activer que si l'écriture échoue

sudo firewall-cmd --permanent --add-service=ftp
sudo firewall-cmd --permanent --add-port=30000-30100/tcp
sudo firewall-cmd --reload
```

## B.5 /etc/hosts pour le nom du TP6

Les home directories contiennent `centos2` : le nom existe en DNS (doc 01 §4), rien à faire.

## B.6 Démarrage et test local (TP6 P2 §6-8)

```bash
sudo systemctl enable --now vsftpd
sudo systemctl status vsftpd --no-pager
sudo ss -lntp | grep :21

# Test local
ftp 127.0.0.1
#  Name: ftpaccess      Password: eff2017v31
#  ftp> pwd             → /home/ftpaccess   (chroot actif)
#  ftp> ls
#  ftp> put /etc/hostname test.txt
#  ftp> get test.txt
#  ftp> bye

# root doit être refusé :
ftp 127.0.0.1    # Name: root  → 530 Permission denied
```

## B.7 Tests depuis PC01 (TP6 P3 et P4 §2-5)

En ligne de commande Windows (`cmd`) :

```
ftp 192.168.137.20
```
- avec `root` → **530 Permission denied** (exigence h) → capture d'écran.
- avec `ftpaccess` → **530 Permission denied** (bloqué en P4) → capture.
- avec `tri` / `ofppt` → connexion OK, `pwd` = `/`, `ls`, `put`, `get` → captures.

Avec **FileZilla** :
- Hôte `192.168.137.20`, port 21, utilisateur `tri`, mot de passe `ofppt`, « Connexion
  rapide ».
- Vérifier dans FileZilla que la navigation vers `C:\` ou `/etc` **remonte** en `/` :
  c'est le chroot (P4 §1-2). Capture du chemin affiché en « / » + message « 550 Failed to
  change directory to / ».

> **Incohérence à signaler** : TP6 P3 §3 demande de « se connecter en utilisateur root puis
> ftpaccess » alors que P2 §5h exige d'interdire root. On documente le refus de root comme
> la preuve que la configuration fonctionne.

## B.8 Dépannage FTP

| Symptôme | Cause | Correctif |
|---|---|---|
| `530 Login incorrect` sur un compte valide | shell nologin, ou mot de passe | `usermod -s /bin/bash ftpaccess` |
| Connexion OK, `ls` vide ou 500 | SELinux | `setsebool -P ftp_home_dir on`, `getsebool -a | grep ftp` |
| `425 Can't open data connection` | mode passif + pare-feu | ouvrir 30000-30100/tcp |
| `500 OOPS: vsftpd: refusing to run with writable root inside chroot` | `allow_writeable_chroot` manquant | ajouter la directive (déjà dans le fichier) |
| Écriture refusée pour `tri` | droits du home | `chmod 755 /home/tri` |

---

# PARTIE C — TP9 : Samba

## C.1 Groupes et utilisateurs (TP9 §7-9)

L'énoncé donne : *Hiba → recherche*, *Wahid → controle*, *Hamid → « Hamid »*. La colonne
« Hamid » n'est pas un groupe : c'est une coquille (et l'étape 9 parle de « deux
utilisateurs » alors qu'il y en a trois). **Choix retenu : Hamid est membre de `controle`**
(celui qui a les droits d'écriture). À écrire dans le rapport.

```bash
sudo yum install -y samba samba-client cifs-utils

sudo groupadd recherche
sudo groupadd controle

sudo useradd -m -G recherche hiba
sudo useradd -m -G controle  wahid
sudo useradd -m -G controle  hamid

# mots de passe système (non utilisés par Samba, mais demandés par useradd)
echo 'hiba:Ofppt2026!'  | sudo chpasswd
echo 'wahid:Ofppt2026!' | sudo chpasswd
echo 'hamid:Ofppt2026!' | sudo chpasswd

# mots de passe Samba (base tdbsam) — TP9 §9
sudo smbpasswd -a hiba
sudo smbpasswd -a wahid
sudo smbpasswd -a hamid
sudo pdbedit -L                      # vérification
```

## C.2 Arborescence du partage (TP9 §11)

```bash
sudo mkdir -p /decouverte
sudo chown root:controle /decouverte
sudo chmod 2775 /decouverte           # setgid : les nouveaux fichiers héritent du groupe

echo "TP Samba - fichier de test"  | sudo tee /decouverte/tp.txt
echo "Cours administration réseau" | sudo tee /decouverte/cour.txt

# Contexte SELinux du partage
sudo chcon -Rt samba_share_t /decouverte
sudo ls -Zd /decouverte
```

## C.3 `/etc/smb.conf` (TP9 §10 et §12)

```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.orig
sudo tee /etc/samba/smb.conf >/dev/null <<'EOF'
[global]
   workgroup = SAMBA                      # TP9 §10a
   server string = SRV2 OFPPT
   netbios name = SRV2
   security = user                        # TP9 §10b : base de comptes Samba
   passdb backend = tdbsam
   map to guest = never                   # TP9 §12d : refus sans mot de passe
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no

[decouverte]                              # TP9 §12
   comment = Partages du TP9
   path = /decouverte
   browseable = yes                       # §12c : visible par les clients
   guest ok = no                          # §12d
   read only = yes
   valid users = @recherche, @controle
   write list = @controle                 # §12b : controle = lecture + écriture
   create mask = 0664
   directory mask = 0775
   force group = controle
EOF

sudo testparm -s                          # vérification de syntaxe
```

Lecture des droits :

- `@recherche` est dans `valid users` mais **pas** dans `write list` → lecture seule (§12a) ✔
- `@controle` est dans `write list` → lecture + écriture (§12b) ✔
- `browseable = yes` → visible dans le voisinage réseau (§12c) ✔
- `guest ok = no` + `map to guest = never` → connexion sans mot de passe refusée (§12d) ✔

## C.4 SELinux et pare-feu

```bash
sudo setsebool -P samba_export_all_rw on
sudo setsebool -P samba_enable_home_dirs on     # seulement si vous partagez des homes

sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --reload

sudo systemctl enable --now smb nmb
sudo systemctl status smb --no-pager
sudo ss -lntp | grep -E ':(139|445)'
```

## C.5 Test local au serveur (TP9 §14)

```bash
# Lister les partages
smbclient -L localhost -U hiba
smbclient -L localhost -N          # doit échouer : refus sans mot de passe

# Se connecter au partage et créer un dossier
smbclient //localhost/decouverte -U wahid
#  smb: \> ls
#  smb: \> mkdir dossier_wahid
#  smb: \> put /etc/hostname test.txt
#  smb: \> ls
#  smb: \> exit

# hiba doit pouvoir lire mais pas écrire :
smbclient //localhost/decouverte -U hiba
#  smb: \> ls          → OK, on voit tp.txt et cour.txt
#  smb: \> mkdir test  → NT_STATUS_ACCESS_DENIED
```

## C.6 Test depuis Windows (TP9 §15)

1. `\\192.168.137.20\decouverte` dans l'explorateur → demande d'identifiants → `wahid`.
2. Ouvrir `tp.txt`, écrire, créer un dossier, supprimer un fichier → autorisé.
3. Se reconnecter avec `hiba` (`net use \\192.168.137.20\decouverte /delete` puis re-accès)
   → lecture OK, création refusée.
4. Tenter un accès sans identifiant → refus (exigence §12d).
5. Clic droit → « Connecter un lecteur réseau » → capture du lecteur `Z:`.

Captures attendues : la fenêtre d'identifiants, le contenu du partage, le refus d'écriture
pour `hiba`, le refus en anonyme.

## C.7 Montage CIFS depuis un client Linux (TP9 §15, dernière ligne)

L'énoncé parle de « monter ce partage sur tiny » avec le compte root : `tiny` est un nom de
machine d'un autre TP. On monte depuis **SRV1** (Linux), ce qui est l'équivalent Linux de la
manipulation demandée :

```bash
sudo mkdir -p /mnt/decouverte
sudo mount -t cifs //192.168.137.20/decouverte /mnt/decouverte \
     -o username=wahid,uid=$(id -u),gid=$(id -g),vers=3.0
ls -l /mnt/decouverte
cat /mnt/decouverte/tp.txt
touch /mnt/decouverte/depuis_srv1.txt      # doit réussir avec wahid
sudo umount /mnt/decouverte                # l'énoncé demande de démonter
```

## C.8 Dépannage Samba

| Symptôme | Cause | Correctif |
|---|---|---|
| `NT_STATUS_ACCESS_DENIED` au montage | mot de passe Samba absent | `smbpasswd -a utilisateur` |
| Partage visible mais écriture refusée | droits POSIX du dossier | `chown root:controle /decouverte && chmod 2775` |
| `NT_STATUS_HOST_UNREACHABLE` depuis Windows | pare-feu / SELinux | `firewall-cmd --add-service=samba`, `getsebool samba_export_all_rw` |
| Les utilisateurs voient tout en lecture seule | groupe secondaire non pris | `id hiba`, `groups wahid`, reconnexion SMB |
| `testparm` signale `write list` ignoré | `read only = yes` + `valid users` | c'est normal, `write list` gagne |

---

# PARTIE D — Bonus TP4-2 §IV : DNS secondaire (SRV2)

Rapporte des points et rend le « transfert de zone » du TP4-1 réellement observable.

```bash
sudo yum install -y bind bind-utils
sudo cp /etc/named.conf /etc/named.conf.orig

sudo tee /etc/named.conf >/dev/null <<'EOF'
options {
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    directory "/var/named";
    allow-query { any; };
    recursion no;                 /* un esclave ne fait pas de récursion */
    dnssec-validation no;
};

zone "ofppt.local" IN {
    type slave;
    masters { 192.168.137.10; };
    file "slaves/ofppt.local.dir";
};

zone "ntic.local" IN {
    type slave;
    masters { 192.168.137.10; };
    file "slaves/ntic.local.dir";
};

zone "137.168.192.in-addr.arpa" IN {
    type slave;
    masters { 192.168.137.10; };
    file "slaves/192.168.137.rev";
};
EOF

sudo restorecon -Rv /var/named
sudo chown named:named /var/named/slaves
sudo named-checkconf
sudo systemctl enable --now named
sudo firewall-cmd --permanent --add-service=dns && sudo firewall-cmd --reload

# Vérifier le transfert
ls -l /var/named/slaves/            # les fichiers doivent apparaître
sudo tail -20 /var/log/messages     # « transfer of 'ofppt.local/IN' ... succeeded »
dig @192.168.137.20 www.tri.local +short
```

**À mettre dans le rapport** (TP4-2 §IV.3-5) : la directive `allow-transfer` côté maître
(doc 01 §3), la directive `masters` côté esclave, et la trace de transfert dans les logs des
deux machines.

---

## Ce qui doit figurer dans les rapports

**`TP5.doc`** : les zones `ntic.local`/`tri.local` (récupérées du doc 01), `vhosts.conf`,
les deux `index.html`, la capture `apachectl configtest`, les deux pages vues depuis PC01,
la redirection http→https, le certificat, et `ScTP5.txt` en pièce jointe.

**`TP6.doc`** : `vsftpd.conf`, les preuves du refus de `root` et de `ftpaccess`, les tests
`tri`/`ntic` en ligne de commande et FileZilla, le chroot démontré, et `ScTP6.txt`.

**`TP9.doc`** : `smb.conf`, la sortie de `testparm`, la sortie de `pdbedit -L`, le tableau des
droits (recherche = ro, controle = rw), les captures Windows pour `hiba` et `wahid`, le test
`smbclient` local et le montage CIFS/démontage.

**Partout** : le tableau de correspondance d'adressage, les écarts assumés (rsa 2048, chemins
de logs, groupe de Hamid), et la sortie réelle des commandes — pas de « ça fonctionne ».
