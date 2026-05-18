# ============================================================
# Module : mod_agent
# Rôle   : Vue détaillée par agent — occupation, répartition,
#           charge dans l'année, timeline des activités
# ============================================================

# ── Helper : icône ⓘ avec bulle Bootstrap ──────────────────
tooltip_icon <- function(text, placement = "top") {
  tags$span(
    class               = "ms-1 text-muted",
    style               = "cursor:help; font-size:0.85em;",
    `data-bs-toggle`    = "tooltip",
    `data-bs-placement` = placement,
    `data-bs-html`      = "true",
    title               = text,
    icon("circle-question")
  )
}

# ── Helper : en-tête de carte avec tooltip ──────────────────
card_header_tip <- function(icon_name, label, tip_text) {
  div(class = "d-flex align-items-center gap-1",
    icon(icon_name), label,
    tooltip_icon(tip_text)
  )
}

mod_agent_ui <- function(id) {
  ns <- NS(id)

  div(class = "container-fluid mt-3",

    # Activation des tooltips Bootstrap (une seule fois par page)
    tags$script(HTML(
      "$(function(){ var els = document.querySelectorAll('[data-bs-toggle=\"tooltip\"]');",
      "els.forEach(function(el){ new bootstrap.Tooltip(el, {trigger:'hover'}); }); });"
    )),

    # ── Sélecteur agent + période ──────────────────────────────
    fluidRow(
      column(4,
        card(
          card_body(class = "p-2",
            div(class = "d-flex align-items-center gap-2",
              div(class = "flex-grow-1",
                selectInput(ns("agent"), NULL,
                  choices  = c("— Choisir un agent —" = ""),
                  selected = "",
                  width    = "100%"
                )
              ),
              actionButton(ns("prev_agent"), "", icon = icon("chevron-left"),
                           class = "btn-sm btn-outline-secondary"),
              actionButton(ns("next_agent"), "", icon = icon("chevron-right"),
                           class = "btn-sm btn-outline-secondary")
            )
          )
        )
      ),
      column(4,
        card(
          card_body(class = "p-2",
            div(class = "d-flex align-items-center gap-2",
              dateInput(ns("period_from"), NULL,
                        value = paste0(format(Sys.Date(), "%Y"), "-01-01"),
                        width = "100%"),
              span("→"),
              dateInput(ns("period_to"), NULL,
                        value = paste0(format(Sys.Date(), "%Y"), "-12-31"),
                        width = "100%")
            )
          )
        )
      ),
      column(4,
        card(
          card_body(class = "p-2 d-flex justify-content-between align-items-center",
            uiOutput(ns("header_info")),
            div(class = "d-flex gap-2",
              actionButton(ns("reset_period"), "Année courante",
                           class = "btn-sm btn-outline-secondary",
                           icon  = icon("rotate-left")),
              downloadButton(ns("dl_csv"), "Export CSV",
                             class = "btn-sm btn-outline-secondary")
            )
          )
        )
      )
    ),

    # ── KPIs ───────────────────────────────────────────────────
    uiOutput(ns("kpi_row")),

    # ── Charts ligne 1 : charge mensuelle + répartition activité
    fluidRow(
      column(8,
        card(class = "mt-2",
          card_header(card_header_tip("chart-bar", " Charge mensuelle (jours cumulés)",
            "Nombre de jours-calendrier cumulés par mois sur lesquels l'agent a au moins une activité planifiée.<br>Les barres sont empilées par type d'activité.")),
          card_body(class = "p-1",
            plotlyOutput(ns("monthly_load"), height = "260px")
          )
        )
      ),
      column(4,
        card(class = "mt-2",
          card_header(card_header_tip("chart-pie", " Répartition par activité",
            "Part de chaque type d'activité dans le total des jours planifiés sur la période.<br>Basé sur la somme des durées (date fin − date début).")),
          card_body(class = "p-1",
            plotlyOutput(ns("pie_activite"), height = "260px")
          )
        )
      )
    ),

    # ── Charts ligne 2 : heatmap hebdo + répartition statut
    fluidRow(
      column(8,
        card(class = "mt-2",
          card_header(card_header_tip("calendar-week", " Heatmap d'occupation hebdomadaire",
            "Intensité de charge pour chaque jour de la semaine et chaque semaine de l'année.<br>La couleur représente le nombre d'activités simultanées ce jour-là.<br>Blanc = aucune activité · Bleu foncé = forte simultanéité.")),
          card_body(class = "p-1",
            plotlyOutput(ns("heatmap_week"), height = "220px")
          )
        )
      ),
      column(4,
        card(class = "mt-2",
          card_header(card_header_tip("circle-half-stroke", " Répartition par statut",
            "Distribution des activités selon leur statut courant.<br><b>Validée</b> : approuvée · <b>En cours</b> : active · <b>En attente</b> : bloquée · <b>Annulée</b> · <b>Terminée</b>")),
          card_body(class = "p-1",
            plotlyOutput(ns("pie_statut"), height = "220px")
          )
        )
      )
    ),

    # ── Tableau détaillé ───────────────────────────────────────
    fluidRow(
      column(12,
        card(class = "mt-2",
          card_header(
            div(class = "d-flex justify-content-between align-items-center",
              span(icon("list"), " Activités de l'agent"),
              uiOutput(ns("table_badge"))
            )
          ),
          card_body(class = "p-0",
            DTOutput(ns("detail_table"))
          )
        )
      )
    )
  )
}

# ── Server ──────────────────────────────────────────────────
mod_agent_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Met à jour la liste des agents quand les données changent
    observe({
      req(data())
      agents <- sort(unique(data()$resp_op))
      updateSelectInput(session, "agent",
        choices  = c("— Choisir un agent —" = "", setNames(agents, agents)),
        selected = if (length(agents) > 0) agents[1] else ""
      )
    })

    # Navigation prev/next agent
    observeEvent(input$prev_agent, {
      req(data(), input$agent != "")
      agents <- sort(unique(data()$resp_op))
      idx    <- which(agents == input$agent)
      if (length(idx) > 0 && idx > 1)
        updateSelectInput(session, "agent", selected = agents[idx - 1])
    })
    observeEvent(input$next_agent, {
      req(data(), input$agent != "")
      agents <- sort(unique(data()$resp_op))
      idx    <- which(agents == input$agent)
      if (length(idx) > 0 && idx < length(agents))
        updateSelectInput(session, "agent", selected = agents[idx + 1])
    })

    # Reset période → année courante
    observeEvent(input$reset_period, {
      yr <- format(Sys.Date(), "%Y")
      updateDateInput(session, "period_from", value = paste0(yr, "-01-01"))
      updateDateInput(session, "period_to",   value = paste0(yr, "-12-31"))
    })

    # ── Données filtrées pour l'agent ─────────────────────────
    agent_data <- reactive({
      req(data(), input$agent != "")
      df   <- data()
      from <- as.Date(input$period_from)
      to   <- as.Date(input$period_to)
      df   <- df[df$resp_op == input$agent, ]
      # Garder les activités qui chevauchent la période
      if (!is.na(from)) df <- df[df$date_fin   >= from, ]
      if (!is.na(to))   df <- df[df$date_debut <= to,   ]
      df
    })

    # ── Info header ───────────────────────────────────────────
    output$header_info <- renderUI({
      req(input$agent != "")
      tagList(
        tags$strong(icon("user"), " ", input$agent),
        span(class = "text-muted ms-2 small",
          format(as.Date(input$period_from), "%d/%m/%Y"), " → ",
          format(as.Date(input$period_to),   "%d/%m/%Y")
        )
      )
    })

    # ── KPIs ─────────────────────────────────────────────────
    output$kpi_row <- renderUI({
      req(agent_data())
      df   <- agent_data()
      from <- as.Date(input$period_from)
      to   <- as.Date(input$period_to)

      n_activites   <- nrow(df)
      jours_actifs  <- sum(df$duree_jours, na.rm = TRUE)
      periode_jours <- as.numeric(to - from) + 1
      taux_occ      <- if (periode_jours > 0) round(jours_actifs / periode_jours * 100, 1) else 0
      n_projets     <- dplyr::n_distinct(df$Projet)
      n_en_cours    <- sum(df$Statut == "En cours", na.rm = TRUE)

      # Couleur taux d'occupation
      occ_color <- if (taux_occ >= 90) "danger" else if (taux_occ >= 70) "warning" else "success"

      fluidRow(class = "mt-2",
        kpi_box("Activités",         n_activites,           "calendar-check", "#FF0000",
          tip = "Nombre total d'activités planifiées pour cet agent sur la période sélectionnée."),
        kpi_box("Jours planifiés",   jours_actifs,          "hourglass-half", "#00A08A",
          tip = "Somme des durées de toutes les activités (date fin − date début).<br>Attention : les chevauchements sont comptés plusieurs fois."),
        kpi_box("Taux d'occupation", paste0(taux_occ, " %"), "gauge-high",    "#F2AD00",
          tip = paste0("Jours planifiés ÷ jours calendaires de la période × 100.<br>",
                       "Période : ", as.numeric(to - from) + 1, " jours.<br>",
                       "<b>> 90 %</b> : surcharge · <b>70–90 %</b> : chargé · <b>< 70 %</b> : normal.<br>",
                       "Peut dépasser 100 % en cas d'activités simultanées.")),
        kpi_box("Projets distincts", n_projets,             "folder-open",    "#F98400",
          tip = "Nombre de projets différents auxquels l'agent participe sur la période."),
        kpi_box("En cours",          n_en_cours,            "spinner",        "#5BBCD6",
          tip = "Nombre d'activités dont le statut est <b>« En cours »</b> sur la période.")
      )
    })

    # ── Charge mensuelle ──────────────────────────────────────
    output$monthly_load <- renderPlotly({
      req(agent_data(), nrow(agent_data()) > 0)
      df   <- agent_data()
      from <- as.Date(input$period_from)
      to   <- as.Date(input$period_to)

      # Développer chaque activité jour par jour, puis agréger par mois
      rows <- lapply(seq_len(nrow(df)), function(i) {
        d_start <- max(df$date_debut[i], from)
        d_end   <- min(df$date_fin[i],   to)
        if (d_end < d_start) return(NULL)
        jours <- seq(d_start, d_end, by = "day")
        data.frame(
          mois     = format(jours, "%Y-%m"),
          activite = df$activite[i],
          stringsAsFactors = FALSE
        )
      })
      jour_df <- dplyr::bind_rows(rows)
      if (nrow(jour_df) == 0) return(plotly_empty())

      agg <- jour_df %>%
        dplyr::count(mois, activite) %>%
        dplyr::rename(jours = n)

      # Palette activité
      acts  <- unique(agg$activite)
      n_act <- length(acts)
      pal   <- if (n_act <= 12) RColorBrewer::brewer.pal(max(3, n_act), "Set2")[seq_len(n_act)]
               else colorRampPalette(RColorBrewer::brewer.pal(8, "Set2"))(n_act)
      names(pal) <- acts

      p <- plot_ly()
      for (act in acts) {
        sub <- agg[agg$activite == act, ]
        p   <- add_trace(p,
          type   = "bar", x = sub$mois, y = sub$jours,
          name   = act,
          marker = list(color = pal[[act]]),
          hovertemplate = paste0("<b>", act, "</b><br>%{x}<br>%{y} jours<extra></extra>")
        )
      }

      p %>% layout(
        barmode      = "stack",
        xaxis        = list(title = "", tickangle = -30, tickfont = list(size = 10)),
        yaxis        = list(title = "Jours"),
        legend       = list(orientation = "h", y = -0.3, x = 0, font = list(size = 10)),
        plot_bgcolor  = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin        = list(l = 40, r = 10, t = 10, b = 60)
      ) %>%
        config(displaylogo = FALSE,
               modeBarButtons = list(list("zoom2d","pan2d","resetScale2d","toImage")))
    })

    # ── Donut activité ────────────────────────────────────────
    output$pie_activite <- renderPlotly({
      req(agent_data(), nrow(agent_data()) > 0)
      df  <- agent_data()
      agg <- df %>%
        dplyr::group_by(activite) %>%
        dplyr::summarise(jours = sum(duree_jours, na.rm = TRUE), .groups = "drop")

      plot_ly(agg,
        labels = ~activite, values = ~jours,
        type   = "pie", hole = 0.45,
        textinfo = "percent",
        hovertemplate = "<b>%{label}</b><br>%{value} jours (%{percent})<extra></extra>",
        marker = list(colors = RColorBrewer::brewer.pal(max(3, nrow(agg)), "Set2")[seq_len(nrow(agg))])
      ) %>% layout(
        showlegend    = TRUE,
        legend        = list(orientation = "v", font = list(size = 10)),
        plot_bgcolor  = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin        = list(l = 0, r = 0, t = 10, b = 0)
      ) %>%
        config(displaylogo = FALSE)
    })

    # ── Heatmap hebdomadaire ──────────────────────────────────
    output$heatmap_week <- renderPlotly({
      req(agent_data(), nrow(agent_data()) > 0)
      df   <- agent_data()
      from <- as.Date(input$period_from)
      to   <- as.Date(input$period_to)

      # Développer jour par jour
      rows <- lapply(seq_len(nrow(df)), function(i) {
        d_start <- max(df$date_debut[i], from)
        d_end   <- min(df$date_fin[i],   to)
        if (d_end < d_start) return(NULL)
        jours <- seq(d_start, d_end, by = "day")
        data.frame(
          semaine = as.numeric(format(jours, "%V")),
          annee   = as.numeric(format(jours, "%G")),   # ISO year
          jour_s  = as.numeric(format(jours, "%u")),   # 1 Mon … 7 Sun
          stringsAsFactors = FALSE
        )
      })
      jour_df <- dplyr::bind_rows(rows)
      if (nrow(jour_df) == 0) return(plotly_empty())

      agg <- jour_df %>%
        dplyr::count(semaine, jour_s) %>%
        dplyr::rename(n_act = n)

      # Pivoter : semaine en x, jour en y
      jours_labels <- c("Lun","Mar","Mer","Jeu","Ven","Sam","Dim")
      agg$jour_label <- factor(jours_labels[agg$jour_s], levels = rev(jours_labels))

      plot_ly(agg,
        x = ~semaine, y = ~jour_label, z = ~n_act,
        type      = "heatmap",
        colorscale = list(
          list(0, "#f0f9ff"),
          list(0.3, "#7dd3fc"),
          list(0.7, "#0369a1"),
          list(1,   "#0c2340")
        ),
        hovertemplate = "Semaine %{x}, %{y}<br>%{z} activité(s)<extra></extra>",
        showscale = TRUE,
        colorbar  = list(title = "", thickness = 12, len = 0.8)
      ) %>% layout(
        xaxis        = list(title = "Semaine", tickfont = list(size = 10)),
        yaxis        = list(title = "", tickfont = list(size = 10)),
        plot_bgcolor  = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin        = list(l = 50, r = 60, t = 10, b = 40)
      ) %>%
        config(displaylogo = FALSE)
    })

    # ── Donut statut ──────────────────────────────────────────
    output$pie_statut <- renderPlotly({
      req(agent_data(), nrow(agent_data()) > 0)
      df  <- agent_data()
      agg <- df %>%
        dplyr::count(Statut) %>%
        dplyr::rename(nb = n)

      pal_statut <- c(
        "Validée"    = "#22c55e",
        "En cours"   = "#3b82f6",
        "En attente" = "#f59e0b",
        "Annulée"    = "#ef4444",
        "Terminée"   = "#8b5cf6"
      )
      colors <- unname(pal_statut[agg$Statut])
      colors[is.na(colors)] <- "#94a3b8"

      plot_ly(agg,
        labels = ~Statut, values = ~nb,
        type   = "pie", hole = 0.45,
        textinfo = "percent",
        hovertemplate = "<b>%{label}</b><br>%{value} activité(s)<extra></extra>",
        marker = list(colors = colors)
      ) %>% layout(
        showlegend    = TRUE,
        legend        = list(orientation = "v", font = list(size = 10)),
        plot_bgcolor  = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin        = list(l = 0, r = 0, t = 10, b = 0)
      ) %>%
        config(displaylogo = FALSE)
    })

    # ── Tableau détaillé ──────────────────────────────────────
    output$table_badge <- renderUI({
      req(agent_data())
      span(class = "badge bg-secondary", nrow(agent_data()), "activités")
    })

    output$detail_table <- renderDT({
      req(agent_data())
      df <- agent_data() %>%
        dplyr::arrange(date_debut) %>%
        dplyr::select(
          Numéro, date_debut, date_fin, duree_jours,
          activite, Projet, Statut, description_courte
        ) %>%
        dplyr::rename(
          "Début"       = date_debut,
          "Fin"         = date_fin,
          "Durée (j)"   = duree_jours,
          "Activité"    = activite,
          "Description" = description_courte
        )

      datatable(df,
        options = list(
          pageLength = 10,
          scrollX    = TRUE,
          language   = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/fr-FR.json"),
          columnDefs = list(list(targets = 7, width = "300px"))
        ),
        rownames  = FALSE,
        selection = "none",
        class     = "compact stripe hover"
      ) %>%
        formatDate(c("Début", "Fin"), method = "toLocaleDateString") %>%
        formatStyle("Statut",
          backgroundColor = styleEqual(
            c("Validée","En cours","En attente","Annulée","Terminée"),
            c("#dcfce7","#dbeafe","#fef9c3","#fee2e2","#ede9fe")
          )
        )
    })

    # ── Export CSV ────────────────────────────────────────────
    output$dl_csv <- downloadHandler(
      filename = function() {
        paste0("agent_", gsub(" ", "_", input$agent), "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        df   <- agent_data()
        cols <- intersect(
          c("Numéro","resp_op","date_debut","date_fin","duree_jours",
            "activite","Projet","Statut","equipe_ue","description"),
          colnames(df)
        )
        write.csv(df[, cols], file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}

# ── Helper KPI box ──────────────────────────────────────────
kpi_box <- function(title, value, icon_name, color = "primary", tip = NULL) {
  if (startsWith(as.character(color), "#")) {
    card_class <- "card mb-2"
    card_style <- paste0("background-color:", color, "; color:white;")
  } else {
    card_class <- paste0("card text-bg-", color, " mb-2")
    card_style <- NULL
  }
  column(
    width = 2,
    div(class = card_class, style = card_style,
      div(class = "card-body py-2 px-3 d-flex justify-content-between align-items-center",
        div(
          div(class = "fs-5 fw-bold", value),
          div(class = "small opacity-75 d-flex align-items-center gap-1",
            title,
            if (!is.null(tip))
              tags$span(
                style               = "cursor:help; opacity:0.7;",
                `data-bs-toggle`    = "tooltip",
                `data-bs-placement` = "bottom",
                `data-bs-html`      = "true",
                title               = tip,
                icon("circle-question", style = "font-size:0.9em;")
              )
          )
        ),
        icon(icon_name, class = "fa-2x opacity-40")
      )
    )
  )
}
