# 10 — Réseau CÂBLÉ : remplacer le hotspot Wi-Fi

> Ce document **remplace le §5.2 du doc 00** quand le labo est câblé.
> Tout le reste (zones DNS, vhosts, Samba, NFS, TP3) ne change pas — sauf ce qui est
> listé aux §3.2 et §4.2.
>
> **Matériel retenu pour ce labo** : 2 câbles Ethernet, pas de switch, PC Windows avec
> **2 prises RJ45** → **schéma B (pont Windows)**, décrit au §3.
> Le §4 (réseau isolé A ↔ B) reste en secours si le pont refuse de fonctionner.

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
| Un **switch** 5 ports | ~100–150 DH | les 3 machines sur le même segment, rien à configurer |
| **une machine à 2 ports** (ici : le PC Windows) | gratuit si la machine les a | cette machine devient le **nœud central** (pont logiciel) |

**Ce que tu as :** PC Windows avec 2 prises RJ45, aucun switch → la deuxième ligne du tableau.
Le PC Windows ne sert plus de point d'accès Wi-Fi, il sert de **switch logiciel** (un pont).

```
        AVANT (hotspot)                     APRÈS (câblé, pont)
   ┌──────────────────────┐            ┌──────────────────────┐
   │  PC01  Wi-Fi ─ AP ─┐ │            │  PC01                │
   │        192.168.137.1│ │            │  câble 1 → Linux A   │
   └─────────┬─────┬────┘ │            │  câble 2 → Linux B   │
             │     │      │            └──────────────────────┘
        Linux A  Linux B
```

---

## 2. Les trois câblages possibles

### Schéma A — switch 5 ports (le plus simple, si un jour tu en as un)

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

Rien à configurer côté Windows (à part l'IP .1 et, si besoin, le partage de connexion).
**Tous les documents existants s'appliquent sans modification.**

### Schéma B — PC Windows à 2 ports : pont logiciel ← **ton montage**

```
   PC Windows
   ├── carte Ethernet 1 ──câble──► Linux A  192.168.137.10
   ├── carte Ethernet 2 ──câble──► Linux B  192.168.137.20
   └── (les deux cartes réunies en PONT, IP 192.168.137.1 sur le pont)
```

Windows « relie » les deux cartes en interne : ce que Linux A envoie à Linux B passe par le
pont. Du point de vue des Linux, c'est **exactement comme s'ils étaient sur le même switch**.
Le plan d'adressage ne change pas.

Deux variantes, selon qu'il y a Internet ou non :

| Variante | Pont | Internet | `apt` |
|---|---|---|---|
| **B1 — sans Internet** | IP `192.168.137.1/24` posée à la main | non | clé USB (`scripts/97-paquets-hors-ligne.sh`) |
| **B2 — avec Internet** | partage de connexion Windows (ICS) vers le pont | oui | direct |

> Le partage de connexion de Windows utilise **par défaut** le sous-réseau
> `192.168.137.0/24` avec la passerelle `192.168.137.1` — c'est exactement notre plan.
> Aucun conflit d'adressage, aucun document à réécrire.

> ⚠️ Limite connue : un pont logiciel Windows peut décrocher quand une carte passe en veille.
> Désactiver la veille des cartes Ethernet : Gestionnaire de périphériques → carte →
> Propriétés → Gestion de l'alimentation → décocher « Autoriser l'ordinateur à éteindre… ».

### Schéma C — réseau isolé A ↔ B, PC Windows hors du labo

Un seul câble utilisé, le PC Windows ne participe plus au réseau. C'est le plan de secours
du §4 : utile si le pont refuse de fonctionner, mais on perd les tests clients depuis Windows.

---

## 3. Configuration du schéma B (ton cas)

### 3.1 Côté Windows — créer le pont (10 minutes)

**a. Brancher d'abord les câbles.** Un câble entre le PC Windows et **Linux A**, l'autre entre
le PC Windows et **Linux B**. N'importe quelle prise RJ45 de chaque côté : les cartes récentes
gèrent le croisement automatiquement (auto-MDIX), les deux câbles peuvent être droits.

**b. Vérifier que les deux cartes voient le lien** avant de toucher au pont :

```powershell
# PowerShell, en admin
Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.3*"} |
    Format-Table Name, InterfaceDescription, Status, LinkSpeed
```

Attendu : **deux** lignes Ethernet en `Up` (ou `Disconnected` si le Linux d'en face est
éteint — allume-le). Si une ligne reste `Disconnected` avec un câble branché : câble ou prise
morte, on change de câble avant d'aller plus loin.

**c. Créer le pont :**

1. `Win + R` → `ncpa.cpl` (Panneau de configuration → Centre réseau → Modifier les
   paramètres de la carte).
2. Sélectionner **les deux cartes Ethernet** (`Ctrl` + clic).
3. Clic droit → **Créer un pont** (*Bridge Connections*).
4. Windows crée « Pont réseau » ; renomme-le `Pont labo`.
   Les deux cartes physiques passent en « Non connecté » : **c'est normal**, elles sont
   membres du pont et n'ont plus d'adresse propre.

**d. Poser l'adresse du pont :**

```powershell
# Panneau → clic droit "Pont labo" → Propriétés → IPv4 → Propriétés
#   Adresse IP      : 192.168.137.1
#   Masque          : 255.255.255.0
#   Passerelle      : (vide en B1 ; voir B2 pour Internet)
#   DNS             : 192.168.137.10   (après le TP4)
```

Équivalent en ligne de commande (adapter le nom `Pont labo`) :

```powershell
netsh interface ipv4 set address name="Pont labo" static 192.168.137.1 255.255.255.0
netsh interface ipv4 set dnsservers name="Pont labo" static 192.168.137.10 primary
```

**e. Vérifier :**

```powershell
ipconfig /all | Select-String -Pattern "Pont labo" -Context 0,8
# → IPv4 : 192.168.137.1, masque 255.255.255.0
ping 192.168.137.10
ping 192.168.137.20
```

Le `ping` peut échouer **avant** que les Linux soient configurés (§3.3 et §3.4) : c'est normal.
Refais le test après.

### 3.2 Côté Windows — ajouter Internet (variante B2, facultative)

Si une carte Wi-Fi (ou une autre connexion) donne Internet sur le PC Windows :

1. `ncpa.cpl` → clic droit sur la connexion **Internet** (Wi-Fi) → Propriétés → onglet
   **Partage**.
2. Cocher **« Autoriser d'autres utilisateurs du réseau à se connecter via cette connexion »**.
3. Liste déroulante : choisir **`Pont labo`**. Valider.
4. Windows repose automatiquement `192.168.137.1/24` sur le pont et ouvre un mini-DHCP +
   un relais DNS sur `.1`. Nos IP fixes `.10`/`.20` ne sont pas touchées.

Vérification immédiate, depuis un Linux :

```bash
curl -sI --max-time 8 https://deb.debian.org | head -1    # HTTP/2 200
```

> ⚠️ Le partage Windows **filtre l'ICMP** : `ping 192.168.137.1` et `ping 8.8.8.8` peuvent
> échouer alors que tout fonctionne. Le test valable est **TCP** (`curl`), pas `ping`.
>
> ⚠️ Ne mets **pas** de passerelle `.1` dans la config Linux en B1 : il n'y a rien derrière,
> et chaque tentative sortante attendrait un délai d'expiration.

### 3.3 Sur Linux A (SRV1)

> ⚠️ **Avant tout** : si le profil Wi-Fi porte encore `192.168.137.10/24` (c'est notre cas),
> il faut **le remettre en DHCP**, sinon la même IP se retrouve sur deux interfaces et rien
> ne fonctionne de façon prévisible.
>
> ```bash
> UUID="$(nmcli -g UUID,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1)"
> nmcli connection modify "$UUID" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
> ```

```bash
# 0. Le lien physique doit être vu AVANT toute configuration
cat /sys/class/net/enp1s0/carrier     # 1 = câble détecté ; 0 = rien à l'autre bout
ip -br link show enp1s0               # doit être UP

# 1. Profil dédié au câble (idempotent)
sudo nmcli connection delete tp-cable 2>/dev/null || true
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.10/24 \
     ipv4.never-default yes \
     ipv4.dns "127.0.0.1" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no
sudo nmcli connection up tp-cable

# 2. Vérifications
ip -4 a show enp1s0                  # 192.168.137.10/24
ip neigh show dev enp1s0             # une MAC en face = le pont est joignable
hostname -f                          # srv1.ofppt.local
```

En **B2** (Internet par le pont), remplacer les deux lignes de route/DNS par :

```bash
sudo nmcli connection modify tp-cable ipv4.never-default no
sudo nmcli connection modify tp-cable ipv4.gateway 192.168.137.1
sudo nmcli connection modify tp-cable ipv4.dns "127.0.0.1,192.168.137.1"
sudo nmcli connection up tp-cable
```

> `connection.autoconnect no` : le profil ne se lève pas au démarrage, pour ne pas perturber
> la machine en dehors du TP. On le monte à la main : `sudo nmcli connection up tp-cable`.

### 3.4 Sur Linux B (SRV2)

> Même précaution qu'en §3.3 : remettre le profil Wi-Fi en DHCP s'il porte encore
> `192.168.137.20/24`.

```bash
cat /sys/class/net/enp1s0/carrier     # 1

sudo nmcli connection delete tp-cable 2>/dev/null || true
sudo nmcli connection add type ethernet ifname enp1s0 con-name tp-cable \
     ipv4.method manual \
     ipv4.addresses 192.168.137.20/24 \
     ipv4.never-default yes \
     ipv4.dns "192.168.137.10" \
     ipv4.dns-search "ofppt.local" \
     connection.autoconnect no
sudo nmcli connection up tp-cable

ip -4 a show enp1s0                  # 192.168.137.20/24
ip neigh show dev enp1s0             # MAC de .1
```

En **B2** : mêmes trois `nmcli connection modify` que pour A (passerelle `.1`, DNS
`192.168.137.10,192.168.137.1`).

### 3.5 Vérifier le pont dans les deux sens

```bash
# sur A
ping -c2 192.168.137.20
ping -c2 192.168.137.1
ip neigh show dev enp1s0      # .1 et .20 doivent avoir une MAC

# sur B
ping -c2 192.168.137.10
```

Si A ne joint pas B mais que les deux joignent `.1`, le pont est en place et le problème est
ailleurs (pare-feu Linux, profil NetworkManager non appliqué) :

```bash
sudo ufw status                 # sur A et B : doit laisser passer 53, 80, 443, 21, 445, 2049
ip -4 a ; ip r                  # l'IP est-elle sur enp1s0 (et pas restée sur wlp2s0) ?
sudo journalctl -u NetworkManager -n 30 --no-pager
```

Puis le contrôle officiel de la phase 1 :

```bash
bash 00-verif-reseau.sh .10        # sur A  → mode hotspot (passerelle .1 présente)
bash 00-verif-reseau.sh .20        # sur B
# en B1 (pas de passerelle) : ajouter --isole
# attendu : PHASE 1 VALIDÉE — N contrôles OK
```

### 3.6 Le Wi-Fi de la machine : à éteindre ou à laisser ?

| Situation | Action |
|---|---|
| **B1** (pas d'Internet dans le labo) | couper le Wi-Fi du Linux (`nmcli radio wifi off`) : il ne sert à rien et peut créer une 2ᵉ route par défaut |
| **B2** (Internet par le pont Windows) | couper aussi le Wi-Fi du Linux : Internet arrive par le câble |
| Tu veux garder Internet **par le Wi-Fi de la salle** sur ton Linux | garder le Wi-Fi **et** `ipv4.never-default yes` sur `tp-cable` → mode `double` au script |

Le script `00-verif-reseau.sh` distingue les trois cas tout seul :
`hotspot` (passerelle `.1`), `double` (Internet par une autre interface, labo sans passerelle),
`isole` (aucune passerelle).

---

## 4. Plan de secours : réseau isolé A ↔ B (schéma C)

À utiliser si le pont Windows ne fonctionne pas (pilote qui refuse le mode promiscuité,
carte USB fantaisiste…). Un seul câble sert, **le PC Windows sort du réseau du labo**.

```
   Linux A  ═════════ câble 1 ═════════  Linux B
   192.168.137.10                        192.168.137.20

   (le câble 2 reste libre)
```

### 4.1 Ce qui ne change PAS

| Élément | Reste identique |
|---|---|
| Plan d'adressage | `192.168.137.0/24`, A=`.10`, B=`.20`, pc01=`.1` |
| Zones Bind, enregistrements A/CNAME/MX/PTR | **aucune modification** |
| Vhosts Apache, certificat, pages | aucune modification |
| vsftpd, Samba, exports NFS | aucune modification |
| `/etc/hosts` sur A et B | aucune modification |

### 4.2 Ce qui change

| Élément | Avant (hotspot) | Après (câble isolé) |
|---|---|---|
| Interface | `wlp2s0` | `enp1s0` |
| Passerelle | `192.168.137.1` | **aucune** (`ipv4.never-default yes`) |
| Internet / `apt` | via le hotspot | **non disponible** → clé USB |
| `forwarders` de Bind | `192.168.137.1` | à commenter (sinon 5 s d'attente) |
| Tests clients Apache/FTP/Samba | depuis Windows | **depuis Linux A** (`curl`, `smbclient`, `showmount`) |
| TP3 (DHCP) | VM sur PC01 | inchangé : réseau host-only, aucune dépendance |

### 4.3 Configuration

Identique au §3.3 et §3.4 avec `ipv4.never-default yes` (déjà le cas par défaut dans les
commandes données), puis :

```bash
bash 00-verif-reseau.sh .10 --isole
bash 00-verif-reseau.sh .20 --isole
# attendu : PHASE 1 VALIDÉE — N contrôles OK (mode isole)
```

### 4.4 Bind sans Internet

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

```bash
sudo named-checkconf && sudo systemctl restart bind9
dig @127.0.0.1 www.ntic.local +short     # répond toujours
dig @127.0.0.1 github.com +short         # échoue : NORMAL, pas d'Internet
```

---

## 5. Retour à la normale après le TP

Côté Windows : `ncpa.cpl` → clic droit sur **`Pont labo`** → **Supprimer le pont**. Les deux
cartes Ethernet redeviennent indépendantes (et repassent en DHCP si tu les utilises ailleurs).

Côté Linux :

```bash
sudo nmcli connection delete tp-cable
sudo nmcli radio wifi on          # remettre le Wi-Fi si tu l'avais coupé
```

Pour tout le reste (hostname, `systemd-resolved`, `bind9`, `/etc/hosts`, profils Wi-Fi en DHCP) :

```bash
sudo bash 98-retour-a-la-normale.sh
```

---

## 6. Ce qu'il faut dire dans le rapport

Trois phrases, et elles montrent que vous avez compris le montage :

> « Le laboratoire utilise un réseau privé `192.168.137.0/24` en Ethernet. Le PC client
> Windows, qui possède deux interfaces, est configuré en **pont logiciel** : il relie les deux
> serveurs Linux sur un même segment sans switch physique, et porte l'adresse
> `192.168.137.1` du plan d'adressage.
> La connexion Internet (lorsqu'elle est disponible) est partagée vers ce pont, ce qui place
> automatiquement le réseau du laboratoire dans le sous-réseau `192.168.137.0/24` ; en son
> absence, les paquets sont installés hors ligne depuis un dépôt local.
> Le partage de connexion Windows filtrant l'ICMP, les tests de connectivité ont été validés
> en TCP (`curl`, `smbclient`, `dig`) plutôt qu'en `ping`. »

C'est exactement le genre de justification qui fait la différence entre « on a suivi la
feuille » et « on a compris ce qu'on a monté ».

---

## 7. Variante « deux machines seulement »

Question fréquente : et si on n'a que **deux** PC ? Réponse courte : **oui, et c'est même
plus simple** — un seul câble, aucun pont, aucun switch, aucun partage de connexion.

```
   Machine 1 ═══════════ câble ═══════════  Machine 2
   192.168.137.10                          192.168.137.20
   (SRV1 : DNS + DHCP en VM)               (SRV2 : Apache + FTP + Samba + NFS)
```

### 7.1 Deux Linux — ✅ tout le TP est faisable

C'est la meilleure configuration à deux machines : **les six TP sont réalisables**, puisque
tous les services demandés sont des services Linux (Bind, `isc-dhcp-server`, Apache, vsftpd,
Samba, NFS).

- Mise en réseau : §3.3 et §3.4 de ce document, avec `ipv4.never-default yes` (pas de `.1`).
  Le second câble reste en secours.
- Le `ping` **fonctionne** ici (aucun pare-feu Windows sur le chemin) : plus de faux échecs.
- Il manque seulement le **client Windows** : on le remplace par une **VM Windows dans
  VirtualBox**, carte réseau en **mode « Accès par pont » sur `enp1s0`**, IP `192.168.137.1`
  ou DHCP. Les captures d'écran demandées par l'énoncé restent donc produites.

Ce qui change dans les rapports : le PC01 physique devient une VM ; le TP3 (DHCP) se fait
dans une **autre** VM host-only, exactement comme prévu au doc 04.

### 7.2 Deux Windows — ⚠️ techniquement oui, pédagogiquement non

Le réseau fonctionne (deux IP fixes, partages SMB natifs), mais le module est **«
administration d'un réseau sous Linux »** : les rapports doivent montrer `named.conf`,
`apache2.conf`, `smb.conf`, `/etc/exports`, `ufw`, AppArmor. Windows ne fournit ni Bind, ni
vsftpd, ni exports NFS (le rôle serveur NFS n'existe pas sur un Windows client).

Ce que ça permet quand même : ping, partages SMB, client FTP, et le **TP3 (DHCP) en VM** —
c'est-à-dire les TP « client », pas les TP « serveur ». À éviter, sauf si les deux Linux
sont réellement indisponibles le jour de l'évaluation.

### 7.3 Récapitulatif

| Configuration | TP serveurs (4,5,6,8,9) | TP3 DHCP | Client Windows | Câblage |
|---|---|---|---|---|
| 2 Linux + 1 Windows (**schéma B**) | ✅ | ✅ | ✅ natif | 2 câbles + pont |
| **2 Linux** + VM Windows en pont | ✅ | ✅ | ✅ en VM | **1 câble** |
| 2 Windows | ❌ | ✅ en VM | ✅ natif | 1 câble |

**Ordre de préférence : 2 Linux + 1 Windows › 2 Linux + VM Windows › 2 Windows.**
