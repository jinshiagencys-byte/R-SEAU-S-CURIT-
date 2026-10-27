# 06 — Messages à envoyer aux deux autres (copier-coller)

Version courte à leur envoyer sur WhatsApp/Telegram, et les consignes précises à joindre.

---

## Message à envoyer en premier (au groupe, les deux)

> Salut, j'ai lu les 6 TP, voilà le plan pour qu'on ne se marche pas dessus.
>
> **Le réseau** : le partage de connexion du PC Windows fait le réseau du labo
> (192.168.137.0/24). Pas de câble, pas de VM. Il faut juste mettre nos IP fixes :
> - SRV1 (Linux A) : **192.168.137.10**
> - SRV2 (Linux B) : **192.168.137.20**
> - PC01 (Windows) : 192.168.137.1 (c'est déjà lui, on n'y touche pas)
>
> **Pourquoi pas de VM** : les TP 4, 5, 6, 8 et 9 se font très bien en direct. Le seul qui
> exige une VM, c'est le TP3 (DHCP) : Windows fait déjà DHCP sur le hotspot, donc si on
> installe un serveur DHCP sur le même réseau, les deux se marchent dessus. Le TP3 se fera
> dans 2 VM sur le PC Windows, sur un réseau isolé.
>
> **Ordre** : DNS d'abord (dès qu'il marche, Apache/FTP/Samba se testent par nom), ensuite
> le reste. Le TP3 est indépendant, on peut le faire en parallèle.
>
> J'ai préparé un doc par machine avec les commandes exactes, dans l'ordre, et les sorties
> attendues. Vous n'avez qu'à suivre et faire les captures.
>
> **Un piège à ne pas rater** : les TP sont écrits pour CentOS 7, or mes machines sont sous
> Ubuntu 24.04. Les paquets, les chemins de conf et le pare-feu changent (apt au lieu de
> yum, bind9 au lieu de bind, ufw au lieu de firewalld, AppArmor au lieu de SELinux). J'ai
> préparé une version Ubuntu complète, avec le tableau de correspondance à mettre dans les
> rapports.
>
> **Envoie-moi ton `cat /etc/os-release`** pour que je te dise quel doc utiliser.

---

## Pour Linux B (SRV2)

> Tu prends **SRV2** = 192.168.137.20. Ton doc : `02_LINUX-B_SRV2_APACHE-FTP-SAMBA.md`.
>
> Ce que tu as à faire, dans l'ordre :
> 1. Réseau + nom `srv2.ofppt.local` (doc 00 §5.2, puis doc 02 §0). Vérifie avec
>    `dig www.ntic.local +short` → ça doit renvoyer 192.168.137.20 (c'est mon serveur DNS,
>    il faut que je l'aie fini, sinon attends 20 min).
> 2. **TP5 – Apache** : 2 sites `www.tri.local` et `www.ntic.local` sur la même IP, puis
>    SSL + redirection http→https sur ntic.
> 3. **TP6 – FTP** : vsftpd. ⚠️ Lance `script ScTP6.txt` **avant** la première commande,
>    l'énoncé l'exige. Pareil pour le TP5 (`script ScTP5.txt`).
> 4. **TP9 – Samba** : groupes recherche/controle, partage `/decouverte`, droits ro/rw.
> 5. Envoie-moi les captures au fur et à mesure : j'ai besoin de celles du TP8 (NFS) pour
>    mon rapport, et il faut que ça soit fait quand je monte tes partages.
>
> Deux trucs que l'énoncé demande et qu'il ne faut **pas** faire littéralement : ne
> désactive pas SELinux et n'arrête pas le pare-feu. Le doc donne les booléens et les
> `firewall-cmd` à la place — c'est mieux noté et ça ne flingue pas ton PC.
>
> Si tu es sous **Ubuntu** : même chose avec AppArmor et `ufw`, les commandes exactes sont
> dans `07_UBUNTU-24.04.md` §7 (le piège du partage Samba dans `/decouverte` y est).

---

## Pour le PC Windows (PC01)

> Ton doc : `04_WINDOWS_PC01_TP3_ET_TESTS.md`. Tu as deux casquettes.
>
> **1. Le TP3 (DHCP) — c'est toi qui le fais, et c'est le plus gros morceau.**
> On ne peut pas le faire sur le réseau du hotspot : ton partage de connexion fait déjà
> serveur DHCP, deux serveurs DHCP sur le même réseau = tests aléatoires. Donc :
> - installe **VirtualBox** + l'ISO **CentOS 7 Minimal** (lien dans le doc) ;
> - crée un réseau host-only `vboxnet0` en 172.19.20.2/24 avec le **DHCP de VirtualBox
>   désactivé** (étape critique) ;
> - 2 VM : `SRV-A` (le serveur DHCP) et `CLIENT` (un client Linux) ;
> - ton PC Windows sert de client Windows sur le même réseau → tu couvres les deux tests
>   demandés (Linux + Windows) avec une seule machine.
> Compte 2 à 3 h. Toutes les commandes sont dans les parties B, C et D du doc.
>
> **2. Les tests clients de tous les autres TP + les rapports.**
> Tu es le seul à pouvoir faire les captures Windows : le TP5 (les 2 sites dans le
> navigateur), le TP6 (FTP + refus de root + FileZilla), le TP9 (Samba avec hiba et wahid).
> Sans tes captures, nos TPs ne sont pas validés.
>
> ⚠️ **À faire au fur et à mesure, pas à la fin.** Si tu attends le dernier jour, on ne peut
> plus rien corriger et tout le monde perd des points.
>
> Les `.doc` : une question = le numéro, la commande, la sortie réelle, une phrase. Les
> tableaux des documents 04 (partie F.6) et 05 servent de checklist.

---

## Ce que chacun envoie aux autres, au minimum

| Depuis | Vers | Quoi |
|---|---|---|
| Linux A | B + Windows | confirmation « DNS opérationnel » (`dig www.ntic.local`) |
| Linux B | A + Windows | captures Apache/FTP/Samba + `/etc/exports` prêt |
| Windows | A + B | captures des tests clients + `ipconfig /all` du bail DHCP |
| Linux A | B | captures des 4 montages NFS (`df -hT`) |
