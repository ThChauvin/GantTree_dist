# ============================================================
# install_deps.R
# Script d'installation des dépendances GantTree
#
# USAGE :
#   Mode développement  → source("install_deps.R")
#   Mode distribution   → Rscript install_deps.R --portable
# ============================================================

cat("=================================================\n")
cat("  GantTree — Installation des dépendances\n")
cat("=================================================\n\n")

# ── Détection du mode (dev vs portable) ───────────────────
args     <- commandArgs(trailingOnly = TRUE)
portable <- "--portable" %in% args

if (portable) {
  # En mode Rscript, on récupère le chemin du script via commandArgs(FALSE)
  all_args    <- commandArgs(trailingOnly = FALSE)
  file_flag   <- grep("^--file=", all_args, value = TRUE)

  if (length(file_flag) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_flag[1]), mustWork = FALSE)
    script_dir  <- dirname(script_path)
  } else {
    # Fallback : répertoire courant
    script_dir <- normalizePath(".", mustWork = FALSE)
  }

  lib_path <- file.path(script_dir, "R", "library")

  if (!dir.exists(lib_path)) {
    cat("ERREUR : Dossier R/library introuvable.\n")
    cat("Attendu :", lib_path, "\n")
    quit(status = 1)
  }

  cat("Mode : installation portable\n")
  cat("Cible :", lib_path, "\n\n")
  .libPaths(c(lib_path, .libPaths()))

} else {
  lib_path <- .libPaths()[1]
  cat("Mode : installation développement\n")
  cat("Cible :", lib_path, "\n\n")
}

# ── Dépôt CRAN ────────────────────────────────────────────
options(repos = c(CRAN = "https://cloud.r-project.org"))

# ── Liste des packages requis ─────────────────────────────
packages <- list(
  list(pkg = "shiny",        version = "1.7.0",  desc = "Framework Shiny"),
  list(pkg = "bslib",        version = "0.5.0",  desc = "Thème Bootstrap"),
  list(pkg = "shinyWidgets", version = "0.7.0",  desc = "Widgets Shiny étendus"),
  list(pkg = "DT",           version = "0.28",   desc = "Tableaux DataTables"),
  list(pkg = "plotly",       version = "4.10.0", desc = "Graphiques interactifs"),
  list(pkg = "RColorBrewer", version = "1.1-3",  desc = "Palettes de couleurs"),
  list(pkg = "wesanderson",  version = "0.3.6",  desc = "Palette Darjeeling Limited"),
  list(pkg = "dplyr",        version = "1.1.0",  desc = "Manipulation de données"),
  list(pkg = "tidyr",        version = "1.3.0",  desc = "Mise en forme des données"),
  list(pkg = "lubridate",    version = "1.9.0",  desc = "Gestion des dates"),
  list(pkg = "stringr",      version = "1.5.0",  desc = "Manipulation de chaînes"),
  list(pkg = "readxl",       version = "1.4.0",  desc = "Lecture fichiers Excel"),
  list(pkg = "readr",        version = "2.1.0",  desc = "Lecture fichiers CSV"),
  list(pkg = "openxlsx",     version = "4.2.5",  desc = "Export fichiers Excel")
)

# ── Fonction d'installation ────────────────────────────────
install_if_needed <- function(pkg, min_version, desc) {
  installed <- tryCatch(packageVersion(pkg), error = function(e) NULL)

  if (is.null(installed)) {
    cat(sprintf("  [INSTALL] %-15s %s\n", pkg, desc))
    install.packages(pkg, lib = lib_path, quiet = FALSE)
  } else if (installed < package_version(min_version)) {
    cat(sprintf("  [UPDATE ] %-15s v%s -> v%s\n", pkg,
                as.character(installed), min_version))
    install.packages(pkg, lib = lib_path, quiet = FALSE)
  } else {
    cat(sprintf("  [OK    ] %-15s v%s\n", pkg, as.character(installed)))
  }
}

# ── Installation ──────────────────────────────────────────
cat("Vérification et installation des packages...\n")
cat("-------------------------------------------------\n")

ok        <- c()
installed <- c()
failed    <- c()

for (p in packages) {
  tryCatch({
    before <- tryCatch(packageVersion(p$pkg), error = function(e) NULL)
    install_if_needed(p$pkg, p$version, p$desc)
    after  <- tryCatch(packageVersion(p$pkg), error = function(e) NULL)
    if (is.null(before) && !is.null(after)) {
      installed <- c(installed, p$pkg)
    } else {
      ok <- c(ok, p$pkg)
    }
  }, error = function(e) {
    cat(sprintf("  [ERREUR] %-15s %s\n", p$pkg, conditionMessage(e)))
    failed <<- c(failed, p$pkg)
  })
}

# ── Résumé ────────────────────────────────────────────────
cat("\n=================================================\n")
cat("  Résumé\n")
cat("=================================================\n")
cat(sprintf("  Déjà installés  : %d package(s)\n", length(ok)))
cat(sprintf("  Nouvellement    : %d package(s)\n", length(installed)))
cat(sprintf("  Échecs          : %d package(s)\n", length(failed)))

if (length(installed) > 0) {
  cat("\n  Packages installés :\n")
  for (p in installed) cat(sprintf("    + %s\n", p))
}

if (length(failed) > 0) {
  cat("\n  Packages en erreur :\n")
  for (p in failed) cat(sprintf("    x %s\n", p))
  cat("\n  Relancez le script ou installez-les manuellement.\n")
  quit(status = 1)
} else {
  cat("\n  Toutes les dependances sont pretes.\n")
}
cat("=================================================\n")
