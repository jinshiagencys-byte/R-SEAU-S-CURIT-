# TP Administration Réseau — dossier de travail

Corrigés et fiches d'exécution pour les TP DHCP / DNS / Apache / FTP / NFS / Samba
(OFPPT Oujda — module *Administration d'un réseau sous Linux*).

> Les énoncés sont rédigés pour **CentOS 7**. Le laboratoire réel est sous **Ubuntu 24.04**
> (et Windows 11 pour le poste client) : le document `07_UBUNTU-24.04.md` donne la version
> exécutable de chaque manipulation et le tableau de correspondance CentOS ↔ Ubuntu à
> joindre aux rapports.

## Par où commencer

1. **`09_PLAYBOOK_RELAIS.md`** — **le document à suivre pendant le TP** : 61 étapes
   numérotées, un seul porteur du bâton à la fois, avec le message exact à envoyer pour
   passer à l'étape suivante. Commence ici, tu n'as pas besoin de lire le reste.
2. **`08_QUI_FAIT_QUOI.md`** — la vue par phases (parallélisme, durées, portes de sortie).
3. **`00_PLAN_ET_RESEAU.md`** — à lire en premier, à faire ensemble (30 min).
   Architecture du labo, plan d'adressage, répartition, règles de survie.
4. **`07_UBUNTU-24.04.md`** — **obligatoire si ta machine n'est pas CentOS 7** : c'est la
   version exécutable (bind9, isc-dhcp-server, apache2, ufw, AppArmor, systemd-resolved) et
   le tableau de correspondance CentOS ↔ Ubuntu pour les rapports.
5. Puis chaque machine prend son document :

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
| `09_PLAYBOOK_RELAIS.md` | tous | **61 étapes numérotées, un porteur du bâton à la fois, avec les messages de passage** |
| `scripts/00-verif-reseau.sh` | A et B | contrôle de la phase 1 : IP, passerelle, Internet, ping croisé, `/etc/hosts` |
| `scripts/01-verif-dns.sh` | A | contrôle des 29 enregistrements du TP4 (A, CNAME, MX, AAAA, NS, PTR, SOA, SRV) |
| `scripts/90-collecte.sh` | tous | rapport complet prêt à coller dans une Issue GitHub (réseau, services, ports, `dig`, journaux) |
| `scripts/97-paquets-hors-ligne.sh` | A (à la maison) | télécharge tous les `.deb` du TP pour installer **sans Internet** en salle |
| `scripts/98-retour-a-la-normale.sh` | A et B | remet le PC en état normal : DHCP, `systemd-resolved`, hostname, `/etc/hosts` |

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
