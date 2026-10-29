# 10 — LABO CÂBLÉ : mode opératoire, étape par étape

> **Matériel réel** : 2 câbles Ethernet · pas de switch · PC Windows **sans prise RJ45** ·
> une prise Ethernet sur chaque Linux.
>
> → Le seul montage possible aujourd'hui : **🅰 ═══ câble ═══ 🅱** (§ principal, 14 étapes).
> Le PC Windows reste **hors du réseau du labo** ; il fait son TP3 en VM et ses tests clients
> se font depuis 🅰. Le pont Windows (§ Annexe A) demande **2 adaptateurs USB-Ethernet**.
>
> **Règle unique** : on avance étape par étape. Chaque étape = **TU FAIS** → **TU DOIS VOIR**
> → **SI ÇA RATE**. Si « TU DOIS VOIR » n'est pas obtenu, **on ne passe pas à la suite**.
>
> Durée : **20 min** pour les 14 étapes.

```
   🅰 Linux A 192.168.137.10  ═══════ câble ═══════  🅱 Linux B 192.168.137.20

   🆆 PC Windows : hors réseau du labo (pas de prise RJ45)
                   → TP3 en VM host-only, autonome
```

Plan d'adressage **inchangé** : `192.168.137.0/24`, 🅰 `.10`, 🅱 `.20`, 🆆 `.1` (réservé,
non branché). Ni passerelle, ni Internet par le câble.

---

# MODE OPÉRATOIRE — réseau A ↔ B

## Étape 1 — 🅰 Brancher et vérifier le lien

**TU FAIS**

```bash
cat /sys/class/net/enp1s0/carrier     # 1 = câble détecté
ip -br link show enp1s0               # doit contenir UP
```

**TU DOIS VOIR**

```
1
enp1s0    UP    74:e5:f9:xx:xx:xx <BROADCAST,MULTICAST,UP,LOWER_UP>
```

**SI ÇA RATE**

| Sortie | Cause | Action |
|---|---|---|
| `0` | pas de lien | rebrancher les **deux** bouts ; changer de câble ; vérifier que 🅱 est allumé |
| `DOWN` | interface désactivée | `sudo ip link set enp1s0 up`, puis relis `carrier` |
| `enp1s0` introuvable | autre nom | `ip -br link` → utilise le nom trouvé (`eno1`, `enp3s0`…) dans **toutes** les commandes suivantes |

> Coche : `[ ] étape 1 — carrier = 1 sur 🅰`

## Étape 2 — 🅰 Libérer le Wi-Fi

**TU FAIS** — le profil Wi-Fi porte encore `192.168.137.10/24` : la même IP sur deux
interfaces casse tout. On le remet en DHCP, **par UUID** (les noms changent quand la machine
roame) :

```bash
UUID="$(nmcli -g UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)"
echo "UUID = $UUID"
nmcli connection modify "$UUID" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
```

**TU DOIS VOIR**

```bash
ip -4 -o addr show | grep 192.168.137 || echo "aucune IP du labo : c'est bon"
# aucune IP du labo : c'est bon
```

**SI ÇA RATE** — tu vois deux fois `192.168.137.10` (sur `wlp2s0` **et** `enp1s0`) : tu as
modifié le mauvais profil. Reprends avec l'UUID affiché ci-dessus.

> Coche : `[ ] étape 2 — Wi-Fi de 🅰 en DHCP`

## Étape 3 — 🅰 Créer le profil câblé

**TU FAIS** — à coller d'un bloc :

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

> `never-default yes` : aucune passerelle → le câble porte le labo et ne capte pas Internet.
> `autoconnect no` : le profil ne se lève pas au démarrage, seulement à la main.

**SI ÇA RATE** — « failed to add » : l'interface n'existe pas sous ce nom → reprends avec le
nom trouvé à l'étape 1.

> Coche : `[ ] étape 3 — profil tp-cable créé sur 🅰`

## Étape 4 — 🅰 Monter et vérifier

**TU FAIS**

```bash
sudo nmcli connection up tp-cable
ip -4 a show enp1s0
ip r
```

**TU DOIS VOIR**

```
inet 192.168.137.10/24 brd 192.168.137.255 scope global noprefixroute enp1s0
192.168.137.0/24 dev enp1s0 proto kernel scope link src 192.168.137.10
```

Deux contrôles : **`.10/24` sur `enp1s0`** · **aucune ligne `default via 192.168.137.1`**.

> `ip neigh` sera vide à cette étape : 🅱 n'est pas encore configuré. C'est normal.

**SI ÇA RATE**

| Symptôme | Cause | Action |
|---|---|---|
| pas d'IP `.10` | profil non monté | relis la sortie de `nmcli connection up` |
| `default via 192.168.137.1` | `never-default` non appliqué | `sudo nmcli connection modify tp-cable ipv4.never-default yes && sudo nmcli connection up tp-cable` |

> Coche : `[ ] étape 4 — 🅰 en .10/24, sans passerelle`

## Étape 5 — 🅱 Vérifier le lien

**TU FAIS** — sur 🅱 :

```bash
cat /sys/class/net/enp1s0/carrier
ip -br link show enp1s0
```

**TU DOIS VOIR** — `1` puis `UP`.

**SI ÇA RATE** — `0` alors que le câble est branché sur 🅰 (dont `carrier` vaut `1`) : c'est le
câble ou la prise de 🅱. Change de câble (tu en as deux).

> Coche : `[ ] étape 5 — carrier = 1 sur 🅱`

## Étape 6 — 🅱 Libérer le Wi-Fi

**TU FAIS**

```bash
UUID="$(nmcli -g UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)"
nmcli connection modify "$UUID" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
```

**TU DOIS VOIR**

```bash
ip -4 -o addr show | grep 192.168.137 || echo "aucune IP du labo : c'est bon"
```

> Coche : `[ ] étape 6 — Wi-Fi de 🅱 en DHCP`

## Étape 7 — 🅱 Créer le profil câblé

**TU FAIS**

```bash
sudo nmcli connection delete tp-cable 2>/dev/null
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.20/24 \
     ipv4.never-default yes \
     ipv4.dns "192.168.137.10" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no
```

**TU DOIS VOIR** — `ajoutée avec succès`, adresse `.20` (trois différences avec 🅰 : `.20`, le
DNS `.10`, et rien d'autre).

> Coche : `[ ] étape 7 — profil tp-cable créé sur 🅱`

## Étape 8 — 🅱 Monter et vérifier

**TU FAIS**

```bash
sudo nmcli connection up tp-cable
ip -4 a show enp1s0
ip neigh
```

**TU DOIS VOIR** — `.20/24` sur `enp1s0`, et **une entrée ARP pour `.10`** :

```
192.168.137.10 dev enp1s0 lladdr xx:xx:xx:xx:xx:xx REACHABLE
```

**SI ÇA RATE** — pas d'entrée `.10` : 🅰 n'est pas monté → `ping -c2 192.168.137.10`, puis
relis `ip neigh`. Si toujours rien, retourne à l'étape 4 sur 🅰.

> Coche : `[ ] étape 8 — 🅱 en .20/24, voit 🅰`

## Étape 9 — Le ping croisé (la vraie porte de sortie)

**TU FAIS**

```bash
# sur 🅰
ping -c2 192.168.137.20

# sur 🅱
ping -c2 192.168.137.10
```

**TU DOIS VOIR** — `2 received, 0% packet loss` **des deux côtés**.

Le ping fonctionne ici : aucun pare-feu Windows sur le chemin (c'était la cause des faux
échecs du hotspot).

**SI ÇA RATE**

```bash
ip neigh show            # une MAC en face = le lien est bon, le blocage est logiciel
sudo ufw status          # sur les deux machines
sudo ufw allow from 192.168.137.0/24
```

> Coche : `[ ] étape 9 — ping OK dans les deux sens`

## Étape 10 — 🅰 Le contrôle officiel

**TU FAIS**

```bash
bash 00-verif-reseau.sh .10 --isole
```

**TU DOIS VOIR** — en vert, dernière ligne :

```
PHASE 1 VALIDÉE — 5 contrôles OK (mode isole)
```

**SI ÇA RATE** — chaque `[ECHEC]` indique l'attendu et l'obtenu :

| `[ECHEC]` sur | Revoir |
|---|---|
| `hostname -f` | `sudo hostnamectl set-hostname srv1.ofppt.local` |
| `192.168.137.10/24` | étape 4 |
| `/etc/hosts` | ajouter les 3 lignes du labo (doc 00 §3) |

> Coche : `[ ] étape 10 — 🅰 validé`

## Étape 11 — 🅱 Le contrôle officiel

**TU FAIS**

```bash
bash 00-verif-reseau.sh .20 --isole
```

**TU DOIS VOIR** — `PHASE 1 VALIDÉE — 5 contrôles OK (mode isole)`.

> Coche : `[ ] étape 11 — 🅱 validé`

## Étape 12 — 🅱 interroge le DNS de 🅰 par le câble

**TU FAIS** — sur 🅱 (bind9 doit tourner sur 🅰) :

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

> Coche : `[ ] étape 12 — DNS joignable depuis 🅱`

## Étape 13 — Reprendre le playbook

**TU FAIS** — retour dans `09_PLAYBOOK_RELAIS.md` à l'étape **19** (paquets + comptes sur 🅱),
puis **25 bis** (bascule du résolveur de 🅱).

**TU DOIS VOIR** — le playbook avance : le réseau n'est plus un blocage.

> Coche : `[ ] étape 13 — playbook repris à l'étape 19`

## Étape 14 — Retour à la normale

```bash
# sur 🅰 et sur 🅱
sudo nmcli connection delete tp-cable
nmcli radio wifi on
```

Puis, pour tout le reste (hostname, `systemd-resolved`, `bind9`, `/etc/hosts`, profils Wi-Fi) :

```bash
sudo bash 98-retour-a-la-normale.sh
```

> Coche : `[ ] étape 14 — machines rendues à leur usage normal`

---

# ANNEXE A — Le PC Windows sans prise RJ45 : les trois solutions

**Aucun switch ne résout ça** : sans prise, Windows ne peut pas être câblé, point. Un switch
ne sert qu'à multiplier les ports Ethernet.

| Solution | Coût | Ce que ça donne | Aujourd'hui ? |
|---|---|---|---|
| **Rien** (état actuel) | 0 | 🅰↔🅱 câblés, 🆆 hors labo : TP3 en VM, tests clients depuis 🅰 | ✅ **oui** |
| **2 adaptateurs USB-Ethernet** | ~120–200 DH | pont Windows complet (2 câbles, schéma d'origine) | non |
| **1 adaptateur + 1 switch 5 ports + 3 câbles** | ~250 DH | les 3 machines sur le switch, le plus propre | non |

Un seul adaptateur ne suffit pas : Windows aurait un port pour **un** câble, et l'autre Linux
resterait à l'écart (le pont a besoin de deux interfaces).

## Si un jour tu as les 2 adaptateurs : pont Windows

Seules les étapes 1 à 4 changent (côté 🆆). Le reste du mode opératoire est identique, sauf
qu'on retire `--isole` du script (la passerelle `.1` existe).

```
étape 1  Get-NetAdapter | ? {$_.PhysicalMediaType -like "*802.3*"} | ft Name,Status
étape 2  brancher : adaptateur 1 → 🅰, adaptateur 2 → 🅱
étape 3  ncpa.cpl → sélectionner les 2 adaptateurs → clic droit → Créer un pont
         (renommer le pont : "Pont labo")
étape 4  netsh interface ipv4 set address name="Pont labo" static 192.168.137.1 255.255.255.0
```

Puis, sur 🅰 et 🅱, **une seule modification** par rapport au mode A↔B :

```bash
sudo nmcli connection modify tp-cable ipv4.never-default no ipv4.gateway 192.168.137.1
sudo nmcli connection up tp-cable
```

Et pour Internet (facultatif) : `ncpa.cpl` → clic droit sur la connexion qui donne Internet →
Propriétés → Partage → cocher → choisir `Pont labo`. Windows repose alors `.1/24` : c'est son
sous-réseau par défaut, aucun conflit avec notre plan.

---

# ANNEXE B — Dépannage express

| Symptôme | Où | Cause | Diagnostic |
|---|---|---|---|
| `carrier = 0` | Linux | pas de lien physique | `cat /sys/class/net/enp1s0/carrier` |
| `ip neigh` vide | Linux | l'autre machine n'est pas montée | `ping -c2 <autre IP>` puis `ip neigh` |
| deux IP `192.168.137.x` | Linux | Wi-Fi pas nettoyé | `ip -4 -o addr show \| grep 192.168.137` |
| ping muet, MAC présente | Linux | ufw | `sudo ufw status` |
| `.10` répond, `.20` non | — | 🅱 non monté | étape 8 |
| DNS `connection refused` | 🅱 | bind9 arrêté sur 🅰 | `systemctl start bind9` |
| pas d'Internet | les deux | **normal** : pas de passerelle | `apt` par clé USB (`scripts/97-…`) |

---

# ANNEXE C — À quoi sert le poste Windows

Il **n'héberge aucun service** du module : c'est un **client de test** et l'**hôte des VM du
TP3**.

| Rôle | Où c'est exigé | Sans réseau câblé |
|---|---|---|
| Client de test (captures) | TP3 §9, TP4, TP5 (certificat), TP6, TP9 (`\\srv2\partage`) | ❌ impossible depuis Windows |
| Hôte VirtualBox des VM DHCP | TP3-1, TP3-2 | ✅ **autonome** (host-only, aucun besoin du labo) |

Conséquence à assumer, et **à écrire dans le rapport** :

> « Le poste client Windows ne disposant d'aucune interface Ethernet, il n'a pas pu être
> intégré au segment câblé du laboratoire. Les tests clients des TP4/5/6/9 ont donc été
> réalisés depuis SRV1 (`curl`, `dig`, `smbclient`, `ftp`, `showmount`). Le TP3 (DHCP),
> exécuté en machines virtuelles sur réseau host-only, reste totalement indépendant de
> cette contrainte. »

Remplacement propre, si tu veux des captures Windows : **une VM Windows en « accès par pont »
sur `enp1s0`** de 🅰. Elle apparaît sur le segment en `192.168.137.1` et se comporte comme le
PC physique.

---

# ANNEXE D — Variante « deux machines »

Si un jour un seul Linux est disponible : les six TP restent faisables sur une machine, mais
on perd le montage NFS (client/serveur) et le DNS esclave. À éviter — et le TP8 (NFS) demande
explicitement deux hôtes.
