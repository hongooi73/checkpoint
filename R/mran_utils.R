#' Utilities for working with MRAN snapshots
#'
#' These functions are for working with the MRAN checkpoint server. `use_mran_snapshot` updates the CRAN mirror for your R session to point to an MRAN snapshot, using `options(repos)`. `list_mran_snapshots` returns the dates for which an MRAN snapshot exists.
#'
#' @param snapshot_date Date of snapshot to use in `YYYY-MM-DD` format, e.g. `"2020-01-01"`. Specify a date on or after `"2014-09-17"`.
#' @param mran_url The base MRAN URL. The default is taken from the system option `checkpoint.mranUrl`, or if this is unset, `https://mran.microsoft.com`.
#' @param validate For `use_mran_snapshot`, whether to check if the snapshot date is valid (exists on the server).
#' @return
#' For `use_mran_snapshot`, the new value of `getOption("repos")`, invisibly. For `list_mran_snapshots`, a character vector of snapshot dates.
#' @example inst/examples/example_mran.Rex
#' @rdname mran
#' @export
use_mran_snapshot <- function(snapshot_date,
                              mran_url=getOption("checkpoint.mranUrl", "https://mran.microsoft.com"),
                              validate=FALSE
                             )
{
    snapshot_date <- verify_date(snapshot_date, validate)

    if(!grepl("^(https?|file)://", mran_url))
        stop("Not a HTTP[S] or file URL", call.=FALSE)

    # replace all unnamed repos and CRAN-repos
    repos <- getOption("repos")
    repo_names <- names(repos)
    if(is.null(repo_names))
        options(repos=c(CRAN=snapshot_url(mran_url, snapshot_date)))
    else
    {
        unnamed_or_cran <- repo_names %in% c("", "CRAN")
        repos <- c(CRAN=snapshot_url(mran_url, snapshot_date), repos[!unnamed_or_cran])
        options(repos=repos)
    }
    invisible(getOption("repos"))
}

#' @rdname mran
#' @export
list_mran_snapshots <- function(mran_url=getOption("checkpoint.mranUrl", "https://mran.microsoft.com"))
{
    if(grepl("^https?://", mran_url))
    {
        lines <- try(readLines(snapshot_url(mran_url)), silent=TRUE)
        if(inherits(lines, "try-error"))
            stop("Unable to contact MRAN host", call.=FALSE)
    }
    else if(grepl("^file://", mran_url))
    {
        f <- file(snapshot_url(mran_url))
        on.exit(close(f))
        lines <- dir(summary(f))
    }
    else stop("Invalid URL scheme", call.=FALSE)

    date_pat <- "\\d{4}-\\d{2}-\\d{2}"
    lines <- grep(date_pat, lines, value=TRUE)
    gsub(sprintf("<a href=.*?>(%s).*?</a>.*$", date_pat), "\\1", lines)
}

snapshot_url <- function(mran_url, snapshot_date=NULL)
{
    if(length(snapshot_date) == 0)
        file.path(sub("/$", "", mran_url), "snapshot")
    else file.path(sub("/$", "", mran_url), "snapshot", snapshot_date)
}

verify_date <- function(date, validate=FALSE)
{
    realdate <- try(as.Date(date), silent=TRUE)
    if(inherits(realdate, "try-error"))
        stop("Invalid date, must be in the format YYYY-MM-DD", call.=FALSE)
    if(realdate < as.Date("2014-09-17"))
        stop("Snapshots are only available after 2014-09-17", call.=FALSE)
    if(realdate > Sys.Date())
        stop("Snapshot date later than current date", call.=FALSE)
    if(validate && !(date %in% list_mran_snapshots()))
        stop("Snapshot date does not exist on MRAN", call.=FALSE)
    date
}


