# 10 — LABO CÂBLÉ : mode opératoire, étape par étape

> **À suivre dans l'ordre, du haut en bas.** Une étape à la fois, on vérifie, on coche.
> Trois acteurs : 🆆 = PC Windows · 🅰 = Linux A (SRV1) · 🅱 = Linux B (SRV2).
>
> Chaque étape a trois blocs : **TU FAIS** → **TU DOIS VOIR** → **SI ÇA RATE**.
> Si « TU DOIS VOIR » n'est pas obtenu, **ne passe pas à l'étape suivante** : applique
> « SI ÇA RATE ». C'est la seule règle.
>
> Durée totale : **35 à 45 min** (dont 10 min côté Windows).
> Matériel : 2 câbles Ethernet, PC Windows à **2 prises RJ45**, 1 prise RJ45 par Linux.
> Le plan d'adressage ne change pas : `192.168.137.0/24`, 🅰 `.10`, 🅱 `.20`, 🆆 `.1`.

```
   🆆 PC Windows  192.168.137.1
   ├── prise 1 ──câble──► 🅰 Linux A  192.168.137.10
   └── prise 2 ──câble──► 🅱 Linux B  192.168.137.20
        (les deux prises réunies en PONT réseau)
```

---

# PHASE 0 — Avant de brancher (2 min)

## Étape 1 — 🆆 Compter les prises

**TU FAIS** — PowerShell **en administrateur** :

```powershell
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.3*"} |
    Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize
```

**TU DOIS VOIR** — **deux** lignes Ethernet (peu importe leur nom : `Ethernet`, `Ethernet 2`,
`Realtek PCIe GbE Family Controller`…).

**SI ÇA RATE**

| Ce que tu vois | Cause | Action |
|---|---|---|
| une seule ligne | une seule carte Ethernet | arrête ici : passe à l'**Annexe B** (réseau isolé A↔B) |
| deux lignes mais une en `Disabled` | carte désactivée | clic droit → Activer |
| `Get-NetAdapter` inconnu | vieux Windows | utilise `ipconfig /all` et compte les cartes physiques |

> Coche : `[ ] étape 1 — 2 cartes Ethernet vues`

---

# PHASE 1 — 🆆 PC Windows (10 min)

## Étape 2 — 🆆 Brancher les câbles

**TU FAIS**

1. Câble 1 : une prise du PC Windows → prise Ethernet de 🅰.
2. Câble 2 : l'autre prise du PC Windows → prise Ethernet de 🅱.
3. Les deux Linux **allumés**.

**TU DOIS VOIR** — les deux lignes de l'étape 1 passent en **`Up`** avec une vitesse
(`1 Gbps` ou `100 Mbps`) :

```powershell
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.3*"} |
    Format-Table Name, Status, LinkSpeed -AutoSize
```

**SI ÇA RATE**

- Une ligne reste `Disconnected` → le câble ou la prise est mort : **change de câble** et
  refais le test. Ne cherche pas midi à quatorze heures, un câble neuf coûte 15 DH.
- Les deux restent `Disconnected` → les Linux sont éteints, ou leurs cartes sont désactivées
  (`ip -br link` sur le Linux doit montrer `enp1s0` en `UP`).

> Coche : `[ ] étape 2 — les 2 liens sont Up`

## Étape 3 — 🆆 Créer le pont

**TU FAIS**

1. `Win + R` → tape `ncpa.cpl` → Entrée.
2. Sélectionne **les deux cartes Ethernet** (`Ctrl` + clic sur chacune).
3. Clic droit sur la sélection → **Créer un pont** (*Bridge Connections*).
4. Attends 5 s : une icône **« Pont réseau »** apparaît.
   Renomme-la **`Pont labo`** (`F2`).

**TU DOIS VOIR** — une nouvelle icône `Pont labo`, et les deux cartes physiques passées en
« Non connecté » / « Identifié ». **C'est normal** : elles sont membres du pont, elles n'ont
plus d'adresse propre.

**SI ÇA RATE**

| Symptôme | Cause | Action |
|---|---|---|
| « Créer un pont » grisé | une des cartes est déjà partagée (ICS) | clic droit sur chaque carte → Propriétés → onglet Partage → tout décocher, puis recommence |
| le pont se crée mais rien ne passe | pilote qui refuse le mode promiscuité | passe à l'**Annexe B** (réseau isolé A↔B) |
| pas de « Créer un pont » dans le menu | Windows familial / pilote virtuel | idem, Annexe B |

> Coche : `[ ] étape 3 — pont « Pont labo » créé`

## Étape 4 — 🆆 Donner l'adresse au pont

**TU FAIS** — PowerShell **en administrateur** (le nom doit être exactement `Pont labo`) :

```powershell
netsh interface ipv4 set address name="Pont labo" static 192.168.137.1 255.255.255.0
```

Sans Internet pour l'instant (on verra ça à l'étape 6).

**TU DOIS VOIR**

```powershell
ipconfig | Select-String -Pattern "Pont labo" -Context 0,6
#   Adresse IPv4. . . . . . . . . . . . . .: 192.168.137.1
#   Masque de sous-réseau . . . . . . . . .: 255.255.255.0
```

**SI ÇA RATE** — « Le nom spécifié n'est pas un adaptateur réseau » : le nom du pont n'est pas
`Pont labo`. Liste-les : `netsh interface show interface`, puis reprends avec le bon nom.

> Coche : `[ ] étape 4 — pont en 192.168.137.1/24`

## Étape 5 — 🅰 Vérifier le lien physique (côté Linux)

**TU FAIS**

```bash
cat /sys/class/net/enp1s0/carrier     # 1 = câble détecté
ip -br link show enp1s0               # doit contenir UP
```

**TU DOIS VOIR**

```
1
enp1s0           UP             74:e5:f9:xx:xx:xx <BROADCAST,MULTICAST,UP,LOWER_UP>
```

**SI ÇA RATE**

| Sortie | Cause | Action |
|---|---|---|
| `0` | pas de lien : câble, prise, ou carte en face éteinte | rebrancher, changer de câble, vérifier l'étape 2 |
| `DOWN` | interface désactivée | `sudo ip link set enp1s0 up` puis relis `carrier` |
| `enp1s0` introuvable | autre nom d'interface | `ip -br link` : utilise le nom trouvé (ex. `eno1`) dans toutes les commandes suivantes |

> Coche : `[ ] étape 5 — carrier = 1 sur 🅰`

## Étape 6 — 🅰 Libérer le Wi-Fi (obligatoire)

**TU FAIS** — le profil Wi-Fi porte encore `192.168.137.10/24`. La même IP sur deux
interfaces = panne garantie. On le remet en DHCP :

```bash
UUID="$(nmcli -g UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)"
echo "$UUID"                                    # note l'UUID
nmcli connection modify "$UUID" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
nmcli connection up "$UUID"
```

**TU DOIS VOIR**

```bash
ip -4 -o addr show | grep 192.168.137 || echo "aucune IP du labo : c'est bon"
```

**SI ÇA RATE** — `grep` renvoie deux lignes avec `192.168.137.10` (une sur `wlp2s0`, une sur
`enp1s0`) : refais la commande avec l'**UUID**, pas le nom (`MID-SAMA 6482`, `VERECHAGUINE…`
changent de nom quand la machine roame).

> Coche : `[ ] étape 6 — Wi-Fi en DHCP`

## Étape 7 — 🅰 Créer le profil câblé

**TU FAIS** — une seule commande, à coller d'un bloc :

```bash
sudo nmcli connection delete tp-cable 2>/dev/null
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.10/24 \
     ipv4.never-default yes \
     ipv4.dns "127.0.0.1" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no
```

**TU DOIS VOIR** — `Connexion « tp-cable » (…) ajoutée avec succès.`

> `never-default yes` = pas de passerelle : le câble porte le labo, il ne doit pas capter
> Internet. `autoconnect no` = le profil ne se lève pas tout seul au démarrage.

**SI ÇA RATE** — « Error: failed to add 'tp-cable' » : l'interface n'existe pas sous ce nom.
Reprends avec le nom de l'étape 5.

> Coche : `[ ] étape 7 — profil tp-cable créé`

## Étape 8 — 🅰 Monter le profil et vérifier

**TU FAIS**

```bash
sudo nmcli connection up tp-cable
ip -4 a show enp1s0
ip r
ip neigh show dev enp1s0
```

**TU DOIS VOIR**

```
inet 192.168.137.10/24 brd 192.168.137.255 scope global noprefixroute enp1s0
...
192.168.137.0/24 dev enp1s0 proto kernel scope link src 192.168.137.10
...
192.168.137.1 dev enp1s0 lladdr xx:xx:xx:xx:xx:xx REACHABLE
```

Les trois choses à contrôler : **l'IP `.10` sur `enp1s0`** · **aucune ligne `default via
192.168.137.1`** · **une MAC en face de `.1`** (le pont Windows répond).

**SI ÇA RATE**

| Symptôme | Cause | Action |
|---|---|---|
| pas de ligne `192.168.137.1` dans `ip neigh` | le pont n'est pas monté | `ping -c2 192.168.137.1` puis relis `ip neigh` ; si toujours rien, refais l'étape 4 |
| `.1` en `FAILED` | adresse absente côté Windows | `ipconfig` sur 🆆 : le pont a-t-il bien `192.168.137.1` ? |
| `ip r` montre `default via 192.168.137.1` | `never-default` non appliqué | `sudo nmcli connection modify tp-cable ipv4.never-default yes && sudo nmcli connection up tp-cable` |

> Coche : `[ ] étape 8 — 🅰 en .10, pont .1 joignable en ARP`

## Étape 9 — 🅱 Refaire les étapes 5 à 8, en `.20`

**TU FAIS** — exactement les mêmes commandes, avec trois différences :

```bash
cat /sys/class/net/enp1s0/carrier                # 1

UUID="$(nmcli -g UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)"
nmcli connection modify "$UUID" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
nmcli connection up "$UUID"

sudo nmcli connection delete tp-cable 2>/dev/null
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.20/24 \
     ipv4.never-default yes \
     ipv4.dns "192.168.137.10" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no
sudo nmcli connection up tp-cable

ip -4 a show enp1s0                              # 192.168.137.20/24
ip neigh show dev enp1s0                         # MAC de .1 ET de .10
```

**TU DOIS VOIR** — `192.168.137.20/24` sur `enp1s0`, et **deux** entrées ARP : `.1` et `.10`.

**SI ÇA RATE** — `.10` absent de `ip neigh` : c'est 🅰 qui n'est pas monté. Retourne à
l'étape 8 sur 🅰, puis reviens ici.

> Coche : `[ ] étape 9 — 🅱 en .20, voit .1 et .10`

---

# PHASE 2 — Les portes de sortie

## Étape 10 — Le pont laisse-t-il passer le trafic ?

**TU FAIS** — sur 🅰 :

```bash
ping -c2 192.168.137.20
```

**TU DOIS VOIR** — `2 received, 0% packet loss`.

**SI ÇA RATE** — et que `.20` répond sur 🅱 vers `.10`, applique dans cet ordre :

```bash
# 1. le pare-feu Linux (sur A ET sur B)
sudo ufw status                     # doit laisser passer les services ; sinon : sudo ufw allow from 192.168.137.0/24

# 2. le pont Windows (sur 🆆)
ping 192.168.137.10                 # si Windows joint .10 mais pas .20 : le pont est correct,
                                    # le problème est côté B
```

> ⚠️ `ping 192.168.137.1` depuis un Linux **peut** échouer : le pare-feu Windows filtre
> l'ICMP. Ce n'est **pas** une panne. Le test valable est en TCP : `curl` (étape 12).

> Coche : `[ ] étape 10 — ping A↔B OK`

## Étape 11 — Le contrôle officiel (phase 1)

**TU FAIS**

```bash
# sur 🅰
bash 00-verif-reseau.sh .10 --isole

# sur 🅱
bash 00-verif-reseau.sh .20 --isole
```

**TU DOIS VOIR** — la dernière ligne, en vert :

```
PHASE 1 VALIDÉE — 5 contrôles OK (mode isole)
```

**SI ÇA RATE** — le script dit exactement quel contrôle échoue (`[ECHEC]`), avec l'attendu et
l'obtenu. Reprends l'étape correspondante :

| `[ECHEC]` sur | Revoir |
|---|---|
| `hostname -f` | `sudo hostnamectl set-hostname srv1.ofppt.local` (ou `srv2…`) |
| `192.168.137.10/24` | étape 8 (ou 9) |
| `/etc/hosts` | ajouter les 3 lignes du labo (`/etc/hosts` du doc 00 §3) |

> En mode **B2** (Internet partagé par le pont, étape 12), lance sans `--isole`.
> Le script détecte seul : `mode hotspot`, `mode double` ou `mode isole`.

> Coche : `[ ] étape 11 — PHASE 1 VALIDÉE sur 🅰` · `[ ] sur 🅱`

## Étape 12 — Et Internet ? (facultatif, variante B2)

**Si le labo n'a pas besoin d'Internet** (paquets déjà installés ou clé USB) : **saute cette
étape**, elle ne sert qu'à `apt`.

**TU FAIS** — sur 🆆, `ncpa.cpl` :

1. Clic droit sur la connexion **qui donne Internet** (Wi-Fi ou autre) → Propriétés → onglet
   **Partage**.
2. Cocher **« Autoriser d'autres utilisateurs du réseau à se connecter via cette connexion »**.
3. Liste déroulante : **`Pont labo`** → OK.

Windows repose alors automatiquement `192.168.137.1/24` sur le pont (c'est son sous-réseau
par défaut : aucun conflit).

**TU DOIS VOIR** — sur 🅰 :

```bash
curl -sI --max-time 8 https://deb.debian.org | head -1
# HTTP/2 200
```

**SI ÇA RATE**

```bash
ip r                          # une route par défaut doit exister
ip route get 8.8.8.8          # doit sortir par enp1s0
```

Si `ip r` n'a pas de `default` : le partage n'est pas actif (retour à l'étape 12), ou il
partage vers la mauvaise carte.

> Coche : `[ ] étape 12 — Internet OK par le pont` (ou `[ ] sans objet`)

## Étape 13 — DNS : 🅱 interroge 🅰 par le câble

**TU FAIS** — sur 🅱 :

```bash
dig @192.168.137.10 www.ntic.local +short
dig @192.168.137.10 srv1.ofppt.local +short
```

**TU DOIS VOIR**

```
192.168.137.20
192.168.137.10
```

**SI ÇA RATE**

| Symptôme | Cause | Action |
|---|---|---|
| `connection refused` | bind9 arrêté sur 🅰 | sur 🅰 : `sudo systemctl start bind9` |
| `connection timed out` | pare-feu sur 🅰 | `sudo ufw allow 53` |
| `SERVFAIL` | zone en erreur | `sudo named-checkconf && sudo named-checkzone ofppt.local /etc/bind/zones/ofppt.local.dir` |

> Coche : `[ ] étape 13 — DNS de 🅰 répond depuis 🅱 par le câble`

## Étape 14 — Reprendre le playbook

**TU FAIS** — retour dans `09_PLAYBOOK_RELAIS.md`, à l'étape **19** (paquets + comptes sur 🅱),
puis **25 bis** (bascule du résolveur de 🅱).

**TU DOIS VOIR** — le playbook avance à nouveau : le réseau n'est plus un blocage.

> Coche : `[ ] étape 14 — playbook repris à l'étape 19`

---

# PHASE 3 — Retour à la normale

## Étape 15 — 🆆 Défaire le pont

`ncpa.cpl` → clic droit sur **`Pont labo`** → **Supprimer le pont**. Les deux cartes
redeviennent indépendantes (et repassent en DHCP).

## Étape 16 — 🅰 et 🅱 Défaire le profil câblé

```bash
sudo nmcli connection delete tp-cable
nmcli radio wifi on                  # si le Wi-Fi avait été coupé
```

Puis, pour tout le reste (hostname, `systemd-resolved`, `bind9`, `/etc/hosts`, profils Wi-Fi
en DHCP) :

```bash
sudo bash 98-retour-a-la-normale.sh
```

---

# ANNEXE A — Dépannage express

| Symptôme | Où | Cause | Commande de diagnostic |
|---|---|---|---|
| `carrier = 0` | Linux | pas de lien physique | `cat /sys/class/net/enp1s0/carrier` |
| `ip neigh` vide | Linux | le pont ne répond pas | `ping -c2 192.168.137.1` |
| `.1` en `FAILED` | Linux | adresse absente sur le pont | `ipconfig` sur Windows |
| deux IP `192.168.137.x` | Linux | Wi-Fi pas nettoyé | `ip -4 -o addr show \| grep 192.168.137` |
| `ping .1` muet, `curl` OK | Linux | ICMP filtré par Windows | **pas une panne** |
| `ping` A↔B muet | Linux | ufw, ou pont HS | `sudo ufw status` |
| pont instable | Windows | veille des cartes | Gestionnaire de périphériques → carte → Gestion de l'alimentation |
| pont impossible | Windows | pilote sans promiscuité | **Annexe B** |

---

# ANNEXE B — Plan de secours : réseau isolé A ↔ B

Si le pont Windows refuse de fonctionner : **un seul câble**, 🆆 sort du réseau du labo.

```
   🅰 192.168.137.10  ═══════ câble ═══════  🅱 192.168.137.20
```

1. Câble direct entre 🅰 et 🅱 (le second reste au sac).
2. Étapes 5 à 9 du mode opératoire, **sans** toucher à Windows (le `never-default yes` est
   déjà dans le profil `tp-cable`). Sur 🅱, `ipv4.dns "192.168.137.10"` inchangé.
3. Vérifier : `ping -c2 192.168.137.20` depuis 🅰 → doit répondre (aucun pare-feu Windows
   sur le chemin).
4. Contrôle : `bash 00-verif-reseau.sh .10 --isole` → `PHASE 1 VALIDÉE`.

**Ce qu'on perd** : les tests clients depuis Windows (TP4/5/6/9). Ils se font depuis 🅰
(`curl`, `dig`, `smbclient`, `ftp`, `showmount`), et on l'écrit dans le rapport.

---

# ANNEXE C — À quoi sert le poste Windows (et la variante deux machines)

Le PC Windows **n'héberge aucun service** : il est **client de test** et **hôte des VM du TP3**.

| Rôle | Où c'est exigé | Perdu si absent |
|---|---|---|
| Client de test (captures) | TP3 §9, TP4, TP5 (certificat), TP6, TP9 (`\\srv2\partage`) | les preuves « côté client » |
| Hôte VirtualBox des VM DHCP | TP3-1, TP3-2 | rien : VirtualBox existe sous Linux |

**Variante « deux machines »** : un seul câble, aucun pont, aucun switch. Deux Linux = les six
TP faisables (tous les services sont Linux) ; le client Windows devient une **VM VirtualBox en
accès par pont**. Deux Windows = le réseau marche, mais pas le module (ni Bind, ni vsftpd, ni
export NFS).

| Config | TP serveurs | TP3 | Client Windows | Câblage |
|---|---|---|---|---|
| 2 Linux + 1 Windows (ce doc) | ✅ | ✅ | ✅ natif | 2 câbles + pont |
| **2 Linux** + VM Windows en pont | ✅ | ✅ | ✅ en VM | **1 câble** |
| 2 Windows | ❌ | ✅ VM | ✅ natif | 1 câble |

**Ordre de préférence : 2 Linux + 1 Windows › 2 Linux + VM Windows › 2 Windows.**

---

# ANNEXE D — Ce qu'on dit dans le rapport

> « Le laboratoire utilise un réseau privé `192.168.137.0/24` en Ethernet. Le PC client
> Windows, qui possède deux interfaces, est configuré en **pont logiciel** : il relie les deux
> serveurs Linux sur un même segment sans switch physique, et porte l'adresse `192.168.137.1`
> du plan d'adressage.
> La connexion Internet, lorsqu'elle est disponible, est partagée vers ce pont, ce qui place
> automatiquement le laboratoire dans le sous-réseau `192.168.137.0/24` ; en son absence, les
> paquets sont installés hors ligne depuis un dépôt local.
> Le partage de connexion Windows filtrant l'ICMP, les tests de connectivité ont été validés
> en TCP (`curl`, `smbclient`, `dig`) plutôt qu'en `ping`. »
