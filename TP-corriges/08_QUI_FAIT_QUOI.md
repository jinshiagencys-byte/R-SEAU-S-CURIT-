# 08 — Qui fait quoi, dans quel ordre (chef d'orchestre)

Réponse courte aux deux questions : **oui, tu commences** — tu es le seul point bloquant pour
les autres. Et non, Linux B et le poste Windows ne t'attendent pas pour tout : ils ont du
travail parallèle dès la minute 0.

Trois principes :

1. **Toi (Linux A) tu ouvres le bal** avec le DNS : sans lui, personne ne peut tester
   Apache/FTP/Samba par nom. C'est 45 à 60 minutes, une seule fois.
2. **Linux B pré-installe ses paquets pendant que tu fais le DNS** (ça ne dépend pas de toi).
3. **Windows n'est jamais bloqué** : le TP3 est complètement indépendant du réseau du labo,
   il peut démarrer à la minute 0 et tourner en fond.

```
        PHASE 1            PHASE 2              PHASE 3+4           PHASE 5
   ┌──────────────┐   ┌──────────────┐   ┌────────────────┐  ┌──────────────┐
   │ Réseau       │   │ A : DNS      │   │ B : Apache     │  │ B : NFS      │
   │ (les 3)      │──▶│ B : apt inst.│──▶│ B : FTP        │─▶│ A : montages │
   │ 20 min       │   │ W : TP3 (VM) │   │ B : Samba      │  │ W : captures │
   └──────────────┘   └──────────────┘   └────────────────┘  └──────────────┘
                       ▲ bloquant : A       ▲ bloquant : B          ▲ les 2
```

---

## PHASE 0 — Avant de toucher au réseau (10 min, chacun chez soi)

| Qui | Action | Résultat attendu |
|---|---|---|
| Windows | Activer le partage de connexion / point d'accès mobile. **Désactiver la mise en veille** (Paramètres → Alimentation → jamais). Noter SSID + mot de passe. | `ipconfig` → `192.168.137.1` |
| Windows | **Désactiver la mise en veille** (bis) : si le PC s'endort, le hotspot tombe et les deux Linux perdent le réseau en pleine manip. | — |
| A + B | Se connecter au Wi-Fi du hotspot. Rien d'autre. | `ip a` → une IP en `192.168.137.x` |

**Pourquoi la mise en veille est un vrai sujet** : c'est la panne la plus fréquente de ce
genre de labo. Le PC Windows s'endort, les Linux perdent la passerelle, `dig` et `apt`
échouent, et on croit que Bind est cassé.

✅ Porte de sortie : les 3 machines ping le `192.168.137.1`.

---

## PHASE 1 — Socle réseau (20 min, A et B en parallèle, Windows supervise)

| Qui | Action | Doc |
|---|---|---|
| **Linux A** | IP fixe `192.168.137.10`, hostname `srv1.ofppt.local`, `/etc/hosts`, `ping` vers B | `07` §1 |
| **Linux B** | IP fixe `192.168.137.20`, hostname `srv2.ofppt.local`, `/etc/hosts`, `ping` vers A | `07` §1 |
| Windows | Vérifier `ping 192.168.137.10` et `ping 192.168.137.20` | `00` §5.2 |

**Test de sortie obligatoire** (à faire à deux, pas chacun dans son coin) :

```bash
# sur chaque machine : vérifie IP, passerelle, Internet, ping croisé, /etc/hosts
bash scripts/00-verif-reseau.sh 192.168.137.10     # sur SRV1
bash scripts/00-verif-reseau.sh 192.168.137.20     # sur SRV2
```

Si ça échoue alors que chacun ping la passerelle : isolation client du hotspot. Couper
temporairement `sudo ufw disable` sur les deux **pour confirmer** que c'est bien le réseau,
puis le remettre.

✅ Porte de sortie : A ping B et B ping A.

---

## PHASE 2 — DNS (A seul, 45-60 min) · les deux autres avancent en parallèle

### Linux A — c'est toi, et c'est bloquant

```bash
# 1. Installer D'ABORD (apt a besoin d'Internet → ne coupe pas le résolveur avant)
sudo apt install -y bind9 bind9utils bind9-dnsutils

# 2. Configurer
#    -> 07 §3.2 (named.conf.options), §3.3 (named.conf.local), §3.4 (zones)
#       piège : les zones vont dans /etc/bind/zones/ et appartiennent à root:bind

# 3. Contrôler et démarrer
sudo named-checkconf
sudo named-checkzone ofppt.local /etc/bind/zones/ofppt.local.dir
sudo systemctl enable --now bind9
sudo ss -lntup | grep :53

# 4. Tester AVANT de toucher au résolveur (avec @127.0.0.1 explicite)
dig @127.0.0.1 srv1.ofppt.local +short
dig @127.0.0.1 www.ntic.local +short

# 5. Seulement maintenant : basculer le résolveur système (07 §3.7)
#    systemd-resolved -> off, resolv.conf -> nameserver 127.0.0.1

# 6. Contrôle automatique des 26 enregistrements
bash scripts/01-verif-dns.sh 192.168.137.10
```

✅ **Porte de sortie (à annoncer au groupe dès que c'est bon)** :

```bash
# depuis Linux B et depuis Windows :
dig @192.168.137.10 www.ntic.local +short     # → 192.168.137.20
nslookup www.tri.local 192.168.137.10         # (Windows)
```

Tant que ces deux commandes ne répondent pas, **B ne peut pas valider ses TPs par nom**. Mais
il peut tout préparer (voir ci-dessous).

### Linux B — pendant ce temps, il n'attend pas

Rien de ce qui suit n'a besoin du DNS :

```bash
sudo apt update
sudo apt install -y apache2 vsftpd samba samba-client cifs-utils \
                    nfs-kernel-server nfs-common net-tools dnsutils curl
sudo mkdir -p /var/www/html/{tri,ntic} /var/log/apache2/{tri,ntic} /etc/apache2/ssl
sudo a2enmod ssl && sudo a2dissite 000-default
sudo groupadd recherche ; sudo groupadd controle
sudo useradd -m -G recherche hiba ; sudo useradd -m -G controle wahid ; sudo useradd -m -G controle hamid
sudo smbpasswd -a hiba ; sudo smbpasswd -a wahid ; sudo smbpasswd -a hamid
sudo mkdir -p /home/{projet,data,tri,ntic} /decouverte
```

→ `07` §12, étape 0, jusqu'à la ligne `apt install`.

**Astuce s'il veut tester Apache avant que ton DNS soit prêt** — ça marche sans DNS :

```bash
# forcer le nom côté client, sans toucher au DNS
curl -s -H "Host: www.tri.local" http://192.168.137.20 | head
# ou, en local sur SRV2 :
echo "192.168.137.20 www.tri.local www.ntic.local" | sudo tee -a /etc/hosts
```

### Windows — démarre le TP3 maintenant

L'installation des 2 VM CentOS 7 prend 30 à 40 minutes de téléchargement et d'installation,
entièrement indépendantes du réseau du labo. C'est le meilleur moment pour la lancer.

→ `04` parties B et C.

---

## PHASE 3 — Apache (B, 45 min) · A rédige le TP4

| Qui | Action | Résultat attendu |
|---|---|---|
| **Linux B** | vhosts `www.tri.local` + `www.ntic.local`, `index.html`, `a2ensite`, `configtest` → `07` §5 | `curl -H "Host: www.tri.local" http://192.168.137.20` répond |
| **Linux A** | Rien à exécuter : **rédige le rapport TP4** avec les sorties déjà obtenues (c'est le moment, pas à la fin) | `TP4.doc` à 70 % |
| Windows | Suite de l'installation des VM | VM qui bootent |

Ensuite B ajoute SSL (§5.3-5.4) et vérifie la redirection :

```bash
curl -sI http://www.ntic.local | head -3     # 301 vers https
curl -sk https://www.ntic.local | grep -o 'virtual host NTIC fonctionne'
```

✅ Porte de sortie : `http://www.tri.local` et `http://www.ntic.local` s'affichent **depuis
Windows** (captures).

---

## PHASE 4 — FTP (B, 45 min) · Windows teste

| Qui | Action |
|---|---|
| **Linux B** | `script ScTP5.txt` si pas déjà fait → `vsftpd` (`07` §6), comptes, `/etc/ftpusers`, chroot |
| **Windows** | Tests `ftp` + FileZilla : refus de root, refus de ftpaccess, upload/download avec tri → `04` §F.3 |
| **Linux A** | Monte en parallèle la partie NFS **dès que B annonce `showmount -e` prêt** (phase 5) |

⚠️ Rappel qui coûte une note : `script ScTP6.txt` **avant** la première commande du TP6.

✅ Porte de sortie : captures Windows des 3 cas (root refusé, ftpaccess refusé, tri OK) +
`ScTP6.txt` non vide.

---

## PHASE 5 — Samba (B, 45 min) · Windows teste · A prépare NFS

| Qui | Action |
|---|---|
| **Linux B** | Groupes, `/decouverte`, `smb.conf`, **AppArmor** (`07` §7), `smbd` |
| **Windows** | `\\192.168.137.20\decouverte` avec wahid (rw), hiba (ro), anonyme (refus) → `04` §F.5 |
| **Linux A** | Crée `khadija` avec **le même UID** que sur SRV2 (`id khadija` sur B), prépare `/mnt/*` → `03` §3.4 |

⚠️ Le piège AppArmor : si le partage renvoie `NT_STATUS_ACCESS_DENIED` alors que `testparm`
est propre, c'est l'override `/etc/apparmor.d/local/usr.sbin.smbd` qui manque.

✅ Porte de sortie : captures rw/ro/anonyme + `testparm` + `pdbedit -L`.

---

## PHASE 6 — NFS (les deux, 30 min, à faire ensemble)

| Qui | Action | Doc |
|---|---|---|
| **Linux B** | Crée les 4 répertoires, `/etc/exports`, `exportfs -rav`, `showmount -e` | `07` §8 + `03` §2 |
| **Linux A** | Monte les 4 partages, teste ro/rw/UID, `fstab`, `mount -a` | `03` §3 |
| **Windows** | Récupère les captures de A et les met dans `TP8.doc` | — |

✅ Porte de sortie : `df -hT | grep nfs` montre 4 lignes ; écriture refusée sur `/mnt/projet`,
acceptée sur `/mnt/ntic` avec UID 0.

---

## PHASE 7 — Windows termine (2 h)

| Action | Doc |
|---|---|
| DHCPv6 + relais + logs DORA | `04` §D |
| Matrice de tests complète (16 lignes) | `04` §F.6 |
| Les 6 `.doc` + les captures numérotées | `04` §G |

---

## PHASE 8 — Rendu (30 min, tous)

`05_CHECKLIST_RENDU.md` §2 (checklist par TP) et §5 (10 minutes de relecture).

**Le seul point non négociable** : `ScTP5.txt` et `ScTP6.txt` joints et non vides.

---

## Vue condensée : ce qui tourne sur chaque machine à la fin

| | SRV1 (Linux A) | SRV2 (Linux B) | PC01 (Windows) |
|---|---|---|---|
| **Système** | Ubuntu 24.04 | Ubuntu 24.04 | Windows 11 |
| **IP** | 192.168.137.10 | 192.168.137.20 | 192.168.137.1 (hotspot) |
| **Services** | Bind 9 (maître) | apache2, vsftpd, smbd/nmbd, nfs-kernel-server, Bind 9 (esclave, bonus) | 2 VM VirtualBox (TP3) |
| **Consomme** | rien | DNS de SRV1, NFS de SRV2 (local) | DNS de SRV1, http/ftp/smb de SRV2 |
| **Produit pour le groupe** | zones DNS, `dig`, TP4 | 4 services, `ScTP5.txt`, `ScTP6.txt`, `exports` | TP3, **toutes les captures**, les `.doc` |

## Les 3 points de blocage à surveiller

1. **Le DNS de A** — bloque B pour Apache/FTP/Samba (contournable avec `/etc/hosts`, mais
   les captures doivent être faites avec le vrai DNS).
2. **`script` oublié** — ne bloque personne, mais coûte une note entière sur TP5 et TP6.
3. **Le PC Windows qui s'endort** — casse le réseau des trois, en pleine phase.

## Répartition des rapports (qui rédige quoi)

| Rapport | Rédacteur | Matière fournie par |
|---|---|---|
| `TP3.doc` | Windows | Windows (VM) |
| `TP4.doc` | **Linux A** | A |
| `TP5.doc` | Linux B | B (config) + Windows (captures navigateur) |
| `TP6.doc` | Linux B | B + Windows (captures FileZilla) |
| `TP8.doc` | **Linux A** | A (montages) + B (`exports`) |
| `TP9.doc` | Linux B | B + Windows (captures Samba) |

Chacun ajoute **son** nom sur le rapport qu'il rédige, et cite les autres dans la section
« répartition du travail » — c'est ce qui prouve le travail d'équipe.
