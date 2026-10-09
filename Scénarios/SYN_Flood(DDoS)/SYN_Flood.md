# Attaque SYN Flood

## 1. Description

Une attaque **SYN Flood** est un type d'attaque informatique par déni de service (**DoS/DDoS**) qui sature les ressources d'un serveur cible en exploitant le mécanisme d'établissement des connexions du protocole **TCP**.

Cette attaque agit au niveau de la **couche transport (Layer 4)** et peut rendre un serveur indisponible pour les utilisateurs légitimes en saturant sa table de connexions avec de nombreuses demandes de connexion incomplètes.

---

## 2. Configurer la détection avec Snort

### 2.1 Modifier le fichier de règles

Commencez par modifier le fichier de règles locales de Snort :

```bash
sudo nano /etc/snort/rules/local.rules
```

### 2.2 Ajouter la règle de détection

Ajoutez ensuite la règle suivante :

```text
alert tcp any any -> $HOME_NET 80 (msg:"ALERTE DDoS - SYN Flood detecte"; flags:S; threshold:type both, track by_dst, count 100, seconds 2; sid:1000004; rev:1;)
```

### 2.3 Explication de la règle

#### 1. En-tête de la règle — Où regarder ?

- **`alert`** : action demandée à Snort. Une alerte est générée lorsque le trafic correspondant à la règle est détecté. D'autres actions sont possibles, comme `drop`, mais ici l'objectif est simplement d'enregistrer l'événement afin de pouvoir l'exploiter dans Kibana.

- **`tcp`** : protocole surveillé. Le SYN Flood exploite le mécanisme d'établissement des connexions TCP.

- **`any any`** : origine du trafic. Le premier `any` signifie que n'importe quelle adresse IP source peut être concernée, tandis que le second indique que n'importe quel port source est accepté.

- **`->`** : direction du trafic. La règle surveille le trafic entrant vers le réseau protégé.

- **`$HOME_NET`** : réseau de destination. Il s'agit de la variable configurée au début du projet, ici `192.168.56.0/24`. Elle représente le réseau à protéger.

- **`80`** : port de destination surveillé. Dans ce projet, le port 80 correspond au serveur Web Apache.

#### 2. Options de la règle — Que rechercher ?

- **`msg:"ALERTE DDoS - SYN Flood detecte"`** : message associé à l'alerte. Ce texte est enregistré dans les journaux de Snort, puis peut être récupéré par `syslog-ng` et affiché dans Kibana.

- **`flags:S`** : option centrale de la détection. Le drapeau TCP `S` correspond au paquet **SYN**, utilisé pour initier une connexion TCP. Un SYN Flood repose sur l'envoi massif de demandes de connexion qui ne sont pas complétées.

- **`threshold:type both, track by_dst, count 100, seconds 2`** : mécanisme de limitation du nombre d'alertes afin d'éviter de surcharger les journaux lors d'un volume important de trafic.

- **`track by_dst`** : comptabilise les paquets en fonction de leur destination, c'est-à-dire le serveur surveillé.

- **`count 100` et `seconds 2`** : le seuil est fixé à 100 paquets SYN sur une période de 2 secondes.

- **`type both`** : permet de contrôler la génération des alertes autour du seuil défini afin d'éviter une quantité excessive d'alertes dans les journaux.

- **`sid:1000004`** : identifiant unique de la règle (**Snort ID**). Les règles personnalisées utilisent généralement un SID réservé aux règles locales.

### 2.4 Redémarrer Snort

Enregistrez le fichier (`Ctrl+O`, puis `Entrée`) et quittez l'éditeur (`Ctrl+X`).

Redémarrez ensuite Snort afin d'appliquer la nouvelle règle :

```bash
sudo systemctl restart snort
```

---

## 3. Générer le trafic de test depuis Kali

Dans un environnement de laboratoire autorisé, le trafic de test peut être généré avec l'outil **hping3**.

> **Attention :** cette commande génère un volume important de trafic. Effectuez ce test uniquement sur votre environnement de laboratoire et pendant une courte durée. Un volume excessif peut générer de nombreux journaux, saturer l'espace disque et perturber les services de supervision, notamment Kibana.

```bash
sudo hping3 -S --flood -p 80 192.168.56.101
```

Le paramètre **`--flood`** demande à `hping3` d'envoyer les paquets à un rythme très élevé, sans attendre les réponses.

Arrêtez le test avec `Ctrl+C` après la durée prévue pour votre laboratoire.

---

## 4. Visualiser les alertes dans Kibana

Pour vérifier que la détection fonctionne :

1. Ouvrez l'onglet **Discover** dans Kibana.
2. Dans la barre de recherche, recherchez le message d'alerte :
   **`ALERTE DDoS`**
3. Vérifiez que la période sélectionnée en haut à droite couvre le moment du test, par exemple :
   - **Last 15 minutes**
   - ou **Today**
4. Vérifiez que les événements générés par Snort apparaissent bien dans les résultats.

![Visualisation de l'alerte dans Kibana](Kibana_allert_DDoS.png)

## 5. Limites de la configuration
Bien que cette règle permette de détecter une attaque basique, ce dispositif présente plusieurs limites techniques et conceptuelles :

### 5.1 Détection sans prévention (IDS vs IPS)
La règle actuelle est configurée avec l'action alert. Le système agit uniquement en tant que système de détection d'intrusion (IDS) et se contente de journaliser l'événement. Aucun mécanisme n'est en place pour bloquer (action drop) le trafic malveillant. Le serveur Apache reste donc totalement vulnérable à l'épuisement de ses ressources.

### 5.2 Sensibilité des seuils (Faux positifs et faux négatifs)
La détection repose sur un seuil fixe et rigide (100 paquets en 2 secondes).

Faux positifs : Un pic d'affluence légitime très soudain sur le serveur web pourrait déclencher la règle, générant de fausses alertes.

Faux négatifs : Un attaquant sophistiqué pourrait configurer son outil pour envoyer des requêtes à un rythme légèrement inférieur au seuil configuré (attaque de type Low and Slow). L'attaque passerait alors sous le radar de Snort tout en saturant lentement le serveur.

### 5.3 Absence d'analyse d'état (Stateful inspection)
La règle se limite à compter les paquets porteurs du drapeau SYN. Elle ne vérifie pas si la connexion aboutit réellement (réception d'un paquet ACK). Une analyse plus avancée nécessiterait l'utilisation des préprocesseurs de Snort (comme le préprocesseur stream), capables de maintenir l'état des sessions TCP et de détecter spécifiquement les demi-connexions orphelines.

### 5.4 Usurpation d'adresse IP (IP Spoofing)
Dans le cadre d'un véritable SYN Flood, les attaquants falsifient (spoofent) généralement l'adresse IP source des paquets. Par conséquent, les adresses IP enregistrées par Snort et remontées dans Kibana sont le plus souvent illégitimes. Mettre en place un blocage manuel ou automatique basé sur ces adresses IP s'avère donc inefficace et risque de bloquer des utilisateurs légitimes (dommages collatéraux).

### 5.5 Vulnérabilité de l'infrastructure de supervision
Lors d'une attaque massive, le volume de paquets peut saturer les capacités de traitement de Snort. De plus, la génération excessive d'alertes risque d'engorger la chaîne de journalisation (syslog-ng), de saturer l'espace disque du serveur et de provoquer le plantage d'Elasticsearch ou de Kibana, neutralisant ainsi la visibilité sur l'attaque.

---
**[Retour au README](../../README.md)**