# 03 — TP8 : NFS (SRV2 exporte, SRV1 monte)

**TP à faire à deux** — c'est le seul qui exige deux Linux.

- **Serveur NFS :** SRV2 (Linux B) — `192.168.137.20`
- **Client NFS :** SRV1 (Linux A) — `192.168.137.10`
- **Durée :** ~45 min. **À faire après** le TP4 (le DNS n'est pas indispensable ici, mais
  autant utiliser `srv2.ofppt.local` dans `/etc/exports` et `fstab`).

> ⚠️ Commandes écrites pour **CentOS 7**. Sous **Ubuntu 24.04** : `07_UBUNTU-24.04.md` §8
> (`nfs-kernel-server`, `nfs-common`, `ufw`) ; `/etc/exports` et les tests sont identiques.


---

## 0. À lire avant de commencer : deux incohérences de l'énoncé

1. L'étape 3 demande de créer **deux** répertoires (`/home/projet`, `/home/data`) mais l'étape
   4 en partage **quatre** (`/home/projet`, `/home/data`, `/home/tri`, `/home/ntic`). On crée
   les quatre et on le signale.
2. Le TP8 est imprimé **deux fois** dans le PDF (`TP8_NFS.pdf` et `TP8_NFS (1).pdf` sont
   identiques à l'octet près). Une seule série de réponses suffit.

Et une règle de sécurité : on monte sous **`/mnt/...`**, jamais sous `/home/...`. Monter un
partage NFS sur `/home` masquerait les répertoires personnels locaux du client — incident
classique et pénible à réparer.

---

## 1. Question 1 du TP : « Quel est le rôle d'un service NFS ? »

À rédiger dans le rapport (3-4 lignes, pas de copier-coller de Wikipédia) :

> NFS (Network File System) permet à une machine cliente de monter un répertoire situé sur
> une autre machine et de l'utiliser comme s'il était local : même arborescence, mêmes
> droits, mêmes appels système. Contrairement à FTP ou Samba, il n'y a pas de « transfert de
> fichier » : l'accès est transparent au niveau du système de fichiers, ce qui le destine aux
> réseaux UNIX/Linux. Il repose sur RPC (port 2049 pour NFS, `rpcbind` pour la découverte)
> et n'a **aucune notion de session ni de mot de passe** : l'authentification est uniquement
> basée sur l'UID/GID du client, d'où l'importance de `root_squash`.

---

## 2. Serveur : SRV2 (Linux B)

### 2.1 Paquet (TP8 §2)

```bash
rpm -qa | grep -E 'nfs-utils|rpcbind'
sudo yum install -y nfs-utils
sudo systemctl enable --now rpcbind nfs-server
```

### 2.2 Arborescence (TP8 §3 + les deux répertoires manquants)

```bash
sudo mkdir -p /home/projet /home/data /home/tri /home/ntic

# Utilisateur khadija, propriétaire de /home/tri (TP8 §4c)
sudo useradd -m khadija 2>/dev/null || true
echo 'khadija:Ofppt2026!' | sudo chpasswd

# Propriétaires et droits
sudo chown root:root       /home/projet && sudo chmod 755 /home/projet
sudo chown root:root       /home/data   && sudo chmod 755 /home/data
sudo chown khadija:khadija /home/tri    && sudo chmod 755 /home/tri
sudo chown root:root       /home/ntic   && sudo chmod 755 /home/ntic

# Quelques fichiers témoins
echo "projet" | sudo tee /home/projet/README.txt
echo "data"   | sudo tee /home/data/README.txt
```

### 2.3 `/etc/exports` (TP8 §4)

```bash
sudo cp /etc/exports /etc/exports.orig
sudo tee /etc/exports >/dev/null <<'EOF'
# /home/projet : tout le monde, LECTURE SEULE                    (TP8 §4a)
/home/projet    *(ro,sync)

# /home/data   : SRV1 en lecture/écriture                        (TP8 §4b)
/home/data      192.168.137.10(rw,sync)

# /home/tri    : SRV1 en lecture/écriture, via l'utilisateur khadija (TP8 §4c)
#                -> c'est l'UID de khadija qui compte (voir §2.6)
/home/tri       192.168.137.10(rw,sync)

# /home/ntic   : tout le monde en lecture/écriture, "via root"   (TP8 §4d)
#                -> no_root_squash : le root du client reste root
/home/ntic      *(rw,sync,no_root_squash)
EOF
```

Options expliquées (à mettre dans le rapport) :

| Option | Effet |
|---|---|
| `ro` / `rw` | lecture seule / lecture-écriture |
| `sync` | le serveur confirme l'écriture une fois sur disque (sûr, plus lent) |
| `root_squash` (défaut) | root du client devient `nobody` côté serveur |
| `no_root_squash` | root du client reste root côté serveur — **dangereux**, seulement en labo |
| `*(...)` | n'importe quel client ; `192.168.137.10(...)` un client précis |

### 2.4 SELinux et pare-feu

Le piège n°1 de NFS sous CentOS : sans le booléen SELinux, le montage échoue en
`access denied by server while mounting`.

```bash
sudo setsebool -P nfs_export_all_ro on
sudo setsebool -P nfs_export_all_rw on

sudo firewall-cmd --permanent --add-service=nfs \
                 --add-service=mountd --add-service=rpc-bind
sudo firewall-cmd --reload
```

### 2.5 Export et vérification (TP8 §5-6-7)

```bash
# Recharger la table d'exports sans redémarrer
sudo exportfs -rav
# attendu : exporting *:/home/projet  exporting 192.168.137.10:/home/data ...

# Table d'exports active
sudo exportfs -v

# Vu depuis le serveur lui-même
showmount -e localhost
showmount -e 192.168.137.20
```

Attendu :

```
Export list for 192.168.137.20:
/home/ntic   *
/home/tri    192.168.137.10
/home/data   192.168.137.10
/home/projet *
```

### 2.6 Le point délicat : « via l'utilisateur khadija » (§4c)

NFS ne transporte pas d'identifiant : il transporte un **UID numérique**. Pour que `khadija`
puisse écrire dans `/home/tri` depuis SRV1, il faut que l'UID de `khadija` soit **le même sur
les deux machines**. On le relève :

```bash
id khadija          # ex. uid=1001(khadija) gid=1001(khadija)
```

Sur SRV1, il faudra créer `khadija` avec **le même UID** (voir §3.4). C'est la réponse à la
question 9 « vérifier les propriétaires des nouveaux fichiers » : un fichier créé par
`khadija` sur le client apparaît avec son UID côté serveur, et si les UID diffèrent on voit
un numéro à la place du nom (`ls -n`) — c'est exactement ce qu'il faut montrer dans le
rapport.

---

## 3. Client : SRV1 (Linux A)

### 3.1 Paquets

```bash
sudo yum install -y nfs-utils
sudo systemctl enable --now rpcbind
```

### 3.2 Voir les exports (TP8 §7)

```bash
showmount -e 192.168.137.20
```

### 3.3 Points de montage et montage (TP8 §8)

```bash
sudo mkdir -p /mnt/{projet,data,tri,ntic}

sudo mount -t nfs 192.168.137.20:/home/projet /mnt/projet
sudo mount -t nfs 192.168.137.20:/home/data   /mnt/data
sudo mount -t nfs 192.168.137.20:/home/tri    /mnt/tri
sudo mount -t nfs 192.168.137.20:/home/ntic   /mnt/ntic

df -hT | grep nfs                # les 4 montages
mount | grep nfs
```

Si vous préférez les noms : `srv2.ofppt.local:/home/data` (le DNS du doc 01 est déjà en
place).

### 3.4 Créer khadija avec le même UID (pour le test du §4c)

```bash
# remplacer 1001 par l'UID relevé sur SRV2
sudo useradd -u 1001 -m khadija
sudo passwd khadija
```

### 3.5 Tests lecture / écriture (TP8 §9)

```bash
# --- /mnt/projet : lecture seule pour tout le monde ---
cat /mnt/projet/README.txt                    # OK
touch /mnt/projet/test.txt                    # DOIT échouer : "Read-only file system"

# --- /mnt/data : lecture-écriture pour SRV1 ---
echo "ecrit depuis srv1" | sudo tee /mnt/data/depuis_srv1.txt
sudo rm /mnt/data/depuis_srv1.txt

# --- /mnt/tri : écriture avec khadija (même UID des deux côtés) ---
su - khadija -c 'echo "fichier de khadija" > /mnt/tri/khadija.txt'
ls -ln /mnt/tri                    # le fichier doit appartenir à l'UID de khadija
ls -l  /mnt/tri                    # ... et s'afficher avec le bon nom

# --- /mnt/ntic : root du client reste root (no_root_squash) ---
sudo touch /mnt/ntic/fichier_root.txt
ls -ln /mnt/ntic                   # UID 0 (et non 65534/nobody)
```

### 3.6 Test de synchronisation (TP8 §9)

```bash
# Terminal 1 — sur SRV2 : observer en direct
sudo tcpdump -ni any port 2049 &
watch -n1 'ls -ln /home/data'

# Terminal 2 — sur SRV1 : écrire
for i in 1 2 3; do echo "ligne $i" | sudo tee -a /mnt/data/sync.txt; sleep 1; done
```

Le fichier apparaît **immédiatement** côté serveur : NFS n'est pas de la synchronisation,
c'est un accès distant temps réel. Conclusion à écrire dans le rapport : « il n'y a pas de
délai de synchronisation, les deux machines voient le même inode ; c'est justement la
différence avec `rsync` ou un dossier partagé cloud ».

### 3.7 Montage automatique au démarrage (TP8 §10)

**a. Dans quel fichier ?** → `/etc/fstab`.

**b. Configuration :**

```bash
sudo cp /etc/fstab /etc/fstab.orig
sudo tee -a /etc/fstab >/dev/null <<'EOF'
# TP8 - montages NFS automatiques
srv2.ofppt.local:/home/projet  /mnt/projet  nfs  defaults,_netdev,ro  0 0
srv2.ofppt.local:/home/data    /mnt/data    nfs  defaults,_netdev     0 0
srv2.ofppt.local:/home/tri     /mnt/tri     nfs  defaults,_netdev     0 0
srv2.ofppt.local:/home/ntic    /mnt/ntic    nfs  defaults,_netdev     0 0
EOF

# Test à chaud SANS redémarrer
sudo umount /mnt/{projet,data,tri,ntic}
sudo mount -a
df -hT | grep nfs
```

`_netdev` = « ne monte qu'une fois le réseau disponible » ; sans ça, une machine qui démarre
sans réseau peut bloquer au boot. Alternative plus robuste : `x-systemd.automount` +
`x-systemd.idle-timeout=60`, à mentionner en remarque.

**Danger à connaître** : une ligne `fstab` NFS fausse peut empêcher le démarrage complet.
En cas de doute, tester avec `sudo mount -a` avant de redémarrer, et garder une session root
ouverte.

### 3.8 Nettoyage (à la fin du TP)

```bash
sudo umount /mnt/{projet,data,tri,ntic}
sudo sed -i '/TP8 - montages NFS/,/ntic/d' /etc/fstab   # ou restaurer /etc/fstab.orig
```

---

## 4. Tableau récapitulatif à recopier dans `TP8.doc`

| Partage | Client autorisé | Droits | Option clé | Ce qui doit se passer |
|---|---|---|---|---|
| `/home/projet` | tout le monde | ro | `ro` | lecture OK, écriture refusée (`Read-only file system`) |
| `/home/data` | 192.168.137.10 | rw | `rw` | lecture + écriture OK |
| `/home/tri` | 192.168.137.10 | rw (khadija) | UID identiques | `khadija` écrit, fichiers à son nom |
| `/home/ntic` | tout le monde | rw (root) | `no_root_squash` | root écrit, UID 0 conservé |

## 5. Captures à prévoir

- `exportfs -v` et `showmount -e` côté serveur.
- `df -hT | grep nfs` côté client (les 4 montages).
- Le refus d'écriture sur `/mnt/projet`.
- `ls -ln /mnt/ntic` montrant l'UID 0 (preuve du `no_root_squash`).
- `ls -ln /mnt/tri` avec le fichier de `khadija`.
- `cat /etc/fstab` + `mount -a` sans erreur.

## 6. Dépannage NFS

| Symptôme | Cause | Correctif |
|---|---|---|
| `access denied by server while mounting` | SELinux | `setsebool -P nfs_export_all_rw on` |
| `mount.nfs: Connection timed out` | pare-feu | ouvrir `nfs mountd rpc-bind` |
| `showmount -e` vide | service arrêté | `systemctl status nfs-server`, `exportfs -rav` |
| Écriture refusée pour `khadija` | UID différents | `useradd -u <uid_de_srv2> khadija` |
| Fichiers en `nobody` | `root_squash` sur `/home/ntic` | ajouter `no_root_squash` |
| Démarrage bloqué après ajout dans `fstab` | réseau pas prêt | `_netdev`, ou démarrer en rescue et corriger `/etc/fstab` |
| Les montages disparaissent après `reboot` | pas de ligne `fstab` | §3.7 |
