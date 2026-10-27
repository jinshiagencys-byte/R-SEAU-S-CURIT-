# Administration d'un réseau sous Linux — TP

Dossier de travail pour les TP **DHCP · DNS · Apache · FTP · NFS · Samba**
(OFPPT Oujda, module *Administration d'un réseau sous Linux*).

Le laboratoire est monté sur **3 machines physiques** reliées par le partage de connexion
d'un PC Windows (pas de câble, pas de routeur) :

| Machine | Système | Rôle |
|---|---|---|
| SRV1 | Ubuntu 24.04 | DNS (Bind) |
| SRV2 | Ubuntu 24.04 | Apache, FTP, Samba, NFS, DNS esclave |
| PC01 | Windows 11 | poste client, TP3 (DHCP) en machines virtuelles, rapports |

Les énoncés sont écrits pour **CentOS 7** : les documents donnent la configuration CentOS
(référence pour les rapports) **et** son équivalent Ubuntu 24.04 (version exécutée).

## Contenu

| Fichier | Description |
|---|---|
| [`TP-corriges/README.md`](TP-corriges/README.md) | index et ordre de lecture |
| `00_PLAN_ET_RESEAU.md` | architecture, plan d'adressage, mise en réseau, livrables |
| `01_LINUX-A_SRV1_DNS.md` | TP4 : serveur DNS primaire, zones, MX, transfert |
| `02_LINUX-B_SRV2_APACHE-FTP-SAMBA.md` | TP5, TP6, TP9 |
| `03_TP8_NFS.md` | TP8 : exports et montages NFS |
| `04_WINDOWS_PC01_TP3_ET_TESTS.md` | TP3 : DHCP IPv4/IPv6/relais en VM + tests clients |
| `05_CHECKLIST_RENDU.md` | planning, checklists, incohérences relevées, questions théoriques |
| `06_MESSAGES_EQUIPE.md` | répartition et messages de coordination |
| `07_UBUNTU-24.04.md` | **version exécutable Ubuntu** + tableau CentOS ↔ Ubuntu |

## Démarrage rapide

```bash
git clone https://github.com/jinshiagencys-byte/R-SEAU-S-CURIT-.git
cd R-SEAU-S-CURIT-
less TP-corriges/00_PLAN_ET_RESEAU.md
```

Puis, selon la machine : `07_UBUNTU-24.04.md` pour les serveurs Linux, `04_...` pour le
poste Windows.
