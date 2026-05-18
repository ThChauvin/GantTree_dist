# 🌳 GantTree

> Application Shiny de visualisation de planning et de suivi d'activités, basée sur les exports du logiciel **Pratix**.

---

## 📋 Présentation

**GantTree** est une application R Shiny qui exploite les exports Excel de **Pratix** (logiciel de gestion de demandes de tâches) pour générer automatiquement :

- Un **diagramme de Gantt** interactif des interventions planifiées
- Des **statistiques par agent** : charge mensuelle, répartition par activité, heatmap d'occupation, répartition par statut, etc.

L'application est conçue pour fonctionner **entièrement en local**, sans installation de R ni de packages supplémentaires — tout est fourni dans le dossier `GantTree_dist/`.

---

## 📁 Structure du dossier

```
GantTree_dist/
├── run.bat                  # ▶ Lanceur de l'application (double-clic)
├── app/
│   ├── app.R                # Point d'entrée principal de l'app Shiny
│   ├── modules/
│   │   ├── mod_import.R     # Import & parsing du fichier Pratix
│   │   ├── mod_gantt.R      # Diagramme de Gantt interactif
│   │   ├── mod_agent.R      # Vue statistiques par agent
│   │   ├── mod_recouvrement.R  # (à venir) Analyse des recouvrements
│   │   └── mod_stats.R      # (à venir) Statistiques agrégées
│   └── www/
│       └── Logo_PratixR.png # Logo affiché dans la navbar
├── output/                  # Dossier de sortie (exports CSV, etc.)
└── R/                       # Environnement R portable (fourni)
    ├── bin/
    ├── library/             # Tous les packages R nécessaires (fournis)
    └── ...
```

---

## ⚙️ Installation

### 1. Cloner ou télécharger le dépôt

```bash
git clone https://github.com/<votre-utilisateur>/GantTree.git
```

Ou télécharger le ZIP depuis GitHub → **Code** → **Download ZIP**, puis extraire le contenu.

### 2. Installer R dans le dossier `R/`

Le dossier `R/` doit contenir un environnement R portable (R n'est **pas** inclus dans le dépôt pour des raisons de taille).

1. Télécharger R pour Windows sur [https://cran.r-project.org](https://cran.r-project.org)
2. Lors de l'installation, **choisir comme dossier de destination** le dossier `R/` du projet :
   ```
   C:\...\GantTree_dist\R\
   ```
3. Terminer l'installation normalement

### 3. Copier les packages dans `R/library/`

Les packages R nécessaires sont fournis séparément (dossier `library/` du dépôt).

Copier l'intégralité du dossier `library/` dans :
```
GantTree_dist/R/library/
```

La structure finale doit ressembler à :
```
GantTree_dist/
└── R/
    ├── bin/
    ├── library/        ← packages copiés ici
    │   ├── shiny/
    │   ├── plotly/
    │   └── ...
    └── ...
```

### 4. Vérifier la structure

Assurez-vous que le dossier contient bien `run.bat`, le dossier `app/` et le dossier `R/` avec R installé et les packages en place.

---

## ▶️ Lancement

**Double-cliquez sur `run.bat`.**

L'application s'ouvre automatiquement dans votre navigateur par défaut.

> ⚠️ **Windows uniquement.** Le fichier `run.bat` utilise l'environnement R portable fourni dans le dossier `R/`.

---

## 📂 Format du fichier d'entrée (export Pratix)

L'application accepte les exports **`.xlsx`**, **`.xls`** ou **`.csv`** de Pratix. Le fichier doit contenir au minimum les colonnes suivantes :

| Colonne | Rôle |
|---|---|
| `Date de début intervention` | Date de début (formats FR `DD/MM/YYYY` ou ISO `YYYY-MM-DD`) |
| `Date de fin intervention` | Date de fin |
| `Resp. opérationnel` | Agent responsable |
| `Activité` | Catégorie de l'activité |
| `Projet` | Projet associé |
| `Statut` | État de la demande |
| `Description protocole` | Libellé descriptif |

Les autres colonnes exportées par Pratix sont détectées automatiquement.

> 💡 Une **donnée de démonstration** est intégrée à l'application pour tester sans fichier.

---

## ✨ Fonctionnalités

### 📥 Import & Nettoyage (`mod_import`)
- Chargement de fichiers `.xlsx`, `.xls`, `.csv`
- Détection automatique du séparateur et du format de date (FR / ISO)
- Correction automatique des dates inversées (fin < début)
- Résumé visuel en 4 indicateurs clés
- Aperçu tabulaire des données nettoyées

### 📊 Diagramme de Gantt (`mod_gantt`)
- Filtres dynamiques : agent, activité, statut, projet, période
- Regroupement configurable : par agent, activité, projet, pôle, statut
- Coloration par n'importe quelle dimension
- Ligne « Aujourd'hui » en pointillé rouge
- Tooltip au survol et détail au clic sur une barre
- Export **CSV filtré** et export **PNG** (barre Plotly)

### 👤 Statistiques par agent (`mod_agent`)
- Sélecteur d'agent avec navigation ◀ ▶
- Filtre de période (avec raccourci « Année courante »)
- **5 KPIs** : activités, jours planifiés, taux d'occupation, projets distincts, activités en cours
- Charge mensuelle empilée par type d'activité
- **Heatmap** d'occupation hebdomadaire (semaine × jour)
- Répartition par activité et par statut (graphiques en donut)
- Tableau détaillé avec coloration conditionnelle par statut
- Export CSV par agent

### 🔜 À venir
- **`mod_recouvrement`** — Détection des conflits de planning et chevauchements entre agents
- **`mod_stats`** — Statistiques agrégées par équipe, pôle et type d'activité

---

## 🎨 Interface

| Élément | Détail |
|---|---|
| Thème | Bootstrap **Flatly** via `bslib`, couleur primaire `#2E7D32` |
| Police | **Raleway** (Google Fonts) |
| Palette | **Darjeeling Limited** (`wesanderson`) |
| Logo | `www/Logo_PratixR.png` |

---

## 🧩 Packages R inclus

L'environnement R portable (`R/library/`) embarque notamment :

`shiny` · `bslib` · `plotly` · `DT` · `readxl` · `dplyr` · `tidyr` · `lubridate` · `ggplot2` · `wesanderson` · `shinyWidgets` · `shinycssloaders` · `openxlsx` · `stringr` · `scales` · et leurs dépendances.

---

## 🔧 Ajouter un module

1. Créer `app/modules/mod_monmodule.R` avec les fonctions `mod_monmodule_ui(id)` et `mod_monmodule_server(id, data)`
2. Ajouter `source("modules/mod_monmodule.R")` dans `app/app.R`
3. Ajouter un `nav_panel(...)` dans l'UI
4. Appeler `mod_monmodule_server("monmodule", data = shared_data)` dans le serveur

Le reactive `shared_data` expose le data.frame nettoyé avec les colonnes standardisées décrites dans la section *Format du fichier d'entrée*.

---

## 📄 Licence

Ce projet est distribué sous licence **GNU General Public License v3.0 (GPL-3.0)**.

Vous êtes libre d'utiliser, modifier et redistribuer ce logiciel, à condition que toute version dérivée soit également publiée sous la même licence GPL-3.0.

Voir le fichier [`LICENSE`](./LICENSE) pour le texte complet de la licence.

> 💡 **Comment ajouter le fichier LICENSE sur GitHub ?**
> Sur votre repo → **Add file** → **Create new file** → nommez-le `LICENSE` → cliquez **"Choose a license template"** → sélectionnez **GNU GPL v3**.

---

## 👤 Auteur

Développé par **UMR BIOFORA — ONF / INRAE**

> Pour toute question ou contribution, ouvrez une [issue](../../issues) sur ce dépôt.
