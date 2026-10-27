# 09 — Playbook relais : étape par étape, qui tient le bâton

**Mode d'emploi.** On avance **dans l'ordre des numéros**, un seul bâton à la fois. Quand tu
as fini ton étape, tu envoies le **message type** indiqué, et **le suivant ne commence pas
avant**. Si une étape dépasse 20 minutes, applique la règle de déblocage (§ final) au lieu de
laisser le groupe attendre.

Légende : 🅰 Linux A (SRV1) · 🅱 Linux B (SRV2) · 🆆 Windows (PC01) · 🟢 signal de passage

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

**5. 🅰 Nom de machine**
```bash
sudo hostnamectl set-hostname srv1.ofppt.local
```

**6. 🅰 IP fixe**
```bash
CON="$(nmcli -g NAME,TYPE connection show --active | grep ':802-11-wireless$' | cut -d: -f1)"
echo "Profil : $CON"
sudo nmcli connection modify "$CON" ipv4.method manual ipv4.addresses 192.168.137.10/24 \
     ipv4.gateway 192.168.137.1 ipv4.dns 192.168.137.1 ipv4.dns-search ofppt.local
sudo nmcli connection up "$CON"
```
⚠️ `ipv4.dns 192.168.137.1` **pour l'instant**. On passera à `127.0.0.1` à l'étape 24.

**7. 🅰 `/etc/hosts`**
```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
EOF
```

**8. 🅰 Contrôle**
```bash
hostname -f        # srv1.ofppt.local
ip -4 a | grep 192.168.137.10
ip r | grep default
ping -c2 192.168.137.1
ping -c2 8.8.8.8   # Internet : indispensable pour apt
```

**9. 🅱 Refait les étapes 5 à 8** avec `.20`, `srv2.ofppt.local`, et **le même bloc `/etc/hosts`**.

**10. 🅰 et 🅱 : ping croisé**
```bash
# 🅰
ping -c2 192.168.137.20
# 🅱
ping -c2 192.168.137.10
```
Si ça échoue alors que la passerelle répond : isolation client du hotspot, ou `ufw`. Tester
avec `sudo ufw disable` **temporairement** pour confirmer, puis le remettre.

**11. 🅰 envoie**
> 🟢 **PHASE 1 OK**
> SRV1 = 192.168.137.10, SRV2 = 192.168.137.20, ping croisé OK, Internet OK.
> 🅱 : tu peux lancer ta préparation pendant que je fais le DNS.

🟢 **Fin du relais 1.** Le bâton passe à 🅰.

---

## RELAIS 2 — DNS (🅰, 60 min) ← **le seul vrai point de blocage**

> 🅱 pendant ce temps : étapes 19-20 (installer les paquets). Ça ne casse pas le relais.
> 🆆 pendant ce temps : RELAIS 6 partie A (installer VirtualBox + ISO). Indépendant.

**12. 🅰 Installe bind9 — AVANT de toucher au résolveur**
```bash
sudo apt update
sudo apt install -y bind9 bind9utils bind9-dnsutils
systemctl status bind9 --no-pager | head -3
```
*Si tu coupes `systemd-resolved` avant cette étape, tu perds Internet et `apt` échoue. C'est
pour ça que l'étape 24 vient à la fin.*

**13. 🅰 `named.conf.options`**
```bash
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.orig
```
Contenu à coller → **doc 07 §3.2**. Points non négociables : `listen-on { any; }`,
`allow-query { any; }`, `forwarders { 192.168.137.1; }`, `dnssec-validation no;`.

**14. 🅰 `named.conf.local`** — les 4 zones déclarées (`ofppt.local`, `ntic.local`,
`tri.local`, `137.168.192.in-addr.arpa`). Contenu → **doc 07 §3.3**.

**15. 🅰 Crée le dossier des zones**
```bash
sudo mkdir -p /etc/bind/zones
```

**16. 🅰 Crée les 4 fichiers de zone** → **doc 07 §3.4** :
`ofppt.local.dir`, `ntic.local.dir`, `tri.local.dir`, `192.168.137.rev`.

**17. 🅰 Droits — le piège n°1**
```bash
sudo chown -R root:bind /etc/bind/zones
sudo chmod 640 /etc/bind/zones/*
ls -l /etc/bind/zones/     # doit afficher root bind
```

**18. 🅰 Contrôle et démarrage**
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

**21. 🅰 Contrôle automatique (26 enregistrements)**
```bash
git clone https://github.com/jinshiagencys-byte/R-SEAU-S-CURIT-.git ~/tp-reseau 2>/dev/null || (cd ~/tp-reseau && git pull)
bash ~/tp-reseau/TP-corriges/scripts/01-verif-dns.sh 192.168.137.10
```
Objectif : **`PHASE 2 VALIDÉE — 26 contrôles OK`**.

**22. 🅰 Ouvre le pare-feu DNS**
```bash
sudo ufw allow 53
```

**23. 🅰 Test depuis l'extérieur — LE test qui compte**
```bash
# 🅱
dig @192.168.137.10 www.ntic.local +short      # → 192.168.137.20
```
```powershell
# 🆆
nslookup www.tri.local 192.168.137.10
```

**24. 🅰 Bascule le résolveur système** (seulement maintenant)
```bash
sudo systemctl disable --now systemd-resolved && sudo systemctl mask systemd-resolved
sudo mkdir -p /etc/NetworkManager/conf.d
printf '[main]\ndns=none\n' | sudo tee /etc/NetworkManager/conf.d/99-no-dns.conf
sudo systemctl restart NetworkManager && sudo nmcli connection up "$CON"
sudo rm -f /etc/resolv.conf
printf 'nameserver 127.0.0.1\nsearch ofppt.local\n' | sudo tee /etc/resolv.conf
getent hosts www.ntic.local          # doit répondre SANS @
```

**25. 🅰 envoie**
> 🟢 **DNS OK**
> `dig @192.168.137.10 www.ntic.local` → 192.168.137.20, vérifié depuis SRV1, SRV2 et Windows.
> 26/26 enregistrements validés. 🅱 : tu peux lancer Apache.

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

## Tableau de bord à copier dans le groupe

```
RELAIS 0  Réseau ............ [ ] 🆆
RELAIS 1  IP fixes .......... [ ] 🅰 [ ] 🅱
RELAIS 2  DNS ............... [ ] 🅰   ← bloque tout
RELAIS 3  Web + FTP ......... [ ] 🅱 [ ] 🆆
RELAIS 4  Samba ............. [ ] 🅱 [ ] 🆆
RELAIS 5  NFS ............... [ ] 🅱 [ ] 🅰
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

## Règle d'or du relais

**On ne passe jamais au relais suivant sur une promesse, seulement sur une sortie de
commande.** Chaque 🟢 doit être accompagné de la preuve (extrait de terminal ou capture).
C'est aussi ce qui remplit les rapports au fur et à mesure, sans avoir à tout refaire à la fin.
