# 10 — Réseau CÂBLÉ : remplacer le hotspot Wi-Fi

> Ce document **remplace le §5.2 du doc 00** quand le labo est câblé.
> Tout le reste (zones DNS, vhosts, Samba, NFS, TP3) ne change pas — sauf ce qui est
> listé au §5.

---

## 1. La contrainte à comprendre avant de brancher

Un câble Ethernet relie **exactement deux prises**. Ce n'est pas un bus : il n'y a pas de
« réseau qui circule dans le câble ».

```
   2 câbles  +  3 machines  =  il manque quelque chose
```

Trois machines sur un même réseau câblé, ça demande **une** de ces deux choses :

| Solution | Coût | Résultat |
|---|---|---|
| Un **switch** 5 ports (le plus simple) | ~100–150 DH | les 3 machines sur le même segment, aucun réglage réseau exotique |
| **une machine à 2 ports** (PC Windows avec 2 cartes, ou 1 port + adaptateur USB-Ethernet) | ~80 DH (adaptateur) | cette machine devient le nœud central |

Sans l'un des deux, ton deuxième câble ne peut relier que **deux** machines, et la troisième
reste en Wi-Fi — donc le point faible que tu cherches à supprimer reste.

**Test rapide de ce que tu as :**

```bash
# sur chaque Linux : combien de ports Ethernet physiques ?
ip -br link | grep -E '^en'
```

Sur le PC Windows : `ipconfig /all`, ou regarder derrière la machine.
Un port RJ45 = une seule liaison possible.

---

## 2. Les trois câblages possibles

### Schéma A — Switch 5 ports (recommandé)

```
        ┌──────────────┐
        │  switch 5p   │
        └──┬───┬───┬───┘
           │   │   │
   ┌───────┘   │   └────────┐
   │           │            │
 PC Windows  Linux A      Linux B
 192.168.137.1   .10      .20
   │
   └── Wi-Fi école / téléphone (Internet)
```

Le PC Windows partage sa connexion Internet sur son port Ethernet (ICS) → il reste
`192.168.137.1`, et **tous les documents existants s'appliquent sans modification**.

### Schéma B — PC Windows avec 2 ports Ethernet, sans switch

```
   PC Windows (2 cartes Ethernet)
   ├── carte 1 ──câble──► Linux A  192.168.137.10
   ├── carte 2 ──câble──► Linux B  192.168.137.20
   └── (les deux cartes réunies en PONT réseau, IP 192.168.137.1 sur le pont)
```

Les deux cartes sont sélectionnées dans Windows → clic droit → **Créer un pont**
(*Bridge Connections*). On met ensuite `192.168.137.1/24` sur le pont, et on partage
(ICS) la connexion Wi-Fi **vers le pont**.

Même résultat que le schéma A : Windows reste `192.168.137.1`, les documents existants
s'appliquent sans modification.

> Ce montage marche, mais il est moins fiable qu'un switch : un pont logiciel sous Windows
> se comporte mal quand une des deux cartes passe en veille. **Le schéma A reste le plus simple.**

### Schéma C — 2 câbles seulement, pas de switch : réseau isolé A ↔ B

C'est le seul montage qui fonctionne avec exactement 2 câbles et 3 machines dont aucune n'a
2 ports. Mais il faut accepter une chose : **le PC Windows n'est plus sur le réseau du labo**.

```
   Linux A  ═════════ câble 1 ═════════  Linux B
   192.168.137.10                        192.168.137.20

   (le câble 2 reste libre : prise murale, ou rien)
```

Conséquences, à assumer :

- Le PC Windows ne peut pas tester Apache/FTP/Samba/NFS. Ces tests se font **depuis Linux A**
  (`curl`, `smbclient`, `showmount`) — c'est prévu dans les documents, il suffit de remplacer
  « depuis Windows » par « depuis SRV1 ».
- Le PC Windows fait quand même son **TP3** : les 2 VM VirtualBox sont sur un réseau
  host-only, elles n'ont pas besoin du labo.
- **Pas de passerelle par défaut** : `192.168.137.1` (pc01) reste une adresse dans les zones
  DNS, mais elle ne répondra pas. À noter dans le rapport.
- **Pas d'Internet** : `apt` se fait depuis une clé USB (script `97-paquets-hors-ligne.sh`).

C'est le montage du §3 ci-dessous.

---

## 3. Configuration du schéma C (réseau câblé isolé)

> **Si tu es en schéma A ou B** (switch ou pont Windows) : ne lis pas ce §3. Le PC Windows
> reste la passerelle `192.168.137.1`, et **le §5.2 du doc 00 s'applique tel quel** — la
> seule différence est le nom de l'interface (`enp1s0` au lieu de `wlp2s0`). Un profil
> câblé équivalent, sans `never-default`, suffit :
>
> ```bash
> sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
>      ipv4.method manual ipv4.addresses 192.168.137.10/24 \
>      ipv4.gateway 192.168.137.1 ipv4.dns "127.0.0.1,192.168.137.1" \
>      ipv4.dns-search "ofppt.local"
> ```
>
> Le reste du §3 ne concerne que le montage à **deux câbles sans switch**.

### 3.1 Ce qui ne change PAS

| Élément | Reste identique |
|---|---|
| Plan d'adressage | `192.168.137.0/24`, A=`.10`, B=`.20`, pc01=`.1` |
| Zones Bind, enregistrements A/CNAME/MX/PTR | **aucune modification** |
| Vhosts Apache, certificat, pages | aucune modification |
| vsftpd, Samba, exports NFS | aucune modification |
| `/etc/hosts` sur A et B | aucune modification |
| Scripts `00` / `01` | fonctionnent (le script détecte l'absence de passerelle) |

### 3.2 Ce qui change

| Élément | Avant (hotspot) | Après (câble isolé) |
|---|---|---|
| Interface | `wlp2s0` (Wi-Fi) | `enp1s0` (Ethernet) |
| Méthode | `manual` sur le profil Wi-Fi | profil Ethernet dédié `tp-cable` |
| Passerelle | `192.168.137.1` | **aucune** (`ipv4.never-default yes`) |
| DNS sur A | `192.168.137.1` | `127.0.0.1` (une fois Bind lancé) |
| Internet / `apt` | via le hotspot | **non disponible** → clé USB |
| `forwarders` de Bind | `192.168.137.1` | à commenter (sinon 5 s d'attente à chaque requête externe) |

### 3.3 Sur Linux A

```bash
# 1. Vérifier que le lien physique est détecté AVANT de configurer
cat /sys/class/net/enp1s0/carrier      # 1 = câble détecté ; 0 = rien
ip -br link show enp1s0                # doit être "UP"

# 2. Créer un profil dédié (idempotent : supprime l'ancien s'il existe)
sudo nmcli connection delete tp-cable 2>/dev/null || true
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.10/24 \
     ipv4.never-default yes \
     ipv4.dns "127.0.0.1" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no

sudo nmcli connection up tp-cable

# 3. Vérifications
ip -4 a show enp1s0                   # 192.168.137.10/24
ip r                                  # PAS de "default via 192.168.137.1" — c'est voulu
hostname -f                           # srv1.ofppt.local
```

> `connection.autoconnect no` : le profil ne se connecte pas tout seul au démarrage, pour ne
> pas perturber ton PC quand tu n'es pas en TP. Tu le montes à la main avec
> `nmcli connection up tp-cable`.

### 3.4 Sur Linux B

```bash
cat /sys/class/net/enp1s0/carrier      # 1

sudo nmcli connection delete tp-cable 2>/dev/null || true
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.20/24 \
     ipv4.never-default yes \
     ipv4.dns "192.168.137.10" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no

sudo nmcli connection up tp-cable
ip -4 a show enp1s0                   # 192.168.137.20/24
```

### 3.5 Vérifier le lien entre les deux

```bash
# A
ping -c2 192.168.137.20
# B
ping -c2 192.168.137.10
```

Puis le contrôle officiel de la phase 1, en mode sans passerelle :

```bash
bash 00-verif-reseau.sh .10 --isole     # sur A
bash 00-verif-reseau.sh .20 --isole     # sur B
# attendu : PHASE 1 VALIDÉE — N contrôles OK (mode isole)
```

(Le mode `isole` est détecté tout seul ; `--isole` ne sert qu'à forcer le cas si une route
par défaut traîne encore.)

Le ping **fonctionne** ici : il n'y a pas de pare-feu Windows sur le chemin. S'il échoue :

```bash
ip neigh show dev enp1s0        # une MAC en face = le lien est bon
sudo ethtool enp1s0 | grep "Link detected"
sudo journalctl -u NetworkManager -n 20 --no-pager
```

### 3.6 Adapter Bind à l'absence d'Internet

Dans `/etc/bind/named.conf.options` :

```
    listen-on port 53 { 127.0.0.1; 192.168.137.10; };
    allow-query { any; };
    recursion yes;

    /* réseau isolé : plus de resolveur amont.
       Laisser un forwarder injoignable = 5 s d'attente par requete externe. */
    // forwarders { 192.168.137.1; 212.217.0.12; };
    dnssec-validation no;
```

Puis :

```bash
sudo named-checkconf && sudo systemctl restart bind9
dig @127.0.0.1 www.ntic.local +short     # doit toujours répondre
dig @127.0.0.1 github.com +short         # échoue : NORMAL, pas d'Internet
```

### 3.7 Installe les paquets depuis une clé USB

```bash
# préparé à la maison :  bash 97-paquets-hors-ligne.sh
sudo apt install ./paquets-tp/*.deb
```

### 3.8 Garder Internet en même temps (câble pour le labo, Wi-Fi pour `apt`)

C'est le montage le plus confortable : le **câble** porte le labo (`192.168.137.x`), le
**Wi-Fi** garde la connexion Internet de la maison. Les deux coexistent sans se gêner, à
condition que la route par défaut reste sur le Wi-Fi — c'est exactement ce que fait
`ipv4.never-default yes` sur le profil `tp-cable`.

```bash
# ne pas toucher au profil Wi-Fi : il garde DHCP + route par défaut
ip route            # doit montrer :  default via <box> dev wlp2s0
                    #               192.168.137.0/24 dev enp1s0 ...
ip -4 a show enp1s0 # 192.168.137.10/24
```

Conséquences :

- `apt` fonctionne → **pas besoin de clé USB**.
- Bind peut garder ses `forwarders` (internet présent) : `dig @127.0.0.1 github.com` répond.
- Le script de contrôle le reconnaît tout seul (**mode `double`**) : il ne réclame pas de
  passerelle labo et exige seulement que l'Internet réponde.

> ⚠️ Dans ce montage, **le nom de domaine du Wi-Fi ne doit pas écraser `ofppt.local`** :
> c'est pour ça que le profil `tp-cable` porte `ipv4.dns-search "ofppt.local"` et que la
> bascule du résolveur (doc 07 §3.7) reste nécessaire sur 🅰.

---

## 4. Retour à la normale après le TP

```bash
# enlever le profil câblé
sudo nmcli connection delete tp-cable

# si le Wi-Fi avait été figé en IP statique :
sudo nmcli connection modify "NOM_DU_WIFI" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
```

Ou en une commande, pour tout le reste (hostname, `systemd-resolved`, `bind9`, `/etc/hosts`) :

```bash
sudo bash 98-retour-a-la-normale.sh
```

---

## 5. Ce qu'il faut dire dans le rapport

Deux phrases suffisent, et elles montrent que vous avez compris :

> « Le laboratoire utilise un réseau privé `192.168.137.0/24` isolé, câblé en Ethernet entre
> les deux serveurs Linux. Aucune passerelle par défaut n'est configurée : l'adresse
> `192.168.137.1` est réservée au poste client dans le plan d'adressage et les zones DNS,
> mais elle n'assure aucun routage.
> Les paquets logiciels ont été installés hors ligne depuis un dépôt local, le laboratoire
> n'ayant pas d'accès Internet. La résolution externe de `named` est donc désactivée
> (`recursion` conservée pour les zones locales uniquement). »

C'est exactement le genre de justification qui fait la différence entre « on a suivi la
feuille » et « on a compris ce qu'on a monté ».
