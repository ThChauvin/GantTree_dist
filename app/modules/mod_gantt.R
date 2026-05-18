# ============================================================
# Module : mod_gantt
# ============================================================

mod_gantt_ui <- function(id) {
  ns <- NS(id)
  div(class = "container-fluid mt-3",
    fluidRow(
      column(3,
        card(
          card_header(icon("sliders"), " Filtres"),
          card_body(class = "p-2",
            h6(class = "text-muted mt-1", "Periode"),
            dateInput(ns("date_from"), "Du :", value = Sys.Date() - 30),
            dateInput(ns("date_to"),   "Au :", value = Sys.Date() + 180),
            actionButton(ns("reset_dates"), "Plage auto",
                         class = "btn-sm btn-outline-secondary w-100 mb-2",
                         icon  = icon("arrows-left-right")),
            hr(),
            h6(class = "text-muted", "Affichage"),
            selectInput(ns("group_by"), "Grouper les barres par",
              choices = c(
                "Responsable" = "resp_op",
                "Activite"    = "activite",
                "Projet"      = "Projet",
                "Equipe/Pole" = "equipe_ue",
                "Statut"      = "Statut"
              ), selected = "activite"
            ),
            selectInput(ns("color_by"), "Colorier par",
              choices = c(
                "Activite"    = "activite",
                "Responsable" = "resp_op",
                "Projet"      = "Projet",
                "Statut"      = "Statut"
              ), selected = "resp_op"
            ),
            hr(),
            h6(class = "text-muted", "Filtres"),
            uiOutput(ns("filter_resp")),
            uiOutput(ns("filter_activite")),
            uiOutput(ns("filter_statut")),
            uiOutput(ns("filter_projet")),
            hr(),
            selectInput(ns("sort_by"), "Trier par",
              choices = c(
                "Date de debut" = "date_debut",
                "Responsable"   = "resp_op",
                "Duree (long)"  = "duree_desc",
                "Duree (court)" = "duree_asc"
              )
            ),
            hr(),
            downloadButton(ns("dl_csv"), "Exporter CSV filtre",
                           class = "btn-sm btn-outline-secondary w-100")
          )
        )
      ),
      column(9,
        card(
          card_header(
            div(class = "d-flex justify-content-between align-items-center",
              span(icon("chart-gantt"), " Diagramme de Gantt"),
              uiOutput(ns("gantt_info"))
            )
          ),
          card_body(class = "p-0",
            uiOutput(ns("no_data_ui")),
            plotlyOutput(ns("gantt_plot"), height = "650px")
          )
        ),
        card(class = "mt-2",
          card_header(icon("circle-info"), " Detail de l'activite selectionnee"),
          card_body(uiOutput(ns("detail_ui")))
        )
      )
    )
  )
}

mod_gantt_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    observe({
      req(data())
      df <- data()
      output$filter_resp <- renderUI({
        ch <- sort(unique(df$resp_op))
        selectizeInput(ns("sel_resp"), "Responsable(s) :", choices = ch, selected = ch,
          multiple = TRUE, options = list(plugins = list("remove_button")))
      })
      output$filter_activite <- renderUI({
        ch <- sort(unique(df$activite))
        selectizeInput(ns("sel_activite"), "Activite(s) :", choices = ch, selected = ch,
          multiple = TRUE, options = list(plugins = list("remove_button")))
      })
      output$filter_statut <- renderUI({
        ch <- sort(unique(df$Statut))
        selectizeInput(ns("sel_statut"), "Statut(s) :", choices = ch, selected = ch,
          multiple = TRUE, options = list(plugins = list("remove_button")))
      })
      output$filter_projet <- renderUI({
        ch <- sort(unique(df$Projet))
        selectizeInput(ns("sel_projet"), "Projet(s) :", choices = ch, selected = ch,
          multiple = TRUE, options = list(plugins = list("remove_button")))
      })
    })

    observeEvent(input$reset_dates, {
      req(data())
      df <- data()
      updateDateInput(session, "date_from", value = min(df$date_debut, na.rm = TRUE) - 7)
      updateDateInput(session, "date_to",   value = max(df$date_fin,   na.rm = TRUE) + 7)
    })

    filtered <- reactive({
      req(data())
      df <- data()
      if (!is.null(input$sel_resp)     && length(input$sel_resp)     > 0) df <- df[df$resp_op  %in% input$sel_resp, ]
      if (!is.null(input$sel_activite) && length(input$sel_activite) > 0) df <- df[df$activite %in% input$sel_activite, ]
      if (!is.null(input$sel_statut)   && length(input$sel_statut)   > 0) df <- df[df$Statut   %in% input$sel_statut, ]
      if (!is.null(input$sel_projet)   && length(input$sel_projet)   > 0) df <- df[df$Projet   %in% input$sel_projet, ]
      from <- as.Date(input$date_from)
      to   <- as.Date(input$date_to)
      if (!is.na(from)) df <- df[df$date_fin   >= from, ]
      if (!is.na(to))   df <- df[df$date_debut <= to,   ]
      key <- if (!is.null(input$sort_by)) input$sort_by else "date_debut"
      switch(key,
        "date_debut" = df[order(df$date_debut), ],
        "resp_op"    = df[order(df$resp_op, df$date_debut), ],
        "duree_desc" = df[order(-df$duree_jours), ],
        "duree_asc"  = df[order(df$duree_jours), ],
        df
      )
    })

    output$gantt_info <- renderUI({
      req(filtered())
      tagList(
        span(class = "badge bg-primary me-1", nrow(filtered()), "activites"),
        span(class = "badge bg-secondary", n_distinct(filtered()$resp_op), "responsables")
      )
    })

    output$no_data_ui <- renderUI({
      if (is.null(data()))
        div(class = "alert alert-info m-3", icon("lightbulb"),
          " Chargez un fichier dans l'onglet Import.")
      else if (nrow(filtered()) == 0)
        div(class = "alert alert-warning m-3", icon("triangle-exclamation"),
          " Aucune activite ne correspond aux filtres.")
    })

    gantt_colors <- reactive({
      req(filtered())
      df    <- filtered()
      col_f <- if (!is.null(input$color_by) && input$color_by %in% colnames(df)) input$color_by else "activite"
      vals  <- unique(df[[col_f]])
      n     <- length(vals)
      pal   <- if (n <= 12) RColorBrewer::brewer.pal(max(3, n), "Set3")[seq_len(n)]
               else colorRampPalette(RColorBrewer::brewer.pal(12, "Set3"))(n)
      setNames(pal, vals)
    })

    output$gantt_plot <- renderPlotly({
      req(filtered(), nrow(filtered()) > 0)

      df    <- filtered()
      grp   <- if (!is.null(input$group_by) && input$group_by %in% colnames(df)) input$group_by else "resp_op"
      col_f <- if (!is.null(input$color_by) && input$color_by %in% colnames(df)) input$color_by else "activite"
      pal   <- gantt_colors()

      df$y_label <- paste0(df[[grp]], " [", df$Numéro, "]")

      df$tip <- paste0(
        "<b>#", df$Numéro, "</b><br>",
        "Resp : ", df$resp_op, "<br>",
        "Debut : ", format(df$date_debut, "%d/%m/%Y"),
        " > Fin : ", format(df$date_fin, "%d/%m/%Y"), "<br>",
        "Duree : ", df$duree_jours, " jours<br>",
        "Activite : ", df$activite, "<br>",
        "Projet : ", df$Projet
      )

      # Cle : on passe date_debut comme base (string ISO) et date_fin comme x (string ISO).
      # Plotly avec type="date" interprete x et base comme des dates et dessine
      # une barre de largeur = date_fin - date_debut. Pas de conversion numerique.
      # df$d_start <- format(df$date_debut, "%Y-%m-%d")
      # df$d_end   <- format(df$date_fin,   "%Y-%m-%d")
      df$d_start    <- format(df$date_debut, "%Y-%m-%d")
      df$d_end      <- format(df$date_fin,   "%Y-%m-%d")
      # Durée en millisecondes (ce que Plotly attend pour l'axe type="date")
      df$duree_ms   <- as.numeric(df$date_fin - df$date_debut) * 86400 * 1000
      
      p <- plot_ly()
      for (cv in unique(df[[col_f]])) {
        sub <- df[df[[col_f]] == cv, , drop = FALSE]
        if (nrow(sub) == 0) next
        p <- add_trace(p,
          type          = "bar",
          orientation   = "h",
          x             = sub$duree_ms,
          base          = sub$d_start,
          y             = sub$y_label,
          name          = as.character(cv),
          marker        = list(color = pal[[as.character(cv)]],
                               line  = list(color = "white", width = 0.8)),
          text          = sub$tip,
          hovertemplate = "%{text}<extra></extra>",
          showlegend    = TRUE
        )
      }

      today <- format(Sys.Date(), "%Y-%m-%d")
      xmin  <- format(as.Date(input$date_from), "%Y-%m-%d")
      xmax  <- format(as.Date(input$date_to),   "%Y-%m-%d")

      p %>%
        layout(
          barmode = "overlay",
          xaxis = list(type = "date", range = c(xmin, xmax),
                       tickformat = "%b %Y", title = "",
                       gridcolor = "rgba(0,0,0,0.07)"),
          yaxis = list(title = "",
                       categoryorder = "array",
                       categoryarray = rev(unique(df$y_label)),
                       tickfont = list(size = 11),
                       gridcolor = "rgba(0,0,0,0.05)"),
          legend = list(title = list(text = paste0("<b>", col_f, "</b>")),
                        orientation = "h", y = -0.15, x = 0),
          plot_bgcolor  = "rgba(0,0,0,0)",
          paper_bgcolor = "rgba(0,0,0,0)",
          margin = list(l = 10, r = 10, t = 20, b = 80),
          shapes = list(list(
            type = "line", xref = "x", yref = "paper",
            x0 = today, x1 = today, y0 = 0, y1 = 1,
            line = list(color = "red", width = 1.5, dash = "dot")
          )),
          annotations = list(list(
            x = today, y = 1, xref = "x", yref = "paper",
            text = "Aujourd'hui", showarrow = FALSE,
            font = list(color = "red", size = 10),
            xanchor = "left", yanchor = "top"
          ))
        ) %>%
        config(displaylogo = FALSE,
               modeBarButtons = list(list("zoom2d","pan2d","zoomIn2d","zoomOut2d","resetScale2d","toImage")),
               toImageButtonOptions = list(format = "png", filename = "gantt", scale = 2))
    })

    output$detail_ui <- renderUI({
      ev <- event_data("plotly_click", source = ns("gantt_plot"))
      if (is.null(ev))
        return(p(class = "text-muted", "Cliquez sur une barre pour voir le detail."))

      df    <- filtered()
      col_f <- if (!is.null(input$color_by) && input$color_by %in% colnames(df)) input$color_by else "activite"
      grp   <- if (!is.null(input$group_by) && input$group_by %in% colnames(df)) input$group_by else "resp_op"
      cv_sel      <- unique(df[[col_f]])[ev$curveNumber + 1]
      sub         <- df[df[[col_f]] == cv_sel, , drop = FALSE]
      sub$y_label <- paste0(sub[[grp]], " [", sub$Numéro, "]")
      row_idx     <- which(sub$y_label == ev$y)
      if (length(row_idx) == 0)
        return(p(class = "text-muted", "Activite non identifiee."))
      row <- sub[row_idx[1], ]

      div(class = "row",
        column(6, tags$dl(class = "row",
          dt_dd("Numero",      row$Numéro),
          dt_dd("Responsable", row$resp_op),
          dt_dd("Activite",    row$activite),
          dt_dd("Projet",      row$Projet),
          dt_dd("Statut",      row$Statut)
        )),
        column(6, tags$dl(class = "row",
          dt_dd("Debut",       format(row$date_debut, "%d/%m/%Y")),
          dt_dd("Fin",         format(row$date_fin,   "%d/%m/%Y")),
          dt_dd("Duree",       paste(row$duree_jours, "jours")),
          dt_dd("Estimation",  paste(row[["Estimation temps"]], "j/h"))
        )),
        column(12, tags$dl(class = "row",
          tags$dt(class = "col-sm-2", "Description"),
          tags$dd(class = "col-sm-10",
            if (!is.null(row$description) && !is.na(row$description)) row$description else "-")
        ))
      )
    })

    output$dl_csv <- downloadHandler(
      filename = function() paste0("gantt_", Sys.Date(), ".csv"),
      content  = function(file) {
        df   <- filtered()
        cols <- intersect(c("Numéro","resp_op","date_debut","date_fin","duree_jours",
                             "activite","Projet","Statut","equipe_ue","description"),
                          colnames(df))
        write.csv(df[, cols], file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}

dt_dd <- function(label, value) {
  val <- tryCatch(if (is.na(value) || value == "") "-" else as.character(value),
                  error = function(e) as.character(value))
  tagList(
    tags$dt(class = "col-sm-4 text-muted", label),
    tags$dd(class = "col-sm-8", val)
  )
}
