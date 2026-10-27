# 09 — Playbook relais : étape par étape, qui tient le bâton

**Mode d'emploi.** On avance **dans l'ordre des numéros**, un seul bâton à la fois. Quand tu
as fini ton étape, tu envoies le **message type** indiqué, et **le suivant ne commence pas
avant**. Si une étape dépasse 20 minutes, applique la règle de déblocage (§ final) au lieu de
laisser le groupe attendre.

Légende : 🅰 Linux A (SRV1) · 🅱 Linux B (SRV2) · 🆆 Windows (PC01) · 🟢 signal de passage
✅ fait · 🟡 fait en partie · ⏳ en attente · ⏸ sans objet

---

## État au 27/10 — 🅰 a fini sa part

| Bloc | État | Preuve |
|---|---|---|
| RELAIS 0 — réseau du labo | ✅ | hotspot `MID-SAMA 6482`, passerelle `192.168.137.1` joignable en ARP |
| RELAIS 1 — socle de 🅰 (5 à 8) | ✅ | `srv1.ofppt.local`, `192.168.137.10/24` sur `wlp2s0`, route par défaut |
| RELAIS 1 — socle de 🅱 (9 à 10) | 🟡 | *déclaré* dans l'issue #1 (17/10, auteur `precieuxboko-create`) : `nmcli up` OK, `curl deb.debian.org` → `HTTP/2 200`. **Non prouvé** : `hostname -f`, `ip -4 a`, `ip r` non fournis ; et `192.168.137.20` ne répond ni en ARP ni en TCP depuis SRV1 |
| RELAIS 2 — DNS de 🅰 (12 à 21) | ✅ | `PHASE 2 VALIDÉE — 29 contrôles OK` |
| RELAIS 2 — bascule du résolveur (24) | ✅ | `resolv.conf` → `127.0.0.1`, `getent hosts www.ntic.local` répond |
| RELAIS 2 — test depuis 🅱 et 🆆 (23) | 🟡 | fait depuis SRV1 sur sa propre IP uniquement |
| PARE-FEU (22) | ⚠️ | `sudo ufw status` doit contenir la règle 53 — à vérifier |
| RELAIS 3 à 6 | ⏳ | dépend de 🅱 |

**Prochaine action : aucune côté 🅰.** Le bâton est à 🅱 (étapes 9, 19, 20, 25 bis).
🅰 reprend la main à l'étape 50 (création de `khadija` avec l'UID fourni par 🅱).

> ⚠️ **Deux pièges mesurés sur ce réseau, à ne pas confondre avec des pannes :**
> `ping 192.168.137.1` et `ping 8.8.8.8` échouent tous les deux alors que tout fonctionne
> (le hotspot Windows filtre l'ICMP). Le test valable est **TCP** :
> `curl -sI --max-time 8 https://deb.debian.org` → `HTTP/2 200`.

### Journal des retours

| Quand | Qui | Quoi | Verdict |
|---|---|---|---|
| 17/10 | 🅱 (`precieuxboko-create`) | issue #1 « premier code » : étape 9, `nmcli up` + `curl deb.debian.org` → `HTTP/2 200` | 🟡 socle déclaré OK, **preuves incomplètes** (pas de `hostname -f`, `ip -4 a`, `ip r`, ni script) |
| 17/25 | 🅰 | contrôle croisé depuis SRV1 : `192.168.137.20` → pas d'entrée ARP, ICMP muet, TCP 22/80/443/445/2049 fermés | ⛔ 🅱 n'est pas (ou plus) sur le réseau au moment du contrôle |

**Ce qui manque pour valider l'étape 9 de 🅱** — 3 commandes, à faire quand il est reconnecté :

```bash
hostname -f                       # srv2.ofppt.local
ip -4 a | grep 192.168.137.20     # 192.168.137.20/24 présent
ip r | grep default               # default via 192.168.137.1
```

> 🔎 **Point de vigilance** : il a utilisé `"$CON"` (le **nom** du profil) et non l'**UUID**.
> C'est exactement le piège qui a fait dériver 🅰 (`VERECHAGUINE SIEGE 2` → `MID-SAMA 6482`).
> S'il s'est reconnecté ailleurs depuis, son IP `.20` est peut-être posée sur le mauvais
> profil. À vérifier avec `nmcli -f NAME,UUID connection show | grep -i -B1 -A0 ""` puis
> `nmcli -g GENERAL.CONNECTION,IP4.ADDRESS device show <interface>`.

---

## RELAIS 0 — Le réseau existe (🆆, 10 min)

**1. 🆆 Active le partage de connexion**
Paramètres → Réseau → Partage de connexion. Note le **SSID** et le **mot de passe**.
`ipconfig` → la carte doit afficher **192.168.137.1**.

**2. 🆆 Coupe la mise en veille**
Paramètres → Système → Alimentation → « Jamais » (écran et veille).
*Sans ça, le hotspot tombe en pleine manip et les deux Linux perdent le réseau.*

**3. 🆆 Envoie le message de démarrage**
> 🟢 **RÉSEAU PRÊT**
> SSID : `……` · mot de passe : `……`
> Je suis en 192.168.137.1, veille coupée. Connectez-vous au Wi-Fi, ne configurez rien d'autre.

**4. 🅰 et 🅱 se connectent au Wi-Fi** (interface graphique ou `nmcli device wifi connect "SSID" password "…"`).
Ne rien configurer. On vérifie juste que chacun a une IP en `192.168.137.x` : `ip -4 a`.

🟢 **Fin du relais 0** : les 3 machines sont sur le même réseau. Le bâton passe à 🅰 et 🅱 **en même temps** (seule étape à deux porteurs).

---

## RELAIS 1 — IP fixes (🅰 puis 🅱, 20 min)

**5. 🅰 Nom de machine** ✅ *fait le 27/10*
```bash
sudo hostnamectl set-hostname srv1.ofppt.local
```

**6. 🅰 IP fixe** ✅ *fait le 27/10*

> ⛔ **Avant cette étape, vérifie que tu es bien sur le hotspot.** Si le Wi-Fi change de
> réseau entre deux commandes, tu configures le mauvais profil et tu perds Internet.
> ```bash
> nmcli -g GENERAL.CONNECTION device show wlp2s0   # nom du profil réellement actif
> nmcli -g IP4.ADDRESS device show wlp2s0          # en DHCP : doit être en 192.168.137.x
> curl -sI --max-time 8 https://deb.debian.org  # l'Internet doit répondre
> ```
> Si `IP4.ADDRESS` n'est pas en `192.168.137.x`, tu n'es pas sur le hotspot : ne configure
> rien, connecte-toi d'abord (`sudo nmcli device wifi connect "SSID" password "…"`).
> ⚠️ Les deux `ping` (passerelle **et** 8.8.8.8) échouent sur ce réseau même quand tout va
> bien : le hotspot Windows filtre l'ICMP. Seul un test **TCP** est fiable.

```bash
# on cible l'UUID : il ne change pas si le nom du profil change
UUID="$(nmcli -g UUID,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
CON="$UUID"          # réutilisé à l'étape 24
nmcli -f NAME,UUID connection show "$UUID"

sudo nmcli connection modify "$UUID" ipv4.method manual ipv4.addresses 192.168.137.10/24 \
     ipv4.gateway 192.168.137.1 ipv4.dns 192.168.137.1 ipv4.dns-search ofppt.local
sudo nmcli connection up "$UUID"
```
⚠️ `ipv4.dns 192.168.137.1` **pour l'instant**. On passera à `127.0.0.1` à l'étape 24.

**6 bis. Si tu as configuré le mauvais profil** (le nom change entre deux commandes, ta
machine a « roamé » vers un autre réseau) :

```bash
# remettre en DHCP tous les profils touchés par erreur
for p in "NOM_PROFIL_1" "NOM_PROFIL_2"; do
  sudo nmcli connection modify "$p" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
done
sudo nmcli connection up "$(nmcli -g NAME,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
curl -sI --max-time 8 https://deb.debian.org | head -1   # Internet doit revenir
```

Et pour éviter que ça recommence pendant le TP :
```bash
nmcli connection modify "AUTRE_RESEAU_CHEZ_TOI" connection.autoconnect no
```


**7. 🅰 `/etc/hosts`** ✅ *fait le 27/10*
```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
EOF
```

**8. 🅰 Contrôle** ✅ *fait le 27/10*
```bash
hostname -f        # srv1.ofppt.local
ip -4 a | grep 192.168.137.10
ip r | grep default
ping -c2 192.168.137.1          # souvent muet : pare-feu Windows, voir ci-dessous
curl -sI --max-time 8 https://deb.debian.org | head -1   # ⬅️ C'EST CE TEST QUI DÉCIDE
```

> ⚠️ **Deux pièges sur ce réseau de TP, vérifiés en vrai :**
>
> 1. `ping 192.168.137.1` **échoue toujours** : le pare-feu Windows bloque les échos ICMP
>    sur la carte du partage de connexion (profil « Public »). La machine route sans répondre.
>    Vérifie qu'elle existe quand même : `ip neigh show 192.168.137.1` doit montrer une MAC.
>
> 2. `ping 8.8.8.8` **échoue aussi** dès que WARP est coupé : le hotspot ne fait pas passer
>    l'ICMP vers l'extérieur, mais il fait très bien passer le TCP. Donc `ping` n'est pas
>    un indicateur fiable ici — et ça n'empêche **pas** `apt` de fonctionner.
>
> **Les seuls juges fiables :**
> ```bash
> curl -sI --max-time 8 https://deb.debian.org | head -1   # HTTP/2 200 → Internet OK
> dig +short @127.0.0.1 github.com                          # une IP → résolution OK
> getent hosts github.com
> ```
> - Ça répond → **passe à l'étape 9**.
> - Ça ne répond pas → là c'est réel :
>   ```bash
>   ip neigh show 192.168.137.1        # une MAC en face = la machine Windows est bien là
>   ip -4 a show wlp2s0                # es-tu sûr d'être sur 192.168.137.x ?
>   warp-cli status                    # Connected ? -> warp-cli disconnect
>   ```

**9. 🅱 Refait les étapes 5 à 8**, avec ses propres valeurs :

```bash
sudo hostnamectl set-hostname srv2.ofppt.local

UUID="$(nmcli -g UUID,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
sudo nmcli connection modify "$UUID" ipv4.method manual ipv4.addresses 192.168.137.20/24 \
     ipv4.gateway 192.168.137.1 ipv4.dns 192.168.137.1 ipv4.dns-search ofppt.local
sudo nmcli connection up "$UUID"

sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
EOF

hostname -f
ip -4 a | grep 192.168.137.20
ip r | grep default
curl -sI --max-time 8 https://deb.debian.org | head -1   # Internet (TCP : le ping ment ici)

# le contrôle automatique de la phase 1
git clone https://github.com/jinshiagencys-byte/R-SEAU-S-CURIT-.git ~/tp-reseau 2>/dev/null \
  || (cd ~/tp-reseau && git pull)
bash ~/tp-reseau/TP-corriges/scripts/00-verif-reseau.sh 192.168.137.20
```

> ⚠️ **`ipv4.dns 192.168.137.1` à ce stade, comme 🅰.** Ne mets **pas** encore
> `192.168.137.10` : le Bind de 🅰 ne tourne pas encore, et chaque résolution attendrait
> 5 secondes avant de basculer sur la passerelle (et `apt` ramperait). La bascule se fait à
> l'**étape 25 bis**, quand 🅰 annonce `🟢 DNS OK`.

**10. 🅰 et 🅱 : ping croisé** ⏳ *en attente de 🅱*
```bash
# 🅰
ping -c2 192.168.137.20
# 🅱
ping -c2 192.168.137.10
```
Si ça échoue alors qu'Internet fonctionne sur les deux : isolation client du hotspot, ou
`ufw`. Tester avec `sudo ufw disable` **temporairement** pour confirmer, puis le remettre.

**11. 🅰 envoie** ⏸ *pas nécessaire : 🅰 et 🅱 travaillent déjà ensemble, aucun message à envoyer*
> 🟢 **PHASE 1 OK**
> SRV1 = 192.168.137.10, SRV2 = 192.168.137.20, ping croisé OK, Internet OK.
> 🅱 : tu peux lancer ta préparation pendant que je fais le DNS.

🟢 **Fin du relais 1.** Le bâton passe à 🅰.

---

## RELAIS 2 — DNS (🅰, 60 min) ← **le seul vrai point de blocage**

> 🅱 pendant ce temps : étapes 19-20 (installer les paquets). Ça ne casse pas le relais.
> 🆆 pendant ce temps : RELAIS 6 partie A (installer VirtualBox + ISO). Indépendant.

> ⚠️ **Avant de commencer : coupe les VPN** (`CloudflareWARP`, ProtonVPN, NordVPN…).
> WARP capture le trafic UDP/TCP 53 et le redirige vers 1.1.1.1 : `dig @192.168.137.10`
> renverra alors des réponses de Cloudflare et tu croiras que Bind est cassé.
> ```bash
> warp-cli status            # Connected ? -> warp-cli disconnect
> warp-cli disconnect
> ```

**12. 🅰 Installe bind9 — AVANT de toucher au résolveur** ✅ *fait le 27/10*
```bash
sudo apt update
sudo apt install -y bind9 bind9utils bind9-dnsutils
systemctl status bind9 --no-pager | head -3
```
*Si tu coupes `systemd-resolved` avant cette étape, tu perds Internet et `apt` échoue. C'est
pour ça que l'étape 24 vient à la fin.*

**13. 🅰 `named.conf.options`** ✅ *fait le 27/10*
```bash
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.orig
```
Contenu à coller → **doc 07 §3.2**. Points non négociables : `listen-on { any; }`,
`allow-query { any; }`, `forwarders { 192.168.137.1; }`, `dnssec-validation no;`.

**14. 🅰 `named.conf.local`** ✅ *fait le 27/10* — les 4 zones déclarées (`ofppt.local`, `ntic.local`,
`tri.local`, `137.168.192.in-addr.arpa`). Contenu → **doc 07 §3.3**.

**15. 🅰 Crée le dossier des zones** ✅ *fait le 27/10*
```bash
sudo mkdir -p /etc/bind/zones
```

**16. 🅰 Crée les 4 fichiers de zone** ✅ *fait le 27/10* → **doc 07 §3.4** :
`ofppt.local.dir`, `ntic.local.dir`, `tri.local.dir`, `192.168.137.rev`.

**17. 🅰 Droits — le piège n°1** ✅ *fait le 27/10*
```bash
sudo chown -R root:bind /etc/bind/zones
sudo chmod 640 /etc/bind/zones/*
ls -l /etc/bind/zones/     # doit afficher root bind
```

**18. 🅰 Contrôle et démarrage** ✅ *fait le 27/10*
```bash
sudo named-checkconf
sudo named-checkzone ofppt.local /etc/bind/zones/ofppt.local.dir
sudo named-checkzone ntic.local  /etc/bind/zones/ntic.local.dir
sudo named-checkzone tri.local   /etc/bind/zones/tri.local.dir
sudo systemctl enable --now bind9
sudo ss -lntup | grep :53
dig @127.0.0.1 srv1.ofppt.local +short      # 192.168.137.10
dig @127.0.0.1 www.ntic.local +short        # 192.168.137.20
```

**19. 🅱 Installe ses paquets** (pendant que 🅰 fait le DNS)
```bash
sudo apt update
sudo apt install -y apache2 vsftpd samba samba-client cifs-utils \
                    nfs-kernel-server nfs-common dnsutils curl net-tools git
sudo mkdir -p /var/www/html/{tri,ntic} /var/log/apache2/{tri,ntic} /etc/apache2/ssl
sudo a2enmod ssl && sudo a2dissite 000-default
```

**20. 🅱 Crée ses comptes** (aucun DNS nécessaire)
```bash
sudo groupadd recherche ; sudo groupadd controle
sudo useradd -m -G recherche hiba ; sudo useradd -m -G controle wahid ; sudo useradd -m -G controle hamid
echo 'hiba:Ofppt2026!'  | sudo chpasswd
echo 'wahid:Ofppt2026!' | sudo chpasswd
echo 'hamid:Ofppt2026!' | sudo chpasswd
sudo smbpasswd -a hiba ; sudo smbpasswd -a wahid ; sudo smbpasswd -a hamid
sudo mkdir -p /decouverte /home/{projet,data,tri,ntic}
```

**21. 🅰 Contrôle automatique (29 enregistrements)** ✅ *fait le 27/10*
```bash
git clone https://github.com/jinshiagencys-byte/R-SEAU-S-CURIT-.git ~/tp-reseau 2>/dev/null || (cd ~/tp-reseau && git pull)
bash ~/tp-reseau/TP-corriges/scripts/01-verif-dns.sh 192.168.137.10
```
Objectif : **`PHASE 2 VALIDÉE — 29 contrôles OK`**.

**22. 🅰 Ouvre le pare-feu DNS** ⚠️ *à vérifier* — `sudo ufw status | grep 53`
```bash
sudo ufw allow 53
```

**23. 🅰 Test depuis l'extérieur — LE test qui compte** 🟡 *fait depuis SRV1 sur sa propre IP ; reste à refaire depuis 🅱 et 🆆*
```bash
# 🅱
dig @192.168.137.10 www.ntic.local +short      # → 192.168.137.20
```
```powershell
# 🆆
nslookup www.tri.local 192.168.137.10
```

**24. 🅰 Bascule le résolveur système** (seulement maintenant) ✅ *fait le 27/10*
```bash
sudo systemctl disable --now systemd-resolved && sudo systemctl mask systemd-resolved
sudo mkdir -p /etc/NetworkManager/conf.d
printf '[main]\ndns=none\n' | sudo tee /etc/NetworkManager/conf.d/99-no-dns.conf
sudo systemctl restart NetworkManager && sudo nmcli connection up "$CON"
sudo rm -f /etc/resolv.conf
printf 'nameserver 127.0.0.1\nsearch ofppt.local\n' | sudo tee /etc/resolv.conf
getent hosts www.ntic.local          # doit répondre SANS @
```

**25. 🅰 envoie** ⏸ *pas nécessaire : 🅱 lit l'état dans ce document*
> 🟢 **DNS OK**
> `dig @192.168.137.10 www.ntic.local` → 192.168.137.20, 29/29 enregistrements validés.
> 🅱 : bascule ton DNS sur le mien (25 bis), puis lance Apache.

**25 bis. 🅱 bascule sur le DNS de 🅰** — juste après le message `🟢 DNS OK`

```bash
UUID="$(nmcli -g UUID,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
sudo nmcli connection modify "$UUID" ipv4.dns "192.168.137.10,192.168.137.1"
sudo nmcli connection up "$UUID"

cat /etc/resolv.conf          # 192.168.137.10 doit être le 1er nameserver
dig www.ntic.local +short     # → 192.168.137.20   (sans @ : c'est le vrai test)
dig www.tri.local +short      # → 192.168.137.20
```

> 🅱 **garde** `systemd-resolved` : en tant que client, il lit les DNS fournis par
> NetworkManager, c'est exactement ce qu'on veut. Seul 🅰 le neutralise, parce que c'est lui
> qui héberge le serveur. Si 🅱 le coupe aussi, il se retrouve sans résolveur.

🟢 **Fin du relais 2.** Le bâton passe à 🅱.

---

## RELAIS 3 — Web et FTP (🅱, 90 min)

**26. 🅱 Les 2 vhosts** → **doc 07 §5.2**
```bash
# /etc/apache2/sites-available/tri.conf  et  ntic.conf
sudo a2ensite tri.conf ntic.conf
```

**27. 🅱 Les 2 pages** → **doc 02 §A.4** (`/var/www/html/tri/index.html`,
`/var/www/html/ntic/index.html`).

**28. 🅱 Certificat + SSL** → **doc 07 §5.3-5.4**
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -out /etc/apache2/ssl/server.crt -keyout /etc/apache2/ssl/server.key \
     -subj "/C=MA/ST=Oujda/L=Oujda/O=OFPPT/OU=TRI/CN=www.ntic.local"
sudo apache2ctl configtest && sudo systemctl reload apache2
```

**29. 🅱 Vérifie en local**
```bash
curl -s -H "Host: www.tri.local" http://192.168.137.20 | grep -o 'Bienvenue.*Offshore'
curl -sI http://www.ntic.local | head -3      # 301 vers https
curl -sk https://www.ntic.local | grep -o 'virtual host NTIC fonctionne'
```

**30. 🅱 envoie**
> 🟡 **WEB PRÊT** — 🆆, tu peux tester à l'étape 31.

**31. 🆆 Teste Apache** → **doc 04 §F.2** : `http://www.tri.local`,
`http://www.ntic.local` (redirection https), captures.

**32. 🆆 envoie**
> 🟡 **WEB VALIDÉ** (3 captures dans le dossier TP5) — 🅱, tu peux passer au FTP.

**33. 🅱 FTP : lance `script` AVANT tout**
```bash
cd ~ && script ScTP6.txt
```

**34. 🅱 vsftpd** → **doc 07 §6** (config `/etc/vsftpd.conf` + `/etc/ftpusers`)

**35. 🅱 Comptes FTP**
```bash
sudo useradd -m -s /bin/bash ftpaccess && echo 'ftpaccess:eff2017v31' | sudo chpasswd
sudo useradd -m -s /bin/bash tri && echo 'tri:ofppt'  | sudo chpasswd
sudo useradd -m -s /bin/bash ntic && echo 'ntic:ofppt' | sudo chpasswd
echo 'ftpaccess' | sudo tee -a /etc/ftpusers
sudo systemctl enable --now vsftpd
sudo ufw allow 21/tcp && sudo ufw allow 30000:30100/tcp
```

**36. 🅱 Teste en local, puis ferme le journal**
```bash
ftp 127.0.0.1    # ftpaccess OK, root refusé
exit             # ⚠ écrit ScTP6.txt — ne pas oublier
wc -l ScTP6.txt  # doit être > 0
```

**37. 🅱 envoie**
> 🟡 **FTP PRÊT** — 🆆, tests FileZilla.

**38. 🆆 Teste FTP** → **doc 04 §F.3** : root refusé (530), ftpaccess refusé (530),
tri OK + upload/download + chroot dans FileZilla.

**39. 🆆 envoie**
> 🟡 **FTP VALIDÉ** — 🅱, tu peux lancer Samba.

🟢 **Fin du relais 3.** Le bâton reste à 🅱 (Samba).

---

## RELAIS 4 — Samba (🅱 + 🆆, 45 min)

**40. 🅱 Partage `/decouverte`**
```bash
echo "TP Samba"      | sudo tee /decouverte/tp.txt
echo "Cours réseau"  | sudo tee /decouverte/cour.txt
sudo chown root:controle /decouverte && sudo chmod 2775 /decouverte
```

**41. 🅱 `smb.conf`** → **doc 02 §C.3** (`workgroup = SAMBA`, `security = user`,
`write list = @controle`, `guest ok = no`, `browseable = yes`).
```bash
sudo testparm -s
```

**42. 🅱 AppArmor — le piège Ubuntu**
```bash
sudo tee -a /etc/apparmor.d/local/usr.sbin.smbd >/dev/null <<'EOF'

/decouverte/ rwk,
/decouverte/** rwk,
EOF
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.smbd
sudo systemctl enable --now smbd nmbd && sudo systemctl restart smbd
sudo ufw allow Samba
```

**43. 🅱 Teste en local**
```bash
smbclient -L localhost -U hiba
smbclient //localhost/decouverte -U wahid    # mkdir → OK
smbclient //localhost/decouverte -U hiba     # mkdir → ACCESS_DENIED
```

**44. 🅱 envoie**
> 🟡 **SAMBA PRÊT** — 🆆, trois tests : wahid rw, hiba ro, anonyme refusé.

**45. 🆆 Teste Samba** → **doc 04 §F.5** + capture du lecteur réseau `Z:`.

**46. 🆆 envoie**
> 🟡 **SAMBA VALIDÉ** — 🅰, prépare `khadija` (UID de 🅱) pour le NFS.

🟢 **Fin du relais 4.** Le bâton passe à 🅰 (NFS).

---

## RELAIS 5 — NFS (🅱 prépare, puis 🅰 monte, 30 min)

**47. 🅱 Crée les 4 répertoires et l'utilisateur `khadija`**
```bash
sudo useradd -m khadija ; echo 'khadija:Ofppt2026!' | sudo chpasswd
sudo chown root:root /home/projet /home/data /home/ntic
sudo chown khadija:khadija /home/tri
sudo chmod 755 /home/projet /home/data /home/tri /home/ntic
id khadija       # note l'UID, ex. uid=1001
```

**48. 🅱 `/etc/exports`** → **doc 03 §2.3**, puis :
```bash
sudo exportfs -rav && sudo exportfs -v
showmount -e localhost
sudo systemctl restart nfs-kernel-server
```

**49. 🅱 envoie**
> 🟢 **NFS PRÊT (exports)** — UID de khadija = `1001`. 🅰, tu peux monter.

**50. 🅰 Crée `khadija` avec LE MÊME UID**
```bash
sudo useradd -u 1001 -m khadija
sudo mkdir -p /mnt/{projet,data,tri,ntic}
```

**51. 🅰 Monte les 4 partages**
```bash
for p in projet data tri ntic; do sudo mount -t nfs 192.168.137.20:/home/$p /mnt/$p; done
df -hT | grep nfs        # 4 lignes
```

**52. 🅰 Teste les droits**
```bash
cat /mnt/projet/README.txt           # OK
touch /mnt/projet/x.txt              # Read-only file system  ← attendu
sudo touch /mnt/data/x.txt           # OK
su - khadija -c 'echo ok > /mnt/tri/k.txt' && ls -ln /mnt/tri
sudo touch /mnt/ntic/root.txt && ls -ln /mnt/ntic   # UID 0
```

**53. 🅰 `fstab` + `mount -a`** → **doc 03 §3.7**

**54. 🅰 envoie**
> 🟢 **NFS VALIDÉ** — 4 montages, ro/rw conformes, `fstab` testé par `mount -a`.
> 🆆 : récupère mes captures pour `TP8.doc`.

🟢 **Fin du relais 5.** Le bâton passe à 🆆.

---

## RELAIS 6 — Le poste Windows termine (🆆, 2 h)

**55. 🆆 (déjà lancé en parallèle) 2 VM VirtualBox** → **doc 04 §B**.
`vboxnet0` en `172.19.20.2/24`, **DHCP VirtualBox désactivé**.

**56. 🆆 `dhcpd.conf` + `dhcpd -t` + démarrage** → **doc 04 §C**.
Capture des logs DORA (`journalctl -u dhcpd`), du fichier de baux, du `ipconfig /all`.

**57. 🆆 DHCPv6 + relais** → **doc 04 §D**.

**58. 🆆 Remplit la matrice de 16 tests** → **doc 04 §F.6**.

**59. 🆆 Rédige les 6 `.doc`** → **doc 04 §G** + **doc 05 §2** (checklist par TP).

**60. 🆆 envoie**
> 🟢 **RENDU PRÊT** — 6 `.doc` + `ScTP5.txt` + `ScTP6.txt` + captures numérotées.

**61. Tous : relecture finale** → **doc 05 §5** (10 minutes).

---

## Si tu es 🅱, tu n'as que ces blocs à exécuter

Tu peux ignorer tout le reste du document. Dans l'ordre, et **seulement** quand la condition
de la 2e colonne est remplie :

| Étape | Déclencheur | Quoi | Contenu |
|---|---|---|---|
| **9** | 🆆 a annoncé `RELAIS 0` | nom `srv2`, IP `.20`, `/etc/hosts`, `00-verif-reseau.sh` | §9 |
| **19** | juste après | `apt install` de tous les paquets | §19 |
| **20** | juste après | groupes, comptes, `smbpasswd`, arborescence | §20 |
| **25 bis** | 🅰 a annoncé `🟢 DNS OK` | bascule DNS → `192.168.137.10` | §25 bis |
| **26-29** | après 25 bis | Apache : 2 vhosts, pages, certificat | doc 07 §5 · doc 02 §A |
| **33-37** | 🆆 a annoncé `WEB VALIDÉ` | FTP : `script ScTP6.txt`, vsftpd, comptes | doc 07 §6 · doc 02 §B |
| **40-43** | 🆆 a annoncé `FTP VALIDÉ` | Samba + AppArmor | doc 07 §7 · doc 02 §C |
| **47-48** | 🆆 a annoncé `SAMBA VALIDÉ` | exports NFS + envoi de l'UID de `khadija` | doc 03 §2 |

**Ce que 🅱 n'a PAS à faire** (erreurs classiques) :

- ❌ installer `bind9` — c'est 🅰
- ❌ couper `systemd-resolved` — c'est 🅰 aussi ; 🅱 en a besoin pour résoudre
- ❌ configurer le partage de connexion — c'est 🆆
- ❌ mettre `192.168.137.10` comme DNS avant l'étape 25 bis
- ❌ toucher au profil Wi-Fi d'une autre machine

Chaque blocage se signale par une **Issue GitHub** (modèle dans `06_MESSAGES_EQUIPE.md`),
avec le rapport de `scripts/90-collecte.sh SRV2`.

---

## Tableau de bord à copier dans le groupe

```
RELAIS 0  Réseau ............ [x] 🆆
RELAIS 1  IP fixes .......... [x] 🅰  [ ] 🅱
RELAIS 2  DNS ............... [x] 🅰  ← 29/29, résolveur basculé
RELAIS 3  Web + FTP ......... [ ] 🅱  [ ] 🆆
RELAIS 4  Samba ............. [ ] 🅱  [ ] 🆆
RELAIS 5  NFS ............... [ ] 🅱  [ ] 🅰
RELAIS 6  TP3 + rapports .... [ ] 🆆
```

---

## Règle de déblocage : personne n'attend plus de 20 minutes

| Blocage | Qui débloque | Contournement |
|---|---|---|
| 🅱 ne peut pas tester par nom | 🅱 | `echo "192.168.137.20 www.tri.local www.ntic.local" \| sudo tee -a /etc/hosts` puis `curl -H "Host: www.tri.local" http://192.168.137.20`. **Refaire les captures avec le vrai DNS** après. |
| 🅰 bloqué sur bind | 🅰 | `sudo journalctl -u bind9 -n 30` ; vérifier `root:bind` sur les zones ; `named-checkconf`. Si > 40 min : 🆆 avance sur les VM, 🅱 sur Samba. |
| 🅱 bloqué sur AppArmor | 🅱 | `sudo aa-complain /usr/sbin/smbd`, refaire le test, puis `sudo aa-enforce /usr/sbin/smbd` une fois réglé. |
| 🆆 n'arrive pas à faire du DHCP depuis l'hôte | 🆆 | Documenter le test client Linux (déjà validé) + `ipconfig /all` montrant « DHCP activé : Oui ». Voir doc 04 §C.5. |
| Le hotspot décroche | 🆆 | Vérifier la veille, puis relancer le partage. Les Linux font `sudo nmcli connection up "$CON"`. |
| `ping 192.168.137.1` **ou** `ping 8.8.8.8` muets | personne | **Ce n'est pas une panne** : le hotspot Windows filtre l'ICMP. Le seul juge : `curl -sI https://deb.debian.org` → `HTTP/2 200`. Ne perds pas 30 min dessus. |
| Internet OK mais `ping` entre A et B muet | 🅰 🅱 | Isolation client du hotspot. `sudo ufw disable` 2 min pour lever le doute, puis remettre. Sinon passer par `ssh`/`curl` pour prouver la connectivité TCP. |

## Règle d'or du relais

**On ne passe jamais au relais suivant sur une promesse, seulement sur une sortie de
commande.** Chaque 🟢 doit être accompagné de la preuve (extrait de terminal ou capture).
C'est aussi ce qui remplit les rapports au fur et à mesure, sans avoir à tout refaire à la fin.
