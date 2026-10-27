# TP Administration Réseau — dossier de travail

Corrigés et fiches d'exécution pour les TP DHCP / DNS / Apache / FTP / NFS / Samba
(OFPPT Oujda — module *Administration d'un réseau sous Linux*).

> Les énoncés sont rédigés pour **CentOS 7**. Le laboratoire réel est sous **Ubuntu 24.04**
> (et Windows 11 pour le poste client) : le document `07_UBUNTU-24.04.md` donne la version
> exécutable de chaque manipulation et le tableau de correspondance CentOS ↔ Ubuntu à
> joindre aux rapports.

## Par où commencer

1. **`08_QUI_FAIT_QUOI.md`** — le chef d'orchestre : 8 phases, qui fait quoi, qui bloque
   qui, et la porte de sortie de chaque phase. **Commence par ça.**
2. **`00_PLAN_ET_RESEAU.md`** — à lire en premier, à faire ensemble (30 min).
   Architecture du labo, plan d'adressage, répartition, règles de survie.
3. **`07_UBUNTU-24.04.md`** — **obligatoire si ta machine n'est pas CentOS 7** : c'est la
   version exécutable (bind9, isc-dhcp-server, apache2, ufw, AppArmor, systemd-resolved) et
   le tableau de correspondance CentOS ↔ Ubuntu pour les rapports.
4. Puis chaque machine prend son document :

| Document | Qui | Contenu |
|---|---|---|
| `00_PLAN_ET_RESEAU.md` | tous | réseau, IP, adressage, livrables, dépannage global |
| `01_LINUX-A_SRV1_DNS.md` | Linux A | TP4 complet + zones du TP5/TP6 (logique + rapport) |
| `02_LINUX-B_SRV2_APACHE-FTP-SAMBA.md` | Linux B | TP5 (Apache+SSL), TP6 (FTP), TP9 (Samba), DNS esclave |
| `03_TP8_NFS.md` | les deux | TP8 (SRV2 exporte, SRV1 monte) |
| `04_WINDOWS_PC01_TP3_ET_TESTS.md` | Windows | TP3 en VM, tests clients, captures, rapports |
| `05_CHECKLIST_RENDU.md` | tous | planning, checklist, incohérences, questions théoriques |
| `06_MESSAGES_EQUIPE.md` | — | messages prêts à copier-coller |
| `07_UBUNTU-24.04.md` | Linux A **et** Linux B | **commandes et fichiers de conf réels pour Ubuntu** (§12 = runbook complet de SRV2) |
| `08_QUI_FAIT_QUOI.md` | tous | **ordre d'exécution en 8 phases, par machine, avec les portes de sortie** |

## L'architecture en une image

```
              PC01 Windows 192.168.137.1  (hotspot + client + TP3 en VM)
                     │
        ┌────────────┴────────────┐
   SRV1 Linux A              SRV2 Linux B
   192.168.137.10            192.168.137.20
   DNS maître (Bind)         Apache · FTP · Samba · NFS · DNS esclave
```

Le seul TP qui sort du hotspot : **TP3 (DHCP)**, fait dans deux VM VirtualBox sur un réseau
host-only isolé — explication dans le document 04.

## Règle d'or

Chaque question du rapport = le numéro, la commande, **la sortie réelle**, une phrase
d'interprétation. Les documents listent les écarts assumés par rapport aux énoncés : ils
doivent apparaître dans les rapports, c'est ce qui est noté.
