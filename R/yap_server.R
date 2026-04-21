# ---------------------------------------------------------------------------
# Local YAP server lifecycle
#
# YAP is a Go program that runs as a local HTTP server:
#   ./yap api
# listens on 127.0.0.1:8000 by default. This file handles:
#   * yap_doctor()   -- diagnose prerequisites (git, git-lfs, go, disk)
#   * yap_install()  -- one-command clone + LFS pull + model extract + build
#   * yap_start()    -- launch the local server as a background process
#   * yap_stop()     -- stop a server we launched
#   * yap_ping()     -- is a server answering on the URL?
#   * yap_status()   -- show what the package thinks is going on
#   * yap_available()-- TRUE iff ping succeeds
#
# NOTE: on Windows, building YAP natively does not currently produce a working
# Hebrew tokenizer. Use WSL instead. yap_install()/yap_start() therefore assume
# a Linux or macOS host. On Windows, build YAP inside WSL and skip those
# helpers; yap_parse() is all you need from R.
# ---------------------------------------------------------------------------

#' Diagnose YAP-install prerequisites
#'
#' Checks the common prereqs for installing YAP: git, git-lfs, Go, disk space.
#' YAP does not always use Git LFS, but having it installed is harmless and
#' some forks do rely on it; we keep the check for safety.
#'
#' @param dest Destination directory to check for free space. Default is the
#'   same default as \code{\link{yap_install}}.
#' @return Invisible list with logical fields \code{git}, \code{git_lfs},
#'   \code{go}, \code{space_ok}, plus \code{go_version}, \code{lfs_version},
#'   \code{space_gb}, and \code{issues}.
#' @export
yap_doctor <- function(dest = file.path("~", "yap")) {
  dest <- normalizePath(dest, mustWork = FALSE)

  has_git <- nzchar(Sys.which("git"))

  has_lfs <- FALSE
  lfs_version <- NA_character_
  if (has_git) {
    lfs_try <- tryCatch(
      suppressWarnings(system2("git", c("lfs", "--version"),
                               stdout = TRUE, stderr = TRUE)),
      error = function(e) character()
    )
    if (length(lfs_try) && any(grepl("git-lfs", lfs_try))) {
      has_lfs <- TRUE
      lfs_version <- lfs_try[1]
    }
  }

  has_go <- nzchar(Sys.which("go"))
  go_version <- NA_character_
  if (has_go) {
    gv <- tryCatch(
      suppressWarnings(system2("go", "version",
                               stdout = TRUE, stderr = TRUE)),
      error = function(e) character()
    )
    if (length(gv)) go_version <- gv[1]
  }

  space_gb <- NA_real_
  space_ok <- NA
  parent <- dirname(dest)
  if (dir.exists(parent) && !.is_windows()) {
    space_gb <- tryCatch({
      out <- suppressWarnings(system2(
        "df", c("-Pk", shQuote(parent)),
        stdout = TRUE, stderr = FALSE
      ))
      if (length(out) >= 2) {
        parts <- strsplit(trimws(out[2]), "\\s+")[[1]]
        kb <- suppressWarnings(as.numeric(parts[4]))
        if (!is.na(kb)) kb / (1024 * 1024) else NA_real_
      } else NA_real_
    }, error = function(e) NA_real_)
    space_ok <- is.na(space_gb) || space_gb >= 1.5
  }

  issues <- character()
  if (!has_git) issues <- c(issues,
    "git not found on PATH. Install from https://git-scm.com/downloads.")
  if (!has_lfs) issues <- c(issues,
    "git-lfs not found. Install from https://git-lfs.com (often not required for YAP but harmless to have).")
  if (!has_go)  issues <- c(issues,
    "Go toolchain not found. Install Go (>= 1.17) from https://go.dev/doc/install.")
  if (isFALSE(space_ok)) issues <- c(issues,
    sprintf("Only ~%.1f GB free under %s; YAP + models need ~1.5 GB.",
            space_gb, parent))
  if (.is_windows()) issues <- c(issues,
    "You are on Windows. As of 2026 YAP built natively on Windows does not produce a working Hebrew tokenizer; use WSL. See README.")

  .check_line <- function(label, ok, detail = "") {
    mark <- if (isTRUE(ok)) "[ok]" else if (isFALSE(ok)) "[--]" else "[??]"
    paste0("  ", mark, " ", label,
           if (nzchar(detail)) paste0("   ", detail) else "")
  }
  message("yap_doctor():")
  message(.check_line("git",      has_git))
  message(.check_line("git-lfs",  has_lfs,
                      if (!is.na(lfs_version)) lfs_version else ""))
  message(.check_line("go",       has_go,
                      if (!is.na(go_version))  go_version  else ""))
  message(.check_line("disk",     space_ok,
                      if (!is.na(space_gb))
                        sprintf("~%.1f GB free in %s", space_gb, parent)
                      else ""))
  if (length(issues)) {
    message("\nIssues / notes before yap_install():")
    for (x in issues) message("  - ", x)
  } else {
    message("\nAll prerequisites look good. You can call yap_install().")
  }

  invisible(list(
    git         = has_git,
    git_lfs     = has_lfs,
    go          = has_go,
    go_version  = go_version,
    lfs_version = lfs_version,
    space_gb    = space_gb,
    space_ok    = space_ok,
    issues      = issues
  ))
}

#' Install YAP locally (clone + LFS pull + model extract + build)
#'
#' One-command local install. Clones YAP, pulls the model data through Git
#' LFS if the repo uses it, decompresses the \code{.bz2} model archives, and
#' builds the \code{yap} binary. Intended for Linux/macOS hosts.
#'
#' On Windows, do not use this; build YAP inside WSL as documented in the
#' README. This function will still run, but the resulting binary will not
#' tokenize Hebrew correctly on Windows.
#'
#' @param dest Directory to install into. Default \code{"~/yap"}.
#' @param repo Git URL of the YAP repository.
#' @param branch Branch or tag to check out. Default \code{"master"}.
#' @param layout Either \code{"flat"} (default) or \code{"gopath"}.
#' @param overwrite If \code{TRUE}, remove \code{dest} first.
#' @param skip_doctor If \code{TRUE}, skip the prerequisite check.
#' @param build If \code{FALSE}, clone and decompress data but do not run
#'   \code{go build}.
#'
#' @return Invisible path to the YAP install directory.
#' @export
yap_install <- function(dest = file.path("~", "yap"),
                        repo = "https://github.com/OnlpLab/yap.git",
                        branch = "master",
                        layout = c("flat", "gopath"),
                        overwrite = FALSE,
                        skip_doctor = FALSE,
                        build = TRUE) {

  layout <- match.arg(layout)
  dest   <- normalizePath(dest, mustWork = FALSE)

  if (!skip_doctor) {
    diag <- yap_doctor(dest)
    needed <- c("git")
    if (build) needed <- c(needed, "go")
    missing <- needed[!unlist(diag[needed])]
    if (length(missing)) {
      stop("yap_install prerequisites missing: ",
           paste(missing, collapse = ", "),
           ". Fix the issues listed by yap_doctor() and retry, or pass ",
           "skip_doctor = TRUE to bypass this check.", call. = FALSE)
    }
  }

  clone_dir <- switch(
    layout,
    flat   = dest,
    gopath = file.path(dest, "src", "yap")
  )

  if (overwrite && dir.exists(dest)) {
    message("Removing existing install at ", dest, " ...")
    unlink(dest, recursive = TRUE, force = TRUE)
  }
  dir.create(dirname(clone_dir), showWarnings = FALSE, recursive = TRUE)

  already_cloned <- dir.exists(file.path(clone_dir, ".git"))
  if (!already_cloned) {
    if (dir.exists(clone_dir) && length(list.files(clone_dir))) {
      stop("Target directory ", clone_dir, " is not empty and is not a git ",
           "clone. Pass overwrite = TRUE or choose a different dest.",
           call. = FALSE)
    }
    message("Cloning ", repo, " -> ", clone_dir, " ...")
    ok <- system2("git", c("clone", "--branch", branch,
                           shQuote(repo), shQuote(clone_dir)))
    if (ok != 0) stop("git clone failed (exit ", ok, ").", call. = FALSE)
  } else {
    message("Reusing existing clone at ", clone_dir, ".")
  }

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(clone_dir)

  # LFS is optional in YAP; best-effort pull.
  system2("git", c("lfs", "install", "--local"))
  system2("git", c("lfs", "pull"))

  # Extract .bz2 model archives in place. base R handles bzip2 natively.
  .decompress_yap_bz2(file.path(clone_dir, "data"))

  data_dir <- file.path(clone_dir, "data")
  if (dir.exists(data_dir)) {
    bad <- .detect_lfs_pointers(data_dir)
    if (length(bad)) {
      stop("After `git lfs pull`, these files still look like LFS ",
           "pointer stubs:\n  ",
           paste(utils::head(bad, 5), collapse = "\n  "),
           if (length(bad) > 5)
             sprintf("\n  ... and %d more.", length(bad) - 5)
           else "",
           "\nRun `git lfs install` once system-wide, then retry with ",
           "overwrite = TRUE.", call. = FALSE)
    }
  } else {
    warning("Clone has no data/ directory; is this really the YAP repo?",
            call. = FALSE)
  }

  if (!build) {
    message("Skipped build (build = FALSE).")
    return(invisible(clone_dir))
  }

  old_gopath <- Sys.getenv("GOPATH", unset = NA)
  on.exit({
    if (is.na(old_gopath)) Sys.unsetenv("GOPATH")
    else Sys.setenv(GOPATH = old_gopath)
  }, add = TRUE)
  if (layout == "gopath") Sys.setenv(GOPATH = dest)

  # YAP predates Go modules and ships with a stale vendor/. Drop vendor and
  # synthesize go.mod if needed. Pin gonuts/commander to the last pre-stdlib
  # flag commit.
  unlink("vendor", recursive = TRUE, force = TRUE)
  if (!file.exists("go.mod")) {
    message("No go.mod; initializing module (`go mod init yap`) ...")
    system2("go", c("mod", "init", "yap"))
  }
  message("Pinning gonuts/commander to a pre-stdlib-flag commit ...")
  system2("go", c("get", "github.com/gonuts/commander@91a7f0a"))
  system2("go", c("mod", "tidy"))

  message("Building YAP with `go build .` ...")
  ok <- system2("go", c("build", "."))
  if (!is.numeric(ok) || ok != 0) {
    stop("go build failed (exit ", ok,
         "). On Windows this is expected; use WSL instead (see README). ",
         "On Linux/macOS, paste the build output above and inspect.",
         call. = FALSE)
  }

  bin <- if (.is_windows()) "yap.exe" else "yap"
  if (!file.exists(file.path(clone_dir, bin))) {
    stop("Build finished but '", bin, "' was not produced in ", clone_dir,
         ".", call. = FALSE)
  }

  message("\n[+] YAP installed.")
  message("    binary : ", file.path(clone_dir, bin))
  message("    data   : ", data_dir)
  message("    next   : yap_start(\"", clone_dir, "\")")
  invisible(clone_dir)
}

# Extract YAP's .bz2 model archives to sibling files without the .bz2 suffix.
.decompress_yap_bz2 <- function(data_dir) {
  if (!dir.exists(data_dir)) return(invisible())
  bz_files <- list.files(data_dir, pattern = "\\.bz2$",
                         recursive = TRUE, full.names = TRUE)
  if (!length(bz_files)) return(invisible())
  for (f in bz_files) {
    out <- sub("\\.bz2$", "", f)
    if (file.exists(out)) next
    message("Extracting ", basename(f), " ...")
    con_in  <- bzfile(f, "rb")
    con_out <- file(out, "wb")
    tryCatch({
      while (length(chunk <- readBin(con_in, "raw", 1e6)) > 0) {
        writeBin(chunk, con_out)
      }
    }, finally = {
      close(con_in); close(con_out)
    })
  }
  invisible()
}

# Detect LFS pointer stubs under a directory.
.detect_lfs_pointers <- function(dir) {
  files <- list.files(dir, recursive = TRUE, full.names = TRUE)
  sizes <- file.info(files)$size
  small <- files[!is.na(sizes) & sizes < 200]
  bad <- character()
  for (f in small) {
    con <- tryCatch(file(f, "rb"), error = function(e) NULL)
    if (is.null(con)) next
    raw <- readBin(con, "raw", n = 64)
    close(con)
    txt <- rawToChar(raw[raw != as.raw(0)])
    if (startsWith(txt, "version https://git-lfs")) bad <- c(bad, f)
  }
  bad
}

#' Start a local YAP server
#'
#' Launches \code{./yap api} as a background process and polls until it
#' responds. Requires the \pkg{processx} package. Assumes a Linux or macOS
#' host with a working \code{yap} binary; on Windows use WSL and skip this.
#'
#' @param yap_path Directory containing the built \code{yap} executable and
#'   its \code{data/} folder.
#' @param port Port to listen on. Default 8000.
#' @param host Host/interface to bind to. Default \code{"127.0.0.1"}.
#' @param timeout Seconds to wait for the server to become responsive.
#' @param quiet If \code{TRUE}, suppress stdout/stderr.
#' @param extra_args Optional extra args passed after \code{api}.
#'
#' @return \code{yap_server} object.
#' @export
yap_start <- function(yap_path,
                      port = 8000L,
                      host = "127.0.0.1",
                      timeout = 180,
                      quiet = TRUE,
                      extra_args = character()) {
  .require_pkg("processx", "to launch the local YAP server")

  yap_path <- normalizePath(yap_path, mustWork = TRUE)
  bin_name <- if (.is_windows()) "yap.exe" else "yap"
  bin <- file.path(yap_path, bin_name)
  if (!.is_file(bin)) {
    stop("No '", bin_name, "' executable found in ", yap_path,
         ".\n",
         "  * If you haven't installed YAP yet, run yap_doctor() then yap_install().\n",
         "  * On Windows, build YAP inside WSL (see README) and do not call yap_start() from R; run './yap api' in Ubuntu.",
         call. = FALSE)
  }
  if (!dir.exists(file.path(yap_path, "data"))) {
    warning("No data/ directory under ", yap_path,
            ". YAP will fail to load its Hebrew models.", call. = FALSE)
  }

  args <- c("api", extra_args)
  if (!identical(port, 8000L) || !identical(host, "127.0.0.1")) {
    args <- c(args, sprintf("-addr=%s:%d", host, port))
  }

  message("Starting YAP: ", bin, " ", paste(args, collapse = " "))
  proc <- processx::process$new(
    command = bin,
    args    = args,
    wd      = yap_path,
    stdout  = if (quiet) "|" else "",
    stderr  = if (quiet) "|" else "",
    supervise = TRUE
  )

  url <- sprintf("http://%s:%d", host, port)

  deadline <- Sys.time() + timeout
  while (Sys.time() < deadline) {
    if (!proc$is_alive()) {
      stop("YAP process exited before becoming ready. ",
           "Run with quiet = FALSE to see the output.", call. = FALSE)
    }
    if (yap_ping(url, timeout = 2)) {
      .yappr$base_url <- url
      .yappr$server   <- proc
      .yappr$yap_path <- yap_path
      srv <- structure(
        list(process = proc, url = url, port = as.integer(port),
             yap_path = yap_path),
        class = "yap_server"
      )
      message("YAP is up at ", url)
      return(srv)
    }
    Sys.sleep(1)
  }

  try(proc$kill(), silent = TRUE)
  stop("YAP did not become ready within ", timeout, " seconds.",
       call. = FALSE)
}

#' Stop a YAP server started by \code{\link{yap_start}}
#'
#' @param server A \code{yap_server} object from \code{\link{yap_start}}, or
#'   \code{NULL} to stop the server stored in the package environment.
#' @param grace Seconds to wait after SIGTERM before forcing a kill.
#' @return \code{TRUE} invisibly if a running server was stopped,
#'   \code{FALSE} otherwise.
#' @export
yap_stop <- function(server = NULL, grace = 5) {
  if (is.null(server)) server <- .yappr$server
  if (is.null(server)) {
    message("No running YAP server recorded in this session.")
    return(invisible(FALSE))
  }
  proc <- if (inherits(server, "yap_server")) server$process else server
  if (!inherits(proc, "process")) {
    message("Object is not a processx process; nothing to stop.")
    return(invisible(FALSE))
  }
  if (!proc$is_alive()) {
    .yappr$server <- NULL
    return(invisible(FALSE))
  }
  try(proc$interrupt(), silent = TRUE)
  proc$wait(timeout = grace * 1000)
  if (proc$is_alive()) proc$kill()
  .yappr$server   <- NULL
  .yappr$base_url <- NULL
  invisible(TRUE)
}

#' Check whether a YAP server is answering at \code{url}
#' @param url Base URL to test.
#' @param timeout Seconds before giving up.
#' @return Logical.
#' @export
yap_ping <- function(url = NULL, timeout = 2) {
  url <- .resolve_url(url)
  ok <- tryCatch({
    r <- httr::GET(url, httr::timeout(timeout))
    !is.null(httr::status_code(r))
  }, error = function(e) FALSE)
  isTRUE(ok)
}

#' Are we ready to talk to YAP?
#' @param url Base URL.
#' @return Logical.
#' @export
yap_available <- function(url = NULL) yap_ping(url)

#' Show what the package knows about the local YAP server
#' @return Invisible list.
#' @export
yap_status <- function() {
  url <- .resolve_url(NULL)
  alive <- if (!is.null(.yappr$server))
    .yappr$server$is_alive() else NA
  reachable <- yap_ping(url)
  message("YAP base URL : ", url)
  message("YAP install  : ", .yappr$yap_path %||% "<unset>")
  message("Process alive: ", alive)
  message("Reachable    : ", reachable)
  invisible(list(url = url,
                 yap_path = .yappr$yap_path,
                 process_alive = alive,
                 reachable = reachable))
}

# Tiny null-coalesce used only inside the package.
`%||%` <- function(a, b) if (is.null(a)) b else a

#' @export
print.yap_server <- function(x, ...) {
  cat("<yap_server>\n")
  cat(" url      : ", x$url, "\n", sep = "")
  cat(" yap_path : ", x$yap_path, "\n", sep = "")
  cat(" alive    : ", isTRUE(x$process$is_alive()), "\n", sep = "")
  invisible(x)
}
