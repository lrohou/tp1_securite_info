# Tutoriel : Mise en place de l'infrastructure virtuelle (Ubuntu Server & Kali Linux)

*Note : Ce guide détaille les étapes génériques de configuration de l'infrastructure. Pour plus de contexte, il est possible de se référer au document [Guide d'Installation Pas-à-Pas](INSTALLATION.md).*

## Partie 1 : Création de la VM1 (Serveur cible - Ubuntu)

Cette machine a pour vocation d'héberger les services Elasticsearch, Kibana, Snort et Apache.

### Étape 1 : Téléchargement de l'image (ISO)

Avant de débuter la configuration dans VirtualBox, il est nécessaire de télécharger l'image d'installation (ISO) d'**Ubuntu Server** (version 22.04 LTS ou 24.04 LTS) depuis le site officiel d'Ubuntu.

### Étape 2 : Création de la machine dans VirtualBox

1. Ouvrir VirtualBox et cliquer sur le bouton **Nouvelle**.
2. Attribuer un nom à la machine (ex. : `VM1-Serveur-ELK`) et sélectionner le fichier ISO préalablement téléchargé.
3. Cocher l'option **"Passer l'installation sans assistance"** (Skip Unattended Installation) si celle-ci est proposée, afin de conserver un contrôle total sur le processus d'installation.

### Étape 3 : Allocation des ressources matérielles

* **Mémoire vive (RAM) :** En raison de la charge des multiples services à héberger, il est recommandé d'allouer entre **6 et 8 Go** de RAM (soit 6144 à 8192 Mo).
* **Processeurs (vCPU) :** Allouer entre **2 et 4 cœurs** de processeur.
* **Disque dur virtuel :** Créer un disque dur d'une capacité d'environ **30 Go**.

### Étape 4 : Configuration des cartes réseau

Avant de démarrer la machine, la sélectionner, cliquer sur **Configuration**, puis naviguer vers l'onglet **Réseau** :

* **Adaptateur 1 :** S'assurer que la carte est activée et que le mode d'accès est réglé sur **NAT**. Cela fournira un accès Internet nécessaire aux mises à jour.
* **Adaptateur 2 :** Activer l'interface et régler le mode d'accès sur **Réseau privé hôte** (Host-only).
  * *Note :* Sur les systèmes Linux/macOS, l'interface par défaut se nomme généralement `vboxnet0`. Sous environnement Windows, sélectionner l'option **"VirtualBox Host-Only Ethernet Adapter"**.

### Étape 5 : Installation du système d'exploitation et configuration IP

1. Démarrer la machine virtuelle et procéder à l'installation standard d'Ubuntu Server.
2. Une fois l'installation achevée, configurer l'adresse IP fixe (`192.168.56.101/24`) sur l'interface `enp0s8`. Pour ce faire, éditer le fichier de configuration Netplan :

   ```bash
   sudo nano /etc/netplan/50-cloud-init.yaml
   ```

3. S'assurer que l'interface `enp0s3` (NAT) reste configurée en DHCP. Une fois les modifications enregistrées, appliquer les paramètres réseau :

   ```bash
   sudo netplan apply
   ```

---

## Partie 2 : Création de la VM2 (Machine attaquante - Kali Linux)

La mise en place de cette seconde machine s'effectue plus rapidement grâce à l'utilisation d'une image pré-construite.

### Étape 1 : Téléchargement et importation

1. Se rendre sur le site officiel de Kali Linux et télécharger l'**image pré-construite destinée à VirtualBox**.
2. Extraire le contenu de l'archive et exécuter le fichier `.vbox` (ou utiliser l'option "Machine" -> "Ajouter" dans VirtualBox pour l'importer manuellement).

### Étape 2 : Ajustement des ressources matérielles

Dans la fenêtre de **Configuration** de la machine importée :

* **Système (RAM) :** Allouer entre **2 et 4 Go** (2 Go sont généralement suffisants pour les outils standards).
* **Processeur :** Allouer **2 vCPU**.

### Étape 3 : Configuration des cartes réseau

Dans l'onglet **Réseau** :

* **Adaptateur 1 :** Conserver le mode **NAT**.
* **Adaptateur 2 :** Activer l'interface, choisir **Réseau privé hôte** (Host-only), et sélectionner la même interface réseau que pour la VM1 (`VirtualBox Host-Only Ethernet Adapter` ou `vboxnet0`).

### Étape 4 : Démarrage et configuration de l'IP

1. Démarrer la machine virtuelle Kali Linux (les identifiants par défaut sont généralement `kali` / `kali`).
2. Ouvrir un terminal et identifier le nom de la seconde connexion réseau :

   ```bash
   nmcli connection show
   ```

3. Attribuer l'IP fixe `192.168.56.102/24` à cette interface (remplacer `NOM_DE_LA_CONNEXION` par le nom identifié à l'étape précédente, par exemple `Wired connection 2`) :

   ```bash
   sudo nmcli connection modify "NOM_DE_LA_CONNEXION" ipv4.addresses 192.168.56.102/24 ipv4.method manual
   sudo nmcli connection up "NOM_DE_LA_CONNEXION"
   ```

### Étape 5 : Test de connectivité

Pour valider l'infrastructure, vérifier la communication avec la VM1 :

```bash
ping -c 4 192.168.56.101
```

*Si des réponses sont reçues, l'infrastructure réseau est opérationnelle.*

---

## Annexe : Configuration de la disposition du clavier (AZERTY Français)

Selon les besoins, deux solutions permettent de basculer la configuration du clavier en français.

### Solution 1 : Modification temporaire (Interface graphique)

Cette commande est utile pour un changement rapide, mais **temporaire et local**. Elle modifie le clavier uniquement pour la session graphique en cours. La configuration sera réinitialisée au prochain redémarrage.

```bash
setxkbmap fr
```

### Solution 2 : Modification permanente et globale

Cette méthode modifie les fichiers de configuration du système d'exploitation. Le clavier restera en AZERTY après les redémarrages et fonctionnera également dans les consoles texte (TTY) hors de l'interface graphique.

Exécuter la commande suivante :

```bash
sudo dpkg-reconfigure keyboard-configuration
```

*Astuce de frappe si le système est actuellement en QWERTY :*
* *Pour le tiret `-` : appuyer sur la touche `)` (après le 0).*
* *Pour la lettre `a` : appuyer sur la touche `q`.*

**Étapes dans le menu de configuration :**
1. Choisir `Generic 105-key PC (intl.)`.
2. Sélectionner `French` dans la liste.
3. Sélectionner `The default for the keyboard layout` pour l'option AltGr.
4. Sélectionner `No compose key`.
5. Laisser l'option par défaut pour le serveur X.

Pour appliquer les modifications immédiatement sans nécessiter de redémarrage, exécuter :

```bash
setupcon
```