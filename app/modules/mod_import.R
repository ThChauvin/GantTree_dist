# ============================================================
# Module : mod_import
# Rôle   : upload fichier (xlsx ou csv), parsing, validation,
#           exposition des données nettoyées aux autres modules
# ============================================================

# Colonnes attendues et leur rôle
COLS_REQUIRED <- c(
  "Date de début intervention",
  "Date de fin intervention"
)
COLS_EXPECTED <- c(
  "Numéro",
  "Date de création",
  "Resp. opérationnel",
  "Date de début intervention",
  "Date de fin intervention",
  "Description protocole",
  "Priorité",
  "Activité",
  "Statut",
  "Projet",
  "Espèce",
  "Lieu(x)",
  "Equipe UE",
  "Demandeur",
  "Resp. scientifique",
  "Resp. technique",
  "Estimation temps"
)

# ---- UI ----------------------------------------------------
mod_import_ui <- function(id) {
  ns <- NS(id)

  div(class = "container-fluid mt-3",
    fluidRow(
      # Panneau upload
      column(4,
        card(
          card_header(icon("file-arrow-up"), " Charger un fichier"),
          card_body(
            fileInput(ns("file"), NULL,
              accept      = c(".xlsx", ".xls", ".csv"),
              placeholder = "Glisser-déposer ou cliquer",
              buttonLabel = "Parcourir…"
            ),
            helpText("Formats acceptés : .xlsx, .xls, .csv"),
            hr(),
            # Options CSV (masquées si xlsx)
            conditionalPanel(
              condition = sprintf("input['%s'].endsWith('.csv')", ns("file_name_hack")),
              selectInput(ns("sep"), "Séparateur CSV",
                choices = c(Virgule = ",", "Point-virgule" = ";", Tabulation = "\t"),
                selected = ";"
              ),
              selectInput(ns("dec"), "Décimale",
                choices = c(Virgule = ",", Point = "."),
                selected = ","
              )
            ),
            # Bouton de chargement avec données démo
            actionButton(ns("load_demo"), "Charger données démo",
              class = "btn-outline-secondary btn-sm w-100",
              icon  = icon("flask")
            )
          )
        )
      ),

      # Panneau résumé / validation
      column(8,
        card(
          card_header(icon("circle-info"), " Résumé du fichier chargé"),
          card_body(
            uiOutput(ns("summary_ui"))
          )
        )
      )
    ),

    # Aperçu du tableau
    fluidRow(
      column(12,
        card(
          card_header(icon("table"), " Aperçu des données",
            # Badge compteur à droite
            span(class = "float-end",
              uiOutput(ns("row_badge"))
            )
          ),
          card_body(
            DTOutput(ns("preview_table"))
          )
        )
      )
    )
  )
}

# ---- Server ------------------------------------------------
mod_import_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # ── Réactif : données brutes ──────────────────────────────
    raw_data <- reactiveVal(NULL)

    # Chargement fichier utilisateur
    observeEvent(input$file, {
      req(input$file)
      tryCatch({
        df <- read_file(input$file$datapath,
                        input$file$name,
                        sep = input$sep %||% ";",
                        dec = input$dec %||% ",")
        raw_data(df)
      }, error = function(e) {
        showNotification(paste("Erreur de lecture :", e$message),
                         type = "error", duration = 8)
      })
    })

    # Chargement données démo
    observeEvent(input$load_demo, {
      raw_data(make_demo_data())
    })

    # ── Réactif : données nettoyées (exposées aux autres modules)
    clean_data <- reactive({
      req(raw_data())
      clean_and_parse(raw_data())
    })

    # ── Résumé ─────────────────────────────────────────────────
    output$summary_ui <- renderUI({
      if (is.null(raw_data())) {
        return(div(class = "text-muted text-center mt-3",
          icon("circle-info"), " Aucun fichier chargé — utilisez le panneau de gauche."
        ))
      }

      df   <- clean_data()
      errs <- attr(df, "warnings")

      tagList(
        fluidRow(
          value_box_mini("Activités",    nrow(df),               "calendar-check", PAL_DARJEELING[1]),
          value_box_mini("Responsables", n_distinct(df$resp_op), "users",          PAL_DARJEELING[2]),
          value_box_mini("Projets",      n_distinct(df$Projet),  "folder-open",    PAL_DARJEELING[3]),
          value_box_mini("Période",      date_range_label(df),   "clock",          PAL_DARJEELING[4])
        ),
        if (length(errs) > 0)
          div(class = "alert alert-warning mt-2",
            icon("triangle-exclamation"), " ",
            paste(errs, collapse = " | ")
          )
      )
    })

    output$row_badge <- renderUI({
      req(clean_data())
      span(class = "badge bg-secondary", nrow(clean_data()), "lignes")
    })

    # ── Aperçu tableau ─────────────────────────────────────────
    output$preview_table <- renderDT({
      req(clean_data())
      df <- clean_data() %>%
        select(Numéro, resp_op, date_debut, date_fin,
               activite, Projet, Statut,
               description_courte) %>%
        rename(
          "Resp. opérationnel" = resp_op,
          "Début"              = date_debut,
          "Fin"                = date_fin,
          "Activité"           = activite,
          "Description"        = description_courte
        )

      datatable(df,
        options = list(pageLength = 8, scrollX = TRUE,
                       language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/fr-FR.json")),
        rownames  = FALSE,
        selection = "none",
        class     = "compact stripe hover"
      ) %>%
        formatDate(c("Début", "Fin"), method = "toLocaleDateString")
    })

    # Retourne les données nettoyées pour les autres modules
    return(clean_data)
  })
}

# ============================================================
# Fonctions internes
# ============================================================

read_file <- function(path, name, sep = ";", dec = ",") {
  ext <- tolower(tools::file_ext(name))
  if (ext %in% c("xlsx", "xls")) {
    readxl::read_excel(path)  # readxl detects dates natively
  } else if (ext == "csv") {
    read.csv(path, sep = sep, dec = dec,
             stringsAsFactors = FALSE, encoding = "UTF-8")
  } else {
    stop("Format non supporté : ", ext)
  }
}

clean_and_parse <- function(df) {
  warnings <- character(0)

  # ── Renommage flexible des colonnes ────────────────────────
  # On cherche par correspondance approximative pour être robuste
  col_map <- list(
    numero           = c("Numéro", "Numero", "ID", "N°"),
    resp_op          = c("Resp. opérationnel", "Resp opérationnel", "Responsable opérationnel"),
    date_debut       = c("Date de début intervention", "Date début", "Debut"),
    date_fin         = c("Date de fin intervention",   "Date fin",   "Fin"),
    description      = c("Description protocole", "Description", "Protocole"),
    activite         = c("Activité", "Activite"),
    equipe_ue        = c("Equipe UE", "Equipe"),
    resp_sci         = c("Resp. scientifique", "Resp scientifique"),
    resp_tech        = c("Resp. technique",    "Resp technique")
  )

  for (target in names(col_map)) {
    candidates <- col_map[[target]]
    found <- intersect(candidates, colnames(df))
    if (length(found) > 0 && !target %in% colnames(df)) {
      df[[target]] <- df[[found[1]]]
    }
  }

  # ── Colonnes de secours ───────────────────────────────────
  if (!"Projet"  %in% colnames(df)) df$Projet  <- NA_character_
  if (!"Statut"  %in% colnames(df)) df$Statut  <- NA_character_
  if (!"Espèce"  %in% colnames(df)) df$Espèce  <- NA_character_
  if (!"Lieu(x)" %in% colnames(df)) df[["Lieu(x)"]] <- NA_character_
  if (!"Estimation temps" %in% colnames(df)) df[["Estimation temps"]] <- NA_real_

  # ── Parsing des dates ─────────────────────────────────────
  df$date_debut <- parse_dates(df$date_debut)
  df$date_fin   <- parse_dates(df$date_fin)

  # Signaler les lignes sans dates valides
  bad <- is.na(df$date_debut) | is.na(df$date_fin)
  if (any(bad)) {
    warnings <- c(warnings, sprintf("%d ligne(s) ignorée(s) : dates manquantes ou invalides.", sum(bad)))
    df <- df[!bad, ]
  }

  # Date fin < date début → signaler et corriger
  inverted <- df$date_fin < df$date_debut
  if (any(inverted, na.rm = TRUE)) {
    warnings <- c(warnings, sprintf("%d ligne(s) avec date fin < date début : inversées automatiquement.", sum(inverted)))
    tmp             <- df$date_fin[inverted]
    df$date_fin[inverted]   <- df$date_debut[inverted]
    df$date_debut[inverted] <- tmp
  }

  # ── Description courte (80 car.) ──────────────────────────
  desc <- if ("description" %in% colnames(df)) df$description else ""
  df$description_courte <- ifelse(
    nchar(desc) > 80,
    paste0(substr(desc, 1, 77), "…"),
    desc
  )

  # ── Resp. opérationnel : nettoyer NA ─────────────────────
  if (!"resp_op" %in% colnames(df)) df$resp_op <- "Non renseigné"
  df$resp_op[is.na(df$resp_op) | df$resp_op == ""] <- "Non renseigné"

  # ── Durée en jours ────────────────────────────────────────
  df$duree_jours <- as.numeric(df$date_fin - df$date_debut)

  attr(df, "warnings") <- warnings
  df
}

parse_dates <- function(x) {
  # Deja une Date ou POSIXct (readxl sans col_types="text")
  if (inherits(x, "Date"))    return(as.Date(x))
  if (inherits(x, "POSIXct")) return(as.Date(x))

  x_chr <- as.character(x)

  # Numero de serie Excel (entier ~40000-50000) : fallback si col_types="text"
  nums <- suppressWarnings(as.numeric(x_chr))
  is_excel_serial <- !is.na(nums) & nums > 30000 & nums < 80000
  result <- rep(as.Date(NA), length(x))
  result[is_excel_serial] <- as.Date(nums[is_excel_serial], origin = "1899-12-30")

  # Formats texte classiques pour le reste
  formats <- c("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d")
  for (fmt in formats) {
    still_na <- is.na(result)
    if (!any(still_na)) break
    parsed <- suppressWarnings(as.Date(x_chr, format = fmt))
    result[still_na & !is.na(parsed)] <- parsed[still_na & !is.na(parsed)]
  }
  result
}

date_range_label <- function(df) {
  if (nrow(df) == 0) return("—")
  paste0(
    format(min(df$date_debut, na.rm = TRUE), "%b %Y"),
    " → ",
    format(max(df$date_fin,   na.rm = TRUE), "%b %Y")
  )
}

# Palette Darjeeling Limited (wesanderson)
PAL_DARJEELING <- c("#FF0000", "#00A08A", "#F2AD00", "#F98400", "#5BBCD6")

# Value box minimaliste compatible bslib
# color = nom Bootstrap ("primary") OU code hex ("#FF0000")
value_box_mini <- function(title, value, icon_name, color = "primary") {
  if (startsWith(as.character(color), "#")) {
    card_class <- "card mb-2"
    card_style <- paste0("background-color:", color, "; color:white;")
  } else {
    card_class <- paste0("card text-bg-", color, " mb-2")
    card_style <- NULL
  }
  column(3,
    div(class = card_class, style = card_style,
      div(class = "card-body py-2 d-flex justify-content-between align-items-center",
        div(
          div(class = "fs-5 fw-bold", value),
          div(class = "small", title)
        ),
        icon(icon_name, class = "fa-2x opacity-50")
      )
    )
  )
}

# Données démo si aucun fichier chargé
make_demo_data <- function() {
  today <- Sys.Date()
  data.frame(
    Numéro                      = 901:910,
    "Date de création"          = today - 30,
    "Date de modification"      = NA,
    "Resp. opérationnel"        = c("Alice Martin","Bob Durand","Alice Martin",
                                    "Claire Petit","Bob Durand","Alice Martin",
                                    "Claire Petit","Bob Durand","Alice Martin","Claire Petit"),
    "Date de début intervention"= today + c(0,5,10,0,15,20,5,10,25,30),
    "Date de fin intervention"  = today + c(30,45,60,20,40,70,25,50,80,90),
    "Description protocole"     = paste("Activité démo numéro", 901:910),
    Priorité                    = sample(1:3, 10, replace = TRUE),
    Quantité                    = sample(c(1,5,10,24), 10, replace = TRUE),
    Activité                    = sample(c("Elevage et suivi en serre","Phénotypage",
                                           "Installation de dispositif","Instrumentation"), 10, replace = TRUE),
    Statut                      = sample(c("Validée","En cours","En attente"), 10, replace = TRUE),
    Projet                      = sample(c("POLODIV","Biosphereadapt","Convention MAA"), 10, replace = TRUE),
    Espèce                      = sample(c("PEUPLIERS HYBRIDES","MELEZES","DOUGLAS"), 10, replace = TRUE),
    "Lieu(x)"                   = sample(c("Serre","Extérieur","Laboratoire"), 10, replace = TRUE),
    Campagne                    = "Campagne 2019",
    "Equipe UE"                 = sample(c("Pôle EMC²","Pôle Phéno","Pôle C2RG"), 10, replace = TRUE),
    "Estimation temps"          = sample(c(2,5,10,20,30), 10, replace = TRUE),
    Demandeur                   = c("X","Y","Z","X","Y","Z","X","Y","Z","X"),
    "Resp. scientifique"        = c("S1","S2","S1","S2","S1","S2","S1","S2","S1","S2"),
    "Resp. technique"           = c("T1","T2","T1","T2","T1","T2","T1","T2","T1","T2"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# opérateur null-coalesce
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b
