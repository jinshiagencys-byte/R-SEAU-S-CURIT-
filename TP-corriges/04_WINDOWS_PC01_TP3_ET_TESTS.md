# 04 — PC01 (Windows) : TP3 DHCP en VM + tests clients + rapports

**Couvre :** TP3-1 (DHCP IPv4) · TP3-2 (DHCPv6 + relais) · bonus TP4-2 §V (DDNS) ·
**tous les tests clients** des TP4/5/6/8/9 · les captures et les `.doc`.

C'est le poste qui produit les preuves : sans ses captures, les autres TPs ne sont pas notés.

---

## PARTIE A — Pourquoi des VM ici et nulle part ailleurs

Le TP3 demande de **créer** un serveur DHCP. Or le partage de connexion Windows fait déjà
tourner un serveur DHCP sur le réseau du labo. Deux serveurs DHCP sur le même segment, c'est
le client qui prend la première offre arrivée : les tests deviennent aléatoires.

On isole donc le TP3 sur un **réseau virtuel** où notre `dhcpd` est le seul serveur DHCP.
C'est aussi l'occasion de montrer deux clients (Linux et Windows) sur le même segment.

**Matériel nécessaire :** ~3 Go de RAM libre et ~15 Go de disque sur le PC Windows.

> 🔌 **Le PC Windows doit d'abord être mis sur le réseau du labo** : pont logiciel entre ses
> deux cartes Ethernet, adresse `192.168.137.1`. Procédure détaillée au **§3.1 de
> `10_RESEAU_CABLE.md`**. Le TP3 ci-dessous ne dépend pas de ce réseau (VM host-only), mais
> les tests clients des TP4/5/6/8/9, si.

```
   Windows (hôte)                Réseau host-only "vboxnet0" 172.19.20.0/24
   172.19.20.x  ◄──── DHCP ────┐
   (client Windows)            │
                               ├── SRV-A (VM CentOS) 172.19.20.1  ← le serveur DHCP
   CLIENT-LINUX (VM) ◄─ DHCP ──┘
   172.19.20.5x
```

---

## PARTIE B — Mise en place du labo virtuel

### B.1 Logiciels

1. **VirtualBox** : https://www.virtualbox.org/wiki/Downloads
2. **CentOS 7 Minimal** (≈ 1 Go) :
   `https://vault.centos.org/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso`

> Prendre la version **Minimal** : elle démarre en 512 Mo de RAM et suffit pour `dhcpd`.
> Ne pas prendre la version DVD/Everything (4 Go).

### B.2 Réseau host-only

VirtualBox → **Fichier → Gestionnaire de réseaux hôtes** :

1. Onglet « Réseau host-only » → **Créer** (`vboxnet0`).
2. Cliquer sur « Modifier » :
   - IPv4 : `172.19.20.2` — masque `255.255.255.0`
   - **Serveur DHCP : onglet DHCP → décocher « Activer le serveur »** ← indispensable,
     sinon VirtualBox distribue des adresses et fausse tout le TP.
3. OK.

### B.3 Les deux VM

| | SRV-A | CLIENT-LINUX |
|---|---|---|
| RAM | 768 Mo | 512 Mo |
| Disque | 10 Go (VDI, dynamique) | 8 Go |
| Réseau | Host-only `vboxnet0` | Host-only `vboxnet0` |
| IP | 172.19.20.1/24 (fixe) | **DHCP** |
| Nom | `SRV-A` | `CLIENT` |

Installation : « Installation de CentOS 7 » → langue → **INSTALLATION DESTINATION** (cliquer
puis « Terminé » sinon l'installation refuse de démarrer) → **NETWORK & HOST NAME** →
activer la carte → **ROOT PASSWORD** (noter le mot de passe) → Terminé → Reboot.

Après le reboot, se connecter en `root`.

### B.4 Réseau du serveur SRV-A (TP3-1 §1-2-3)

```bash
# Nom du serveur
hostnamectl set-hostname SRV-A

# IP fixe (CentOS 7 minimal : NetworkManager gère la carte)
nmcli connection show
nmcli connection modify "Wired connection 1" \
      ipv4.method manual ipv4.addresses 172.19.20.1/24 \
      ipv4.gateway "" ipv4.dns ""
nmcli connection up "Wired connection 1"

# Vérification
ip -4 addr show
ping -c2 172.19.20.2          # la passerelle host-only (le PC Windows)

# Dépôt : CentOS 7 est en fin de vie, corriger avant tout yum
sed -i 's|^mirrorlist=|#mirrorlist=|g; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo
yum clean all && yum makecache
```

> `ipv4.gateway ""` : le serveur DHCP n'a pas besoin de passerelle sur ce segment isolé. Si
> votre version de `nmcli` refuse la syntaxe, utilisez
> `nmcli con mod "Wired connection 1" ipv4.gateway ""` ou ignorez cette ligne.

**Q. TP3-1 §3 « Démarrer le serveur réseau »** → `systemctl restart network` (CentOS 7) ou
`systemctl restart NetworkManager`.

### B.5 Paquet DHCP (TP3-1 §4)

```bash
rpm -qa | grep dhcp
yum install -y dhcp
rpm -ql dhcp | grep dhcpd.conf      # /etc/dhcp/dhcpd.conf existe maintenant
```

---

## PARTIE C — TP3-1 : DHCP IPv4

### C.1 `/etc/dhcp/dhcpd.conf` (TP3-1 §5 et §6)

```bash
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig
cat > /etc/dhcp/dhcpd.conf <<'EOF'
# ---------- Paramètres globaux ----------
option domain-name "tmsir.local";                    # (e)
option domain-name-servers 192.168.1.1, 192.168.1.2; # (f)
option netbios-name-servers 172.19.20.201;           # (g) serveur WINS
option ntp-servers 172.19.20.202;                    # (h) serveur NTP

default-lease-time 86400;      # (a) 1 jour
max-lease-time     259200;     # (b) 3 jours

authoritative;                 # ce serveur est la référence sur ce réseau

# ---------- Plage d'adresses ----------
subnet 172.19.20.0 netmask 255.255.255.0 {
    range 172.19.20.50  172.19.20.59;    # (c) la plage demandée est .50 -.150
    range 172.19.20.71  172.19.20.150;   # (d) en excluant .60 -.70
    option routers 172.19.20.1;
}

# ---------- Réservation (TP3-1 §6) ----------
host pc1 {
    hardware ethernet 08:00:27:00:0C:C0;
    fixed-address 172.19.20.202;
}
EOF
```

**Comment on exclut `.60` → `.70`** : `dhcpd` n'a pas de directive « plage exclue ». La
méthode propre est **deux `range`** qui encadrent le trou (c'est ce qui est fait ci-dessus).
L'autre méthode (classe + `deny members of`) est plus lourde pour rien. À expliquer dans le
rapport — c'est une question classique.

> **Incohérence à signaler** : le §5h déclare un serveur NTP en `172.19.20.202` et le §6
> réserve **la même adresse** `172.19.20.202` à PC1. Les deux sont conservés tels quels :
> l'interprétation cohérente est que **PC1 est le serveur NTP** du réseau. Le dire dans le
> rapport.

### C.2 Vérifier les erreurs de configuration (TP3-1 §7)

C'est la question la plus piégeuse : la commande attendue n'est pas `systemctl status`.

```bash
dhcpd -t -cf /etc/dhcp/dhcpd.conf
# variante : dhcpd -t
```

Sortie attendue : rien (code retour 0) si tout va bien. Une erreur typique :

```
/etc/dhcp/dhcpd.conf line 18: semicolon expected.
```

→ point-virgule ou accolade manquante. À noter aussi : `dhcpd -t` **ne teste pas** que
l'interface a une IP dans le sous-réseau déclaré, d'où le test suivant.

### C.3 Démarrage (TP3-1 §8)

```bash
# Indiquer l'interface d'écoute (sinon dhcpd peut choisir la mauvaise)
grep -q '^DHCPDARGS' /etc/sysconfig/dhcpd || echo 'DHCPDARGS=eth0' >> /etc/sysconfig/dhcpd

systemctl enable --now dhcpd
systemctl status dhcpd --no-pager

# Écoute (le serveur DHCP écoute en UDP 67)
ss -lunp | grep :67
```

Si le service refuse de démarrer alors que `dhcpd -t` est OK : `journalctl -xe -u dhcpd`
→ souvent « No subnet declaration for eth0 » (IP pas dans le sous-réseau, ou mauvaise
interface dans `DHCPDARGS`).

### C.4 Test client Linux (TP3-1 §9)

Sur **CLIENT-LINUX** (réglé en DHCP) :

```bash
ip -4 addr show                     # doit déjà avoir une adresse 172.19.20.5x
# sinon :
dhclient -r eth0 && dhclient -v eth0

ip -4 addr show eth0
ip route
cat /etc/resolv.conf                # doit contenir 192.168.1.1 et 192.168.1.2
```

Attendu : une adresse entre `.50` et `.59` ou `.71` et `.150`, **jamais** entre `.60` et
`.70` (c'est la preuve de l'exclusion). À force de renouveler, on peut montrer plusieurs
adresses de la plage :

```bash
for i in 1 2 3 4; do dhclient -r eth0 >/dev/null; dhclient eth0; ip -4 -br addr show eth0; done
```

### C.5 Test client Windows (TP3-1 §9)

Sur le PC Windows, carte « VirtualBox Host-Only Ethernet Adapter » :

```powershell
# 1. Carte en DHCP
#    Paramètres réseau → Modifier les options de l'adaptateur → carte host-only
#    → IPv4 → Propriétés → "Obtenir une adresse IP automatiquement"

# 2. Libérer / renouveler
ipconfig /release "VirtualBox Host-Only Ethernet Adapter"
ipconfig /renew   "VirtualBox Host-Only Ethernet Adapter"
ipconfig /all
```

Attendu dans `ipconfig /all` :

```
DHCP activé . . . . . . . . . . . : Oui
Bail obtenu . . . . . . . . . . . : <date>
Bail expirant . . . . . . . . . . : <date + 1 jour>
Serveur DHCP  . . . . . . . . . . : 172.19.20.1
Serveurs DNS  . . . . . . . . . . : 192.168.1.1
                                    192.168.1.2
Serveurs WINS . . . . . . . . . . : 172.19.20.201
```

> ⚠️ **Bug connu de VirtualBox** : la carte host-only est parfois forcée en IP statique
> (`172.19.20.2`) par le pilote VirtualBox et refuse le DHCP. Si `ipconfig /all` affiche
> cette IP fixe au lieu d'un bail :
> 1. arrêter la VM SRV-A ;
> 2. VirtualBox → Gestionnaire de réseaux hôtes → `vboxnet0` → IPv4 = `172.19.20.254` ;
> 3. redémarrer SRV-A, puis relancer `ipconfig /renew`.
>
> Si ça bloque encore, la démonstration Windows peut se faire avec le **client Linux déjà
> validé** + une capture de `ipconfig /all` montrant « DHCP activé : Oui » et le serveur
> `172.19.20.1` : le mécanisme de bail est le même, c'est le protocole qui est testé.

### C.6 Logs DHCP (TP3-1 §9-10)

```bash
# Journal en direct
journalctl -u dhcpd -f
# ou
tail -f /var/log/messages | grep dhcpd

# Fichier des baux
cat /var/lib/dhcpd/dhcpd.leases

# Baux actifs, mise en forme
dhcp-lease-list 2>/dev/null || grep -A6 '^lease' /var/lib/dhcpd/dhcpd.leases
```

Ce qu'on doit lire dans le journal :

```
DHCPDISCOVER from 08:00:27:xx:xx:xx via eth0
DHCPOFFER on 172.19.20.51 to 08:00:27:xx:xx:xx via eth0
DHCPREQUEST for 172.19.20.51 from 08:00:27:xx:xx:xx via eth0
DHCPACK on 172.19.20.51 to 08:00:27:xx:xx:xx via eth0
```

C'est le **DORA** (Discover → Offer → Request → Ack) : à commenter dans le rapport, c'est
exactement ce que le prof veut voir compris.

### C.7 Preuve de la réservation

Sur CLIENT-LINUX, on force la MAC de la réservation :

```bash
# Arrêter l'interface, changer la MAC, relancer le bail
nmcli connection modify "Wired connection 1" 802-3-ethernet.mac-address 08:00:27:00:0C:C0
nmcli connection up "Wired connection 1"
dhclient -r eth0 && dhclient -v eth0
ip -4 addr show eth0        # → 172.19.20.202
```

(l'énoncé attribue cette MAC à PC1 ; on la force ici pour prouver la réservation, puis on
remet la MAC d'origine avec `nmcli ... mac-address ""`.)

### C.8 Conclusion du TP3-1 (§11)

À rédiger, pas à copier :

> Le DHCP centralise l'attribution des adresses : plus d'IP en double, plus de saisie
> manuelle sur chaque poste, et les paramètres (passerelle, DNS, WINS, NTP, domaine)
> suivent automatiquement. La réservation par adresse MAC permet de garder une IP stable
> pour un serveur ou une imprimante sans la configurer à la main. Les limites : le serveur
> DHCP est un point de panne unique (sans lui, les postes tombent en APIPA 169.254.x.x) et
> le broadcast DHCP ne traverse pas un routeur — d'où le relais DHCP.

---

## PARTIE D — TP3-2 : DHCPv6

### D.1 IPv6 sur le serveur

```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=0
nmcli connection modify "Wired connection 1" ipv6.method manual \
      ipv6.addresses 2001:db8:2:1::8/64 ipv6.gateway 2001:db8:2:1::2
nmcli connection up "Wired connection 1"
ip -6 addr show eth0            # → 2001:db8:2:1::8/64
```

**Q. §2 « commande pour redémarrer le service réseau »** → `systemctl restart NetworkManager`
(ou `systemctl restart network`). **§3** → `ip -6 addr show`.

### D.2 `/etc/dhcp/dhcpd6.conf` (TP3-2 §4-5)

```bash
cat > /etc/dhcp/dhcpd6.conf <<'EOF'
default-lease-time 86400;                         # (a) 1 jour

option dhcp6.domain-search "ntic.local";          # (d)
option dhcp6.name-servers 2001:db8:2:1::3;        # (e)

subnet6 2001:db8:2:1::/64 {                       # (b)
    range6 2001:db8:2:1::100 2001:db8:2:1::200;   # (c)
}

# Réservation (TP3-2 §5)
host dns {
    host-identifier option dhcp6.client-id 00:01:00:01:1a:2b:3c:4d:08:00:27:00:0c:c0;
    fixed-address6 2001:db8:2:1::3;
}
EOF
```

> **Point technique à expliquer dans le rapport** : en DHCPv6, on **n'identifie pas un
> client par son adresse MAC** mais par son **DUID** (DHCP Unique Identifier), qui contient
> la MAC mais avec un préfixe. L'énoncé demande « réserver … à l'adresse MAC
> 01:00:80:a2:55:67 » : c'est une formulation IPv4. La syntaxe correcte est
> `host-identifier option dhcp6.client-id <DUID>`.
>
> Pour obtenir le DUID du client :
> ```bash
> # sur CLIENT
> dhclient -6 -D -v eth0 2>&1 | grep -i duid
> # ou, côté serveur, en observant la requête :
> tcpdump -ni eth0 -vv 'udp port 547'
> ```
> Puis recopier la valeur dans `host-identifier`. Si vous n'avez pas de client IPv6 à
> disposition, gardez la réservation telle quelle et expliquez la différence : c'est déjà
> une réponse juste.

### D.3 Vérifier et démarrer (TP3-2 §6-7)

```bash
dhcpd -6 -t -cf /etc/dhcp/dhcpd6.conf     # contrôle de syntaxe
systemctl enable --now dhcpd6
systemctl status dhcpd6 --no-pager
journalctl -u dhcpd6 -f
ss -lunp | grep :547
```

### D.4 Test client (TP3-2 §8)

```bash
# CLIENT-LINUX
ip -6 addr show eth0                       # doit avoir 2001:db8:2:1::1xx
dhclient -6 -v eth0
ip -6 route
cat /etc/resolv.conf
```

Windows : `ipconfig /all` → section « Adresse IPv6 » + « Bail obtenu » (IPv6 doit être coché
dans les propriétés de la carte).

### D.5 Arrêt du service (TP3-2 §9)

```bash
systemctl stop dhcpd6
systemctl disable dhcpd6      # si l'énoncé demande aussi de ne pas le relancer au boot
systemctl is-active dhcpd6    # → inactive
```

### D.6 Relais DHCP IPv4 (TP3-2 §10)

Le relais se place sur un **autre** sous-réseau que le serveur et transmet les requêtes en
unicast. Sur **CLIENT-LINUX**, ajouter une 2ᵉ carte (VirtualBox → Configuration → Réseau →
Adaptateur 2 → « Réseau privé » `relais`), puis :

```bash
yum install -y dhcp            # fournit /usr/sbin/dhcrelay
ip addr add 172.19.21.1/24 dev eth1
ip link set eth1 up

# Sur SRV-A : déclarer aussi le sous-réseau distant dans dhcpd.conf
cat >> /etc/dhcp/dhcpd.conf <<'EOF'

subnet 172.19.21.0 netmask 255.255.255.0 {
    range 172.19.21.100 172.19.21.150;
    option routers 172.19.21.1;
}
EOF
dhcpd -t && systemctl restart dhcpd

# Sur CLIENT : lancer le relais vers le serveur
dhcrelay -4 -i eth1 172.19.20.1
# vérifier
systemctl status dhcrelay 2>/dev/null || ps -ef | grep dhcrelay
journalctl -u dhcpd -f      # côté SRV-A : on doit voir les requêtes venir de 172.19.21.1
```

Preuve à faire dans le rapport : côté SRV-A, les lignes `DHCPDISCOVER ... via eth0` dont
l'adresse source est `172.19.21.1` (le relais), et non l'adresse du client. Sans 3ᵉ machine,
c'est déjà une démonstration complète du mécanisme.

---

## PARTIE E — Bonus TP4-2 §V : DDNS (facultatif, ~30 min)

À faire dans la VM **SRV-A** (elle a déjà `dhcpd`). Objectif : quand un client prend un bail,
le serveur DHCP met à jour la zone DNS tout seul.

```bash
yum install -y bind bind-utils

# 1. Clé partagée entre DHCP et DNS
rndc-confgen -a -c /etc/rndc.key
cat /etc/rndc.key

# 2. named.conf minimal avec la zone autorisant les mises à jour par cette clé
cat > /etc/named.conf <<'EOF'
include "/etc/rndc.key";
options {
    listen-on port 53 { any; };
    directory "/var/named";
    allow-query { any; };
    recursion no;
    dnssec-validation no;
};
zone "ofppt.infra" IN {
    type master;
    file "ofppt.infra.dir";
    allow-update { key rndc-key; };
};
EOF

cat > /var/named/ofppt.infra.dir <<'EOF'
$TTL 1H
@   IN SOA srv-a.ofppt.infra. admin.ofppt.infra. ( 1 2H 20M 1W 1H )
    IN NS  srv-a.ofppt.infra.
srv-a IN A 172.19.20.1
EOF

chown root:named /etc/rndc.key /var/named/ofppt.infra.dir
chmod 640 /etc/rndc.key /var/named/ofppt.infra.dir
restorecon -Rv /var/named /etc/rndc.key
named-checkconf && named-checkzone ofppt.infra /var/named/ofppt.infra.dir
systemctl enable --now named

# 3. Côté DHCP : activer les mises à jour
sed -i '1i ddns-update-style interim;\nddns-updates on;\ninclude "/etc/rndc.key";' /etc/dhcp/dhcpd.conf
cat >> /etc/dhcp/dhcpd.conf <<'EOF'

zone ofppt.infra. {
    primary 172.19.20.1;
    key rndc-key;
}
EOF
dhcpd -t && systemctl restart dhcpd
```

Test : sur CLIENT-LINUX, `dhclient -r eth0 && dhclient eth0` puis sur SRV-A :
`dig @172.19.20.1 <nom-du-client>.ofppt.infra` → la Zone doit contenir la nouvelle entrée
(`cat /var/named/ofppt.infra.dir.jnl` avec `named-journalprint`). Si ça ne marche pas, c'est
presque toujours le `include "/etc/rndc.key"` absent ou des droits SELinux — d'où le
`restorecon`.

---

## PARTIE F — Tests clients des autres TPs (le vrai travail de PC01)

À faire **au fur et à mesure**, jamais à la fin : les autres ont besoin de vos captures pour
valider leurs TPs.

### F.0 Réseau du PC01

- Se connecter au Wi-Fi du labo (c'est vous l'émetteur) → `192.168.137.1`.
- DNS de la carte « Point d'accès mobile » = `192.168.137.10` (SRV1).
- Vérifier : `nslookup www.ntic.local 192.168.137.10`

### F.1 TP4 — DNS

```powershell
nslookup srv1.ofppt.local 192.168.137.10
nslookup -type=MX ofppt.local 192.168.137.10
nslookup -type=NS ofppt.local 192.168.137.10
nslookup 192.168.137.30 192.168.137.10      # résolution inverse (PTR)
nslookup www.tri.local 192.168.137.10
```
Captures : les 5 sorties + le `ping srv1.ofppt.local` qui résout en 192.168.137.10.

### F.2 TP5 — Apache + SSL

1. `http://www.tri.local` → « Bienvenue sur le site TRI Offshore ».
2. `http://www.ntic.local` → redirection automatique vers `https://www.ntic.local`.
3. Avertissement de certificat → « Avancé » → « Continuer vers www.ntic.local ».
4. Page bleue soulignée avec « l'Exemple de virtual host NTIC fonctionne ».
5. Vérifier le cadenas → certificat → CN = `www.ntic.local`.

Captures : les 3 pages, l'URL https, le détail du certificat.

### F.3 TP6 — FTP

- `cmd` → `ftp 192.168.137.20` → `root` → **530 Permission denied** (capture).
- → `ftpaccess` / `eff2017v31` → **530** aussi (bloqué au TP6 P4) (capture).
- → `tri` / `ofppt` → `pwd`, `ls`, `put`, `get` → captures.
- FileZilla → `tri` → montrer que `/` est la racine et qu'on ne peut pas remonter (chroot).

### F.4 TP8 — NFS

Windows ne fait pas de client NFS natif ; la preuve Windows est remplacée par **Linux A**
qui monte (doc 03). Captures à récupérer auprès de Linux A pour le rapport.

### F.5 TP9 — Samba

1. `\\192.168.137.20\decouverte` → identifiants `wahid` → ouvrir/modifier `tp.txt`,
   créer un dossier → OK (captures).
2. `net use \\192.168.137.20\decouverte /delete` puis `hiba` → lecture OK, création
   refusée (capture du message « Accès refusé »).
3. Sans identifiant → refus (capture).
4. Clic droit → « Connecter un lecteur réseau » → lecteur `Z:` (capture).

### F.6 Matrice de tests à joindre

| Test | Depuis | Commande / action | Attendu | Fait |
|---|---|---|---|---|
| Bail DHCP IPv4 | CLIENT-LINUX | `dhclient -v` | 172.19.20.5x | ☐ |
| Bail DHCP IPv4 | PC01 | `ipconfig /renew` | 172.19.20.x | ☐ |
| Exclusion .60-.70 | CLIENT-LINUX | 4 renew | jamais .60-.70 | ☐ |
| Réservation MAC | CLIENT-LINUX | MAC forcée | .202 | ☐ |
| Bail DHCPv6 | CLIENT-LINUX | `dhclient -6 -v` | 2001:db8:2:1::1xx | ☐ |
| Relais | SRV-A logs | `dhcrelay` actif | requêtes depuis .21.1 | ☐ |
| A / MX / NS / PTR | PC01 | nslookup | valeurs du doc 01 | ☐ |
| Site tri | PC01 | navigateur | page TRI | ☐ |
| Site ntic | PC01 | navigateur | https + page bleue | ☐ |
| FTP root | PC01 | ftp | 530 | ☐ |
| FTP tri | PC01 | ftp/FileZilla | lecture+écriture | ☐ |
| Chroot | PC01 | FileZilla | pas de remontée | ☐ |
| Samba wahid | PC01 | `\\192.168.137.20` | rw | ☐ |
| Samba hiba | PC01 | `\\192.168.137.20` | ro | ☐ |
| Samba anonyme | PC01 | `\\192.168.137.20` | refus | ☐ |

---

## PARTIE G — Organisation des livrables

Un dossier par TP, et dans chaque dossier :

```
RENDU/
├── TP3/  TP3.doc · dhcpd.conf · dhcpd6.conf · captures/
├── TP4/  TP4.doc · named.conf · ofppt.local.dir · 192.168.137.rev · ntic.local.dir · tri.local.dir
├── TP5/  TP5.doc · ScTP5.txt · vhosts.conf · index.html ×2
├── TP6/  TP6.doc · ScTP6.txt · vsftpd.conf
├── TP8/  TP8.doc · exports · fstab
└── TP9/  TP9.doc · smb.conf
```

**Convention de nommage des captures** : `TP3-05-dhcp-ack.png`, `TP5-03-https.png`…
Numérotées dans l'ordre des questions de l'énoncé → le correcteur suit sans chercher.

**Règle d'or pour les `.doc`** : chaque question = le numéro, la commande, la sortie réelle,
et une phrase d'interprétation. Jamais « ça marche ». Un TP rendu avec les sorties brutes
vaut plus que trois pages de blabla.
