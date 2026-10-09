# Guide d'Installation Pas-à-Pas

Ce guide détaille comment installer et configurer notre système de détection d'intrusions (Snort) couplé à une centralisation de logs (syslog-ng → Elasticsearch → Kibana). 

L'architecture est déployée sur une VM Ubuntu Server (Serveur + IDS + ELK) et testée depuis une VM Kali Linux (Attaquant).

---

## 1. Configuration réseau

Assurez-vous que vos deux VM (Ubuntu et Kali) sont sur le même réseau privé hôte (host-only) dans VirtualBox. 
- **VM Ubuntu** : `192.168.56.101` (interface `enp0s8`)
- **VM Kali** : `192.168.56.102` (ou attribué par DHCP, par ex: `192.168.56.104`)

Vérifiez la connexion depuis Kali : `ping -c 4 192.168.56.101`

Toute la procédure pour créer les deux VM est détaillée ici :
**[Guide de Creation VM Pas-à-Pas](creation_machine.md)**

---

## 2. Services de base (Serveur Cible)

Mettre à jour le système et installer les services requis (serveur web et SSH) :

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 php libapache2-mod-php openssh-server
```

Vérifier l'état des services pour s'assurer de leur bon fonctionnement :

```bash
sudo systemctl status apache2 ssh
```

*Il est désormais possible d'établir une connexion SSH depuis la machine hôte vers le serveur cible (ex. via PowerShell : `ssh uqac@192.168.56.101`).*

---

## 3. Snort (Système de Détection d'Intrusions)

### Installation
```bash
sudo apt install -y snort
```
*Lors de l'installation, indiquez l'interface `enp0s8` et le réseau `192.168.56.0/24`.*

### Configuration essentielle (VirtualBox)
Dans `/etc/snort/snort.debian.conf`, il est **crucial** d'ajouter l'option `-k none` pour éviter que Snort n'ignore les paquets à cause de sommes de contrôle (checksums) erronées générées par la carte réseau virtuelle :
```text
DEBIAN_SNORT_OPTIONS="-k none"
```

### Ajout des règles personnalisées
Nos règles pour les 5 scénarios doivent être ajoutées dans `/etc/snort/rules/local.rules`. Vous pouvez copier celles fournies dans notre dossier `CONF/snort/`.
```bash
# Sauvegarder les règles par défaut
sudo cp /etc/snort/rules/local.rules /etc/snort/rules/local.rules.bak

# Ajouter nos règles d'injection SQL par exemple
cat CONF/snort/sql_injection.rules | sudo tee -a /etc/snort/rules/local.rules
```

Redémarrez Snort pour appliquer :
```bash
sudo systemctl restart snort
```
*Les alertes seront écrites dans `/var/log/snort/snort.alert.fast`.*

---

## 4. syslog-ng (Collecteur de logs)

### Installation
```bash
sudo apt install -y syslog-ng
```

### Configuration
Nous allons collecter les logs d'Apache, Snort et SSH, puis les formater en JSON pour Elasticsearch.
Modifiez `/etc/syslog-ng/syslog-ng.conf` pour y ajouter ce bloc à la fin :

```text

# --- Sources ---
source s_apache {
    file("/var/log/apache2/access.log");
    file("/var/log/apache2/error.log");
};

source s_snort {
    file("/var/log/snort/snort.alert.fast" flags(no-parse));
};

# --- Destination locale (test / débogage) ---
destination d_local_central {
    file("/var/log/syslog-ng-central.log");
};

# --- Liaison ---
log {
    source(s_apache);
    source(s_snort);
    source(s_src);
    destination(d_local_central);
};


destination d_elastic {
    http(
        url("http://127.0.0.1:9200/_bulk")
        method("POST")
        headers("Content-Type: application/x-ndjson")
        body("{\"create\": {\"_index\": \"logs-securite-${YEAR}.${MONTH}.${DAY}\"} }\n{\"message\": \"${MSG}\"}\n")
    );
};

destination d_script {
    program("/usr/local/bin/alerte_sec.sh");
};

log {
    source(s_apache);
    source(s_snort);
    source(s_src);
    destination(d_local_central);
    destination(d_elastic);
};

filter f_regles_perso {
    message("10000");
};

log {
    source(s_snort);
    filter(f_regles_perso);
    destination(d_script);
};
```
*Note importante : L'utilisation de `escape-double-quotes` protège le JSON contre les guillemets présents dans les requêtes Apache.*

Appliquez les changements :
```bash
sudo syslog-ng -s  # Vérifie la syntaxe
sudo systemctl restart syslog-ng
```

---

## 5. Elasticsearch (Base de données)

### Installation via le dépôt officiel Elastic
```bash
sudo apt install -y apt-transport-https curl gnupg
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --yes --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update
sudo apt install -y elasticsearch
```

### Configuration (Laboratoire uniquement)
Désactivez la sécurité pour simplifier le test. Dans `/etc/elasticsearch/elasticsearch.yml`, ajoutez ou modifiez :
```yaml
xpack.security.enabled: false
```
Démarrez le service :
```bash
sudo systemctl enable --now elasticsearch
```
*Le démarrage peut prendre 1 à 2 minutes. Vérifiez que la base répond avec : `curl -X GET "http://127.0.0.1:9200"`.*

---

## 6. Kibana (Interface de visualisation)

### Installation
```bash
sudo apt install -y kibana
```

### Configuration
Pour pouvoir accéder à l'interface web de Kibana depuis votre machine Kali ou votre PC hôte, éditez `/etc/kibana/kibana.yml` :
```yaml
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://127.0.0.1:9200"]
```
Démarrez le service :
```bash
sudo systemctl enable --now kibana
```

---

## 7. Affichage des logs finaux

1. Ouvrez `http://192.168.56.101:5601` dans votre navigateur.
2. Allez dans **Stack Management** > **Data Views** > **Create data view**.
3. Motif (Index pattern) : `logs-securite-*`.
4. Timestamp field : `@timestamp` et sauvegardez.
5. Allez dans **Analytics** > **Discover**.
6. Vous pouvez maintenant filtrer avec `program: "snort"` ou `message: "*SQLI*"` pour voir vos alertes Snort croisées avec les requêtes Apache (`program: "apache2"`) !
