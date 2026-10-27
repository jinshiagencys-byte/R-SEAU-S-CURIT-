# 05 — Checklist de rendu, planning et questions théoriques

---

## 1. Planning réaliste (une journée de TP)

| Créneau | Linux A (SRV1) | Linux B (SRV2) | Windows (PC01) |
|---|---|---|---|
| 0:00–0:30 | **Tous :** réseau, IP fixes, `ping` croisés, correctif `vault.centos.org` (doc 00 §5-6) | | |
| 0:30–2:00 | **TP4** : Bind, 4 zones, tests `dig` (doc 01) | Préparation : `yum`, arborescences, pages HTML (doc 02 §0 et A.2-A.4) | **TP3** : VirtualBox, 2 VM, `dhcpd` (doc 04 §B-C) |
| 2:00–3:00 | TP5 P1 (zones ntic/tri) + TP6 P1 (déjà couvert) → tests croisés | **TP5** : vhosts + SSL, tests `curl` (doc 02 §A) | TP3 : DHCPv6 + relais + logs (doc 04 §D) |
| 3:00–4:00 | **TP8 client** : montages, `fstab` (doc 03 §3) | **TP6** : vsftpd + chroot (doc 02 §B) | Tests FTP depuis Windows (doc 04 §F.3) |
| 4:00–5:00 | Aide + captures TP8 | **TP9** : Samba (doc 02 §C) | Tests Samba + tous les `.doc` (doc 04 §F) |
| 5:00–5:30 | **Tous :** captures manquantes, `ScTP5.txt` / `ScTP6.txt`, relecture | | |

Le TP5 et le TP6 demandent chacun **un journal `script`** : c'est le seul point où une
distraction coûte une note entière. `script ScTP5.txt` → tout le TP → `exit`.

---

## 2. Checklist par TP

### TP3 — DHCP
- [ ] Nom du serveur `SRV-A`, IP `172.19.20.1/24` configurée par fichier (`ifcfg-*` ou `nmcli`)
- [ ] Paquet DHCP vérifié puis installé
- [ ] `dhcpd.conf` : bail 1 j / 3 j, plage .50-.150, exclusion .60-.70, domaine `tmsir.local`,
      DNS 192.168.1.1 et .2, WINS .201, NTP .202
- [ ] Réservation `.202` / MAC `08:00:27:00:0C:C0`
- [ ] `dhcpd -t` montré (question 7)
- [ ] Service démarré **et** activé au boot
- [ ] Test client Linux : bail + `ip a`
- [ ] Test client Windows : `ipconfig /all` avec « Bail obtenu »
- [ ] Logs DORA (`journalctl -u dhcpd`)
- [ ] `/var/lib/dhcpd/dhcpd.leases`
- [ ] DHCPv6 : `dhcpd6.conf`, `dhcpd -6 -t`, test client, arrêt du service
- [ ] Relais `dhcrelay` démontré
- [ ] Conclusion rédigée

### TP4 — DNS
- [ ] Nom d'hôte + IP fixe + `resolv.conf` (via `nmcli`)
- [ ] `bind` + `bind-utils` installés (`rpm -qa`, `rpm -ql`, port 53)
- [ ] `named.conf` avec `forwarders` (212.217.0.12 + passerelle)
- [ ] Zone `ofppt.local` : SOA, NS, A, **MX priorité 20**, AAAA, **CNAME smtp/imap**, ldap
- [ ] SOA : refresh 2H / retry 20M / expire 1W
- [ ] `allow-transfer` + `notify` (`also-notify`)
- [ ] Zone inverse + PTR de mx1
- [ ] `named-checkconf -z` + 4 × `named-checkzone` (OK)
- [ ] Tests **A, SOA, NS, MX, PTR** en `dig`, `nslookup`, `host`
- [ ] Test depuis un client Linux **et** Windows
- [ ] (Bonus) serveur secondaire + preuve du transfert dans les logs
- [ ] (Bonus) DDNS

### TP5 — Apache
- [ ] `ScTP5.txt` **existe et n'est pas vide**
- [ ] Zones `ntic.local` + `tri.local` (SOA, NS, A) + `named-checkzone`
- [ ] Résolution `www.ntic.local` / `www.tri.local` testée
- [ ] Arborescences `/var/www/html/tri|ntic` et `/var/log/httpd/tri|ntic`
- [ ] 2 vhosts sur le **même port 80 et la même IP**
- [ ] `index.html` des deux sites
- [ ] `apachectl configtest` → Syntax OK
- [ ] Test PC01 : les 2 pages
- [ ] `mod_ssl` + certificat `openssl req …`
- [ ] Redirection http → https sur `www.ntic.local`
- [ ] Test PC01 en https (capture du cadenas/avertissement)

### TP6 — FTP
- [ ] `ScTP6.txt` **existe et n'est pas vide**
- [ ] Zone `ofppt.local` + `centos1` + `ftp` résolus
- [ ] `vsftpd` installé, groupe et utilisateur `ftp` vérifiés
- [ ] Les 9 exigences (a→i) présentes dans `vsftpd.conf`, **avec le tableau de correspondance**
- [ ] Utilisateur `ftpaccess` / `eff2017v31`
- [ ] Refus de `root` démontré
- [ ] `chroot_local_user=YES` + refus de remontée démontré
- [ ] `tri` / `ntic` créés, `ftpaccess` bloqué
- [ ] Tests `ftp` + FileZilla, upload et download
- [ ] `vsftpd.conf` joint au rapport

### TP8 — NFS
- [ ] Réponse rédigée à « rôle de NFS »
- [ ] `nfs-utils` installé, `rpcbind` + `nfs-server` actifs
- [ ] 4 répertoires créés (dont `/home/tri` et `/home/ntic`, absents de l'étape 3)
- [ ] `/etc/exports` : ro pour tous, rw pour SRV1, khadija, `no_root_squash`
- [ ] `exportfs -rav` + `showmount -e`
- [ ] 4 montages côté SRV1 + `df -hT`
- [ ] Test lecture/écriture : refus sur `projet`, OK sur `data`, `tri`, `ntic`
- [ ] Propriétaires vérifiés (`ls -ln`) + explication des UID
- [ ] Test de synchronisation (temps réel, pas de délai)
- [ ] `/etc/fstab` + `_netdev` + `mount -a` + justification du fichier
- [ ] Démontage final

### TP9 — Samba
- [ ] `samba` installé, SELinux : booleans + `samba_share_t`
- [ ] Groupes `recherche` / `controle`
- [ ] Hiba, Wahid, Hamid créés (et **choix documenté** pour Hamid)
- [ ] `smbpasswd -a` pour les 3 + `pdbedit -L`
- [ ] `/decouverte` + `tp.txt` + `cour.txt`
- [ ] `smb.conf` : workgroup SAMBA, `security = user`, `browseable = yes`,
      `guest ok = no`, `write list = @controle`
- [ ] `testparm` OK
- [ ] `smbclient` local : liste + `mkdir` + accès refusé pour hiba
- [ ] Windows : `wahid` rw, `hiba` ro, anonyme refusé
- [ ] Montage CIFS + `umount`

---

## 3. Les incohérences des énoncés (à signaler, ça rapporte)

| Où | Problème | Comment on tranche |
|---|---|---|
| Tous | Adressage différent à chaque TP (172.19.20.x, 10.10.0.x, 192.168.2.x, 172.30.3.3, 172.19.196.x) | Un seul plan d'adressage + tableau de correspondance |
| TP3 §5h et §6 | Le serveur NTP et PC1 ont la même IP `.202` | PC1 **est** le serveur NTP |
| TP4-1 §1 / TP6 P1 §1 / TP5 P1 §1 | Trois noms différents pour le même serveur (`ista`, `centos1`, `srv1`) | Un `hostname`, des alias **CNAME** en DNS |
| TP4-1 §8 | Zone inverse de `10.0.0.0/8` alors que le réseau est en /29 | Transposée en `192.168.137.0/24` |
| TP4-2 §I | « Désactiver SELinux » et « arrêter le pare-feu » | On applique les contextes/booléens et on ouvre les ports — c'est la bonne pratique |
| TP5 P2 §2 | La machine est successivement `srv1` (partie 1) puis `srv2` (partie 2) | Deux machines : SRV1 = DNS, SRV2 = serveur web |
| TP5 P1 §7 | « Créer le fichier de zone `.local.dir` » | Coquille : `tri.local.dir` |
| TP5 P2 | « Chemin de journal des erreurs : `/var/log/httpd/tri` » (un répertoire) | `ErrorLog /var/log/httpd/tri/error.log` |
| TP5 P4 §2 | Clé `rsa:1024` | 2048 bits (déprécié côté navigateurs) |
| TP6 P3 §3 | Se connecter en `root` alors que P2 §5h interdit root | Le refus de root **est** le test |
| TP6 P2 §1 et §2 | `centos2.ofppt.ma` puis `centos1` comme serveur DNS de la même zone `.local` | Un seul domaine `ofppt.local`, alias CNAME |
| TP8 §3 vs §4 | 2 répertoires créés, 4 partagés | Les 4 créés |
| TP8 | Le PDF est imprimé **deux fois à l'identique** | Une seule série de réponses |
| TP9 §8 | « Hamid → groupe Hamid » | Hamid dans `controle` |
| TP9 §9 | « Pour les deux utilisateurs » alors qu'il y en a trois | Les trois |
| TP9 §15 | « montez sur tiny » + `umount` (commande Linux) | `tiny` est une machine d'un autre TP ; montage CIFS depuis SRV1 |

---

## 4. Questions théoriques à rédiger (elles tombent à l'oral)

**Rôle du DHCP** — attribuer automatiquement les paramètres IP (adresse, masque, passerelle,
DNS, domaine, WINS, NTP) ; évite les doublons et la saisie manuelle ; réservation par MAC ;
limites : point de panne unique, broadcast non routé (→ relais).

**Rôle du DNS** — traduire nom ↔ adresse ; hiérarchique et distribué ; zones directe et
inverse ; SOA/NS/A/AAAA/MX/CNAME/PTR/SRV ; primaire (maître) et secondaire (esclave) ;
transfert de zone, `notify`, `allow-transfer` ; TTL négatif.

**Rôle de NFS** — voir doc 03 §1.

**Différence NFS / Samba / FTP** —
- NFS : montage transparent, UNIX, basé sur UID/GID, pas d'authentification.
- Samba : SMB/CIFS, authentification par compte, interopérable Windows, ACL.
- FTP : transfert de fichiers explicite (deux canaux : commandes 21, données 20 ou passif),
  pas de montage.

**Différence HTTP / HTTPS** — HTTPS = HTTP dans une session TLS ; le certificat sert à
authentifier le serveur (et non à chiffrer, même si le chiffrement en découle) ; auto-signé
= pas de chaîne de confiance → avertissement navigateur.

**`root_squash` / `no_root_squash`** — le root du client est-il mappé sur `nobody` côté
serveur. `no_root_squash` est une faille en production.

**`chroot` FTP** — enfermer l'utilisateur dans son home ; `allow_writeable_chroot` nécessaire
avec vsftpd ≥ 3.0 car il refuse par défaut un home inscriptible.

**LDAP en SRV vs A** — la priorité/poids de l'énoncé (`20`, `200`) désigne un enregistrement
**SRV** (`_ldap._tcp`), pas un A : c'est le mécanisme utilisé par les clients pour découvrir
un service.

---

## 5. Avant de rendre — 10 minutes de relecture

1. `grep -ril "ça marche\|ca marche\|fonctionne bien" RENDU/` → tout reformuler avec la sortie.
2. Chaque question de l'énoncé a **son numéro** dans le `.doc` (le correcteur coche).
3. `ScTP5.txt` et `ScTP6.txt` sont joints **et** non vides (`wc -l`).
4. Les fichiers de conf sont en annexe, pas seulement évoqués.
5. Le tableau de correspondance d'adressage est en tête de chaque rapport.
6. Le tableau des incohérences (§3) est présent au moins une fois — c'est ce qui distingue
   un TP recopié d'un TP compris.
7. Les captures portent des noms explicites et sont dans l'ordre des questions.
8. Personne n'a laissé sa machine avec SELinux désactivé ou l'IP fixe du labo :
   `00_PLAN_ET_RESEAU.md` §6.4 (retour à la vie normale).
