# 00 — Plan d'ensemble, réseau et règles communes

> À lire et à faire **avant** tous les autres documents. 20 minutes.
>
> ⚠️ **Ta machine est sous Ubuntu 24.04, pas CentOS 7.** Ce document donne l'architecture et
> les règles ; pour les commandes réelles (paquets, chemins, AppArmor, systemd-resolved,
> ufw), utilise **`07_UBUNTU-24.04.md`**. Les documents 01/02/03 restent la référence pour la
> logique et pour la rédaction des rapports.

---

## 1. Contrainte matérielle

Pas de câble, pas de switch, pas de routeur. La seule connexion disponible est le **partage de
connexion du PC Windows** (point d'accès mobile Windows / ICS).

Conséquence : le réseau du labo, c'est **le hotspot Wi-Fi du PC Windows**. Il joue à la fois
le rôle de switch (tout le monde se voit) et de routeur par défaut (Internet pour `yum`).

```
                    ┌──────────────────────────────┐
                    │  PC01 — Windows              │
                    │  192.168.137.1               │
                    │  Point d'accès mobile "LAB"  │
                    │  + DHCP Windows + passerelle │
                    └───────┬──────────────┬───────┘
                            │ Wi-Fi        │ Wi-Fi
                 ┌──────────▼───┐    ┌─────▼────────┐
                 │ SRV1         │    │ SRV2         │
                 │ Linux A      │    │ Linux B      │
                 │ 192.168.137.10│   │ 192.168.137.20│
                 │ DNS maître   │    │ Apache / FTP │
                 │ (Bind)       │    │ Samba / NFS  │
                 │              │    │ DNS esclave  │
                 └──────────────┘    └──────────────┘
```

Vérification de l'adresse du hotspot : sur Windows, `ipconfig` → l'interface « Point d'accès
mobile » doit afficher **192.168.137.1**. Si c'est autre chose (10.42.0.1, 192.168.0.1...),
remplacez partout `192.168.137.` par le bon préfixe dans les documents.

---

## 2. Le seul TP qui sort du hotspot : le TP3 (DHCP)

Un serveur DHCP ne peut pas cohabiter avec le DHCP du hotspot Windows sur le même segment :
le client prendrait tantôt l'un, tantôt l'autre. Le TP3 est donc fait **hors réseau**, sur une
machine virtuelle, dans un segment isolé où notre `dhcpd` est le seul serveur DHCP.

C'est le **document 04** (PC Windows, 2 VM VirtualBox). Les autres TP (4, 5, 6, 8, 9) sont
faits **en direct sur les machines Linux**, sans VM.

C'est volontaire : pas de VM sur les PC Linux = pas de galère de pont réseau en Wi-Fi
(le bridging Wi-Fi ne marche pas de façon fiable), et vos machines restent rapides.

---

## 3. Inventaire à utiliser dans TOUS les rapports

Les énoncés utilisent un adressage différent à chaque TP (10.10.0.196/29, 172.30.3.3,
192.168.2.3, 172.19.196.250/26...). On harmonise, et **on l'écrit noir sur blanc dans
l'introduction de chaque rapport** : « les adresses des énoncés ont été transposées dans le
plan d'adressage du labo, tableau de correspondance ci-dessous ». C'est exactement ce qu'un
correcteur attend, et ça évite de tout reconfigurer 6 fois.

| Rôle dans l'énoncé | Machine réelle | Nom FQDN | IP |
|---|---|---|---|
| PC01 (client) | PC Windows | `pc01.ofppt.local` | 192.168.137.1 |
| SRV1 / centos1 / ista / srv1.ntic.local | PC Linux A | `srv1.ofppt.local` | 192.168.137.10 |
| SRV2 / centos2 / srv2.ntic.local | PC Linux B | `srv2.ofppt.local` | 192.168.137.20 |
| MX1 / mail | (enregistrement seul) | `mx1.ofppt.local` | 192.168.137.30 |
| mail.ntic.local | (enregistrement seul) | `mx1.ofppt.local` | 192.168.137.30 |
| LDAP | (enregistrement seul) | `ldap.ofppt.local` | 192.168.137.40 |
| www.tri.local / www.ntic.local | PC Linux B | `srv2.ofppt.local` | 192.168.137.20 |
| ftp.ofppt.local | PC Linux B | `srv2.ofppt.local` | 192.168.137.20 |
| Passerelle | hotspot Windows | — | 192.168.137.1 |

Zones DNS hébergées par SRV1 (toutes sur la même instance Bind) :

- `ofppt.local` — TP4, TP6
- `ntic.local` — TP4-2, TP5
- `tri.local` — TP5
- `137.168.192.in-addr.arpa` — zone inverse de 192.168.137.0/24 (TP4 §8 transposé)

---

## 4. Répartition du travail

| Qui | Machine | TPs | Document |
|---|---|---|---|
| Linux A | SRV1 | TP4 (DNS maître) + TP5 partie 1 (zones ntic/tri) + TP6 partie 1 | `01` |
| Linux B | SRV2 | TP5 (Apache + SSL), TP6 (FTP), TP9 (Samba), DNS esclave | `02` |
| Les deux | A monte / B exporte | TP8 (NFS) | `03` |
| Windows | PC01 | TP3 (DHCP, en VM) + tests clients de tout + rapports `.doc` + captures | `04` |

Puis : `05_CHECKLIST_RENDU.md` pour ne rien oublier avant de rendre.

**Ordre à respecter** (dépendances) :
1. mettre le réseau en place (§5) sur les 3 machines ;
2. **DNS d'abord** (doc 01) — sans DNS, Apache/FTP/Samba ne se testent pas par nom ;
3. Apache + FTP (doc 02), puis Samba (doc 02) ;
4. NFS (doc 03) ;
5. DHCP (doc 04) — indépendant, peut se faire en parallèle ;
6. rapports et captures au fur et à mesure, **jamais à la fin**.

---

## 5. Mise en réseau des 3 machines (à faire ensemble, une fois)

### 5.1 Windows — le hotspot

1. Paramètres → Réseau et Internet → **Partage de connexion** (ou « Point d'accès mobile »).
2. Activer. Noter le SSID et le mot de passe.
3. `ipconfig` dans un cmd → vérifier `192.168.137.1`.
4. **Ne pas** toucher au pare-feu pour l'instant ; on ouvrira les ports si un test échoue.

### 5.2 Linux A et Linux B — rejoindre le hotspot puis IP fixe

Se connecter au Wi-Fi « LAB » via l'interface graphique, puis :

```bash
# 1. Repérer le nom exact de la connexion Wi-Fi
nmcli -t -f NAME,DEVICE connection show --active

# 2. Passer en IP fixe (remplacer NOM_DU_WIFI)
#    Linux A :
sudo nmcli connection modify "NOM_DU_WIFI" \
     ipv4.method manual \
     ipv4.addresses 192.168.137.10/24 \
     ipv4.gateway 192.168.137.1 \
     ipv4.dns "127.0.0.1,192.168.137.1" \
     ipv4.dns-search "ofppt.local"

#    Linux B : mêmes paramètres avec 192.168.137.20 et 192.168.137.10 en 1er DNS

# 3. Appliquer
sudo nmcli connection up "NOM_DU_WIFI"

# 4. Vérifier
ip -4 addr show ; ip route ; cat /etc/resolv.conf
ping -c2 192.168.137.1     # passerelle Windows
ping -c2 8.8.8.8           # Internet (depuis A et B)
```

> ⚠️ Sur Linux A, mettre `127.0.0.1` en premier DNS alors que Bind n'est pas encore installé
> coupe Internet. Mettez d'abord `192.168.137.1`, puis basculez sur `127.0.0.1` à la fin du
> TP4 (le doc 01 le rappelle au bon moment).

Nom d'hôte :

```bash
# Linux A
sudo hostnamectl set-hostname srv1.ofppt.local
# Linux B
sudo hostnamectl set-hostname srv2.ofppt.local

# et dans /etc/hosts, sur chacune :
192.168.137.10   srv1.ofppt.local srv1
192.168.137.20   srv2.ofppt.local srv2
192.168.137.1    pc01.ofppt.local pc01
```

Test croisé obligatoire avant de continuer :

```bash
# depuis A
ping -c2 192.168.137.20
# depuis B
ping -c2 192.168.137.10
# depuis Windows
ping 192.168.137.10 & ping 192.168.137.20
```

Si le ping croisé A↔B échoue alors que chacun ping la passerelle : c'est l'**isolation
client** du hotspot. Désactiver l'option dans les paramètres du point d'accès, ou tester avec
le pare-feu Linux coupé temporairement (`sudo systemctl stop firewalld`) pour confirmer que
c'est bien ça.

### 5.3 Windows — IP fixe

Le PC Windows est déjà `192.168.137.1` par construction, on n'y touche pas. On vérifie
seulement que le **DNS** pointe bien sur SRV1 après le TP4 :

```powershell
# Panneau de configuration → Centre réseau → Modifier les paramètres de la carte
# → carte "Point d'accès mobile" → IPv4 → Propriétés → DNS préféré : 192.168.137.10
```

---

## 6. Règles de survie (important, ce sont vos PC personnels)

1. **CentOS 7 est en fin de vie** : les dépôts officiels sont fermés, `yum install` échoue.
   ⚠️ **Concerne uniquement les VM CentOS 7** (le TP3 du doc 04, et Linux B s'il est sous
   CentOS) — **pas** ta machine Ubuntu, où on utilise `apt`. Correctif à appliquer **une
   seule fois** dans chaque VM :

   ```bash
   sudo sed -i 's|^mirrorlist=|#mirrorlist=|g; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo
   sudo yum clean all && sudo yum makecache
   sudo yum install -y epel-release   # optionnel
   ```

2. **Ne désactivez pas SELinux globalement**, même quand le TP le demande (TP4-2 §I et TP9).
   Écrivez dans le rapport : « plutôt que `setenforce 0`, nous avons appliqué les booléens et
   les contextes adaptés au service ». C'est mieux noté et ça ne casse pas la machine.
   Les documents donnent les commandes exactes pour chaque service.
   Si vraiment un service refuse de démarrer : `sudo setenforce 0`, on note la commande dans
   le rapport, et on remet `sudo setenforce 1` à la fin.

3. **Pare-feu** : on ouvre les services avec `firewall-cmd`, on ne désactive pas `firewalld`.
   Mais si vous êtes bloqués, `sudo systemctl stop firewalld` permet d'isoler le problème
   en 5 secondes — pensez juste à le redémarrer après.

4. **Sauvegarde avant de toucher au réseau** (à faire sur A et B) :

   ```bash
   sudo mkdir -p ~/sauvegarde-tp && sudo cp -a /etc/NetworkManager/system-connections ~/sauvegarde-tp/
   sudo cp -a /etc/hosts ~/sauvegarde-tp/
   ```

   **Retour à la vie normale** (fin de TP, avant de rendre le PC à son propriétaire) :

   ```bash
   sudo nmcli connection modify "NOM_DU_WIFI" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
   sudo nmcli connection up "NOM_DU_WIFI"
   sudo hostnamectl set-hostname fedora   # ou le nom d'origine
   ```

5. **Nom de la machine** : si votre Linux n'est pas CentOS (Ubuntu, Debian, Fedora, Arch…),
   prévenez-moi avant d'exécuter : les paquets, les chemins de configuration et `nmcli`
   changent. Les documents sont écrits pour **CentOS 7**.

---

## 7. Ce qu'il faut rendre, TP par TP

| TP | Rapport | Journal `script` obligatoire ? | Fichiers de conf à joindre |
|---|---|---|---|
| TP3 | `TP3.doc` | non | `dhcpd.conf`, `dhcpd6.conf` |
| TP4 | `TP4.doc` | non | `named.conf`, 4 fichiers de zone |
| TP5 | `TP5.doc` | **oui → `ScTP5.txt`** | `named.conf`, zones, `vhosts.conf`, `ssl.conf` |
| TP6 | `TP6.doc` | **oui → `ScTP6.txt`** | `vsftpd.conf`, zones |
| TP8 | `TP8.doc` | non | `/etc/exports`, `fstab` |
| TP9 | `TP9.doc` | non | `smb.conf` |

**La commande `script` se lance AVANT la première commande du TP** :

```bash
script ScTP5.txt      # tout ce qui s'affiche ensuite est enregistré
# ... tout le TP ...
exit                  # ou Ctrl+D  → arrête l'enregistrement
```

Si vous l'oubliez, le fichier est vide et c'est une note perdue. Une seule fois par TP.

---

## 8. Bonus qui rapporte des points (à glisser dans les rapports)

- **Le tableau de correspondance d'adressage** (§3) en introduction de chaque rapport.
- **Les incohérences relevées dans les énoncés** (il y en a plusieurs, elles sont listées dans
  chaque document). Les signaler en disant comment vous avez tranché = maturité technique.
- **Les tests** : ne jamais écrire « ça marche ». Toujours la commande + sa sortie réelle.
- **La conclusion** demandée au TP3 : 3–4 lignes sur ce que le DHCP apporte réellement
  (administration centralisée, éviter les conflits d'adresses, réservation par MAC) et ses
  limites (un seul point de panne, nécessité d'un relais par sous-réseau).
