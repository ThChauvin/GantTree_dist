# ============================================================
# Application Shiny - Suivi des activités
# Architecture modulaire (Gantt + modules futurs)
# ============================================================

library(shiny)
library(bslib)
library(readxl)
library(dplyr)
library(lubridate)
library(plotly)
library(DT)

# ---- Chargement des modules --------------------------------
source("modules/mod_import.R")
source("modules/mod_gantt.R")
source("modules/mod_agent.R")
# source("modules/mod_recouvrement.R")  # à activer plus tard
# source("modules/mod_stats.R")         # à activer plus tard

# ---- Fonctions utilitaires (avant l'UI) --------------------
icon_text <- function(icon_name, label) {
  tagList(icon(icon_name), label)
}

# ============================================================
# UI
# ============================================================
ui <- page_navbar(
  header = tags$head(
    tags$link(
      rel  = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Raleway:wght@400;600;700&display=swap"
    ),
    tags$style(HTML("
      /* ── Navbar générale ── */
      .navbar { padding-top: 6px; padding-bottom: 6px; }

      /* ── Titre appli ── */
      .navbar-brand {
        font-family: 'Raleway', sans-serif !important;
        font-size:   1.8rem !important;
        font-weight: 700 !important;
        letter-spacing: 0.06em;
        color: white !important;
        display: flex;
        align-items: center;
        gap: 10px;
      }

      /* ── Onglets de navigation ── */
      .navbar-nav .nav-link {
        font-family: 'Raleway', sans-serif !important;
        font-size:   0.92rem !important;
        font-weight: 600 !important;
        letter-spacing: 0.03em;
        color: rgba(255,255,255,0.85) !important;
        padding: 6px 14px !important;
      }
      .navbar-nav .nav-link:hover,
      .navbar-nav .nav-link.active {
        color: white !important;
      }
      
      /* Couleur des en-têtes de cartes */
      .card-header {
        background-color: #37474F !important;  /* même vert que la navbar */
        color: white !important;
        font-family: 'Raleway', sans-serif;
        font-weight: 600;
        font-size: 0.9rem;
      }
      
      /* ── Badge version ── */
      .version-badge {
        font-family: 'Raleway', sans-serif;
        font-size:   0.78rem;
        color: rgba(255,255,255,0.55) !important;
        letter-spacing: 0.04em;
      }
    "))
  ),
  title = tags$span(
    tags$img(
      src    = "Logo_PratixR.png",
      height = "80px",
      style  = "vertical-align:middle; border-radius:6px;"
    ),
    "GantTree"
  ),
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#1B5E20",
    secondary  = "#263238"
  ),
  window_title = "Suivi activités",
  
  # ── Onglet import ──────────────────────────────────────────
  nav_panel(
    title = icon_text("upload", "Import"),
    mod_import_ui("import")
  ),
  
  # ── Onglet Gantt ──────────────────────────────────────────
  nav_panel(
    title = icon_text("calendar-range", "Gantt"),
    mod_gantt_ui("gantt")
  ),
  
  # ── Onglet Agent ──────────────────────────────────────────
  nav_panel("Agents",
            icon = icon("users"),
            mod_agent_ui("agent")
  ),
  # ── Espace réservé pour les modules futurs ─────────────────
  nav_menu(
    title = "Analyses (à venir)",
    nav_panel("Recouvrement", icon = icon("layer-group"),
              div(class = "container mt-4",
                  card(card_header("Module en cours de développement"),
                       p("Le module d'analyse des recouvrements entre activités menées par les mêmes personnes sera disponible prochainement.")
                  )
              )
    ),
    nav_panel("Statistiques", icon = icon("chart-bar"),
              div(class = "container mt-4",
                  card(card_header("Module en cours de développement"),
                       p("Des statistiques agrégées (charge par personne, par projet, par pôle...) seront disponibles prochainement.")
                  )
              )
    )
  ),
  
  nav_spacer(),
  nav_item(
    tags$small(class = "version-badge", "v1.1 – Gantt · Agents")
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {
  
  # Données partagées entre tous les modules
  shared_data <- mod_import_server("import")
  
  mod_gantt_server("gantt", data = shared_data)
  mod_agent_server("agent", data = shared_data)
  
  # mod_recouvrement_server("recouvrement", data = shared_data)
  # mod_stats_server("stats", data = shared_data)
  session$onSessionEnded(function() {    # fermeture de R quand la session se termine
    
    stopApp()
    
  })
  
}

shinyApp(ui, server)