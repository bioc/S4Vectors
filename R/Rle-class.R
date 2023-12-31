### =========================================================================
### Rle objects
### -------------------------------------------------------------------------
###


setClass("Rle",
    contains="Vector",
    representation(
        values="vector_OR_factor",
        lengths="integer_OR_LLint"
    ),
    prototype(
        values=logical(0),
        lengths=integer(0)
    )
)

 
### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Getters
###

setMethod("length", "Rle",
    function(x) as.double(.Call2("Rle_length", x, PACKAGE="S4Vectors"))
)

setGeneric("runLength", signature = "x",
           function(x) standardGeneric("runLength"))
setMethod("runLength", "Rle", function(x) x@lengths)
 
setGeneric("runValue", signature = "x",
           function(x) standardGeneric("runValue"))
setMethod("runValue", "Rle", function(x) x@values)

setGeneric("nrun", signature = "x", function(x) standardGeneric("nrun"))
setMethod("nrun", "Rle", function(x) length(runLength(x)))

setMethod("start", "Rle", function(x) .Call2("Rle_start", x, PACKAGE="S4Vectors"))
setMethod("end", "Rle", function(x) .Call2("Rle_end", x, PACKAGE="S4Vectors"))
setMethod("width", "Rle", function(x) runLength(x))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Validity
###

.valid_Rle <- function(x)
{
    msg <- NULL
    msg <- c(msg, .Call2("Rle_valid", x, PACKAGE="S4Vectors"))
    ## Too expensive so commented out for now. Maybe do this in C?
    #run_values <- runValues(x)
    #if (length(run_values) >= 2 && is.atomic(run_values) &&
    #    any(run_values[-1L] == run_values[-length(run_values)]))
    #    msg <- c(msg, "consecutive runs must have different values")
    msg
}

setValidity2("Rle", .valid_Rle)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor
###

### Low-level constructor.
new_Rle <- function(values=logical(0), lengths=NULL)
{
    if (!is(values, "vector_OR_factor"))
        stop("Rle of type '", typeof(values), "' is not supported")
    if (!is.null(lengths)) {
        if (!(is.numeric(lengths) || is.LLint(lengths)))
            stop("'lengths' must be NULL or a numeric or LLint vector")
        if (anyNA(lengths))
            stop("'lengths' cannot contain NAs")
        if (is.double(lengths)) {
            suppressWarnings(lengths <- as.LLint(lengths))
            if (anyNA(lengths))
                stop("Rle vector is too long")
        }
        if (length(lengths) == 1L)
            lengths <- rep.int(lengths, length(values))
    }
    .Call2("Rle_constructor", values, lengths, PACKAGE="S4Vectors")
}

setGeneric("Rle", signature="values",
    function(values=logical(0), lengths=NULL) standardGeneric("Rle")
)

setMethod("Rle", "ANY",
    function(values=logical(0), lengths=NULL) new_Rle(values, lengths)
)

setMethod("Rle", "Rle",
    function(values=logical(0), lengths=NULL)
    {
        if (!missing(lengths))
            stop(wmsg("'lengths' cannot be supplied when calling Rle() ",
                      "on an Rle object"))
        values
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Setters
###

setGeneric("runLength<-", signature="x",
           function(x, value) standardGeneric("runLength<-"))
setReplaceMethod("runLength", "Rle",
                 function(x, value) Rle(runValue(x), value))
         
setGeneric("runValue<-", signature="x",
           function(x, value) standardGeneric("runValue<-"))
setReplaceMethod("runValue", "Rle",
                 function(x, value) Rle(value, runLength(x)))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion
###

setAs("ANY", "Rle", function(from) Rle(from))

setAs("Rle", "vector", function(from) as.vector(from))
setAs("Rle", "logical", function(from) as.logical(from))
setAs("Rle", "integer", function(from) as.integer(from))
setAs("Rle", "numeric", function(from) as.numeric(from))
setAs("Rle", "complex", function(from) as.complex(from))
setAs("Rle", "character", function(from) as.character(from))
setAs("Rle", "raw", function(from) as.raw(from))
setAs("Rle", "factor", function(from) as.factor(from))
setAs("Rle", "list", function(from) as.list(from))

as.vector.Rle <- function(x, mode)
  rep.int(as.vector(runValue(x), mode), runLength(x))
setMethod("as.vector", "Rle", as.vector.Rle)
setMethod("as.factor", "Rle", function(x) rep.int(as.factor(runValue(x)), runLength(x)))

asFactorOrFactorRle <- function(x) {
  if (is(x, "Rle")) {
    runValue(x) <- as.factor(runValue(x))
    x
  } else {
    as.factor(x)
  }
}

### S3/S4 combo for as.list.Rle
as.list.Rle <- function(x, ...) as.list(as.vector(x), ...)
setMethod("as.list", "Rle", as.list.Rle)

setGeneric("decode", function(x, ...) standardGeneric("decode"))
setMethod("decode", "ANY", identity)

decodeRle <- function(x) rep.int(runValue(x), runLength(x))
setMethod("decode", "Rle", decodeRle)

.as.data.frame.Rle <- function(x, row.names=NULL, optional=FALSE, ...)
{
    value <- decodeRle(x)
    as.data.frame(value, row.names=row.names,
                  optional=optional, ...)
}
setMethod("as.data.frame", "Rle", .as.data.frame.Rle)

getStartEndRunAndOffset <- function(x, start, end) {
    .Call2("Rle_getStartEndRunAndOffset", x, start, end, PACKAGE="S4Vectors")
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting workhorses
###
### These are the low-level functions that do the real work of subsetting an
### Rle object. The final coercion to class(x) is to make sure that they act
### like an endomorphism on objects that belong to a subclass of Rle (the
### VariantAnnotation package defines Rle subclasses).
### Note that they drop the metadata columns!
###

### TODO: Support NAs in 'pos'.
extract_positions_from_Rle <- function(x, pos, method=0L, decoded=FALSE)
{
    if (!is.integer(pos))
        stop("'pos' must be an integer vector")
    if (!isTRUEorFALSE(decoded))
        stop("'decoded' must be TRUE or FALSE")
    #ans <- .Call2("Rle_extract_positions", x, pos, method, PACKAGE="S4Vectors")
    mapped_pos <- map_positions_to_runs(runLength(x), pos, method=method)
    ans <- runValue(x)[mapped_pos]
    if (decoded)
        return(ans)
    as(Rle(ans), class(x))  # so the function is an endomorphism
}

extract_range_from_Rle <- function(x, start, end)
{
    ans <- .Call2("Rle_extract_range", x, start, end, PACKAGE="S4Vectors")
    as(ans, class(x))  # so the function is an endomorphism
}

### NOT exported but used in IRanges package (by "extractROWS" method with
### signature Rle,RangesNSBS).
extract_ranges_from_Rle <- function(x, start, width, method=0L, as.list=FALSE)
{
    method <- normarg_method(method)
    if (!isTRUEorFALSE(as.list))
        stop("'as.list' must be TRUE or FALSE")
    ans <- .Call2("Rle_extract_ranges", x, start, width, method, as.list,
                                        PACKAGE="S4Vectors")
    ## The function must act like an endomorphism.
    x_class <- class(x)
    if (!as.list)
        return(as(ans, x_class))
    ## 'ans' is a list of Rle instances.
    if (x_class == "Rle")
        return(ans)
    lapply(ans, as, x_class)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting
###

setMethod("extractROWS", c("Rle", "ANY"),
    function (x, i) 
    {
        i <- normalizeSingleBracketSubscript(i, x, allow.NAs=TRUE, as.NSBS=TRUE)
        callGeneric()
    }
)

setMethod("extractROWS", c("Rle", "RangeNSBS"),
    function(x, i)
    {
        range <- i@subscript
        range_start <- range[[1L]]
        range_end <- range[[2L]]
        ans <- extract_range_from_Rle(x, range_start, range_end)
        mcols(ans) <- extractROWS(mcols(x, use.names=FALSE), i)
        ans
    }
)

setMethod("extractROWS", c("Rle", "NSBS"),
    function(x, i)
    {
        ans <- extract_positions_from_Rle(x, as.integer(i))
        mcols(ans) <- extractROWS(mcols(x, use.names=FALSE), i)
        ans
    }
)

setMethod("[", "Rle",
    function(x, i, j, ..., drop=getOption("dropRle", default=FALSE))
    {
        if (!missing(j) || length(list(...)) > 0)
            stop("invalid subsetting")
        if (!missing(i))
            x <- extractROWS(x, i)
        if (drop)
            x <- decodeRle(x)
        x
    }
)

### The replaced elements in 'x' must get their metadata columns from 'value'.
### See this thread on bioc-devel:
###   https://stat.ethz.ch/pipermail/bioc-devel/2015-November/008319.html
setMethod("replaceROWS", c("Rle", "ANY"),
    function(x, i, value)
    {
        ## FIXME: Right now, the subscript 'i' is turned into an IRanges
        ## object so we need stuff that lives in the IRanges package for this
        ## to work. This is ugly/hacky and needs to be fixed (thru a redesign
        ## of this method).
        if (!requireNamespace("IRanges", quietly=TRUE))
            stop("Couldn't load the IRanges package. You need to install ",
                 "the IRanges\n  package in order to replace values in ",
                 "an Rle object.")

        i <- normalizeSingleBracketSubscript(i, x, as.NSBS=TRUE)
        lv <- length(value)
        if (lv != 1L) {
            ans <- Rle(replaceROWS(decodeRle(x), i, as.vector(value)))
            mcols(ans) <- replaceROWS(mcols(x, use.names=FALSE), i,
                                      mcols(value, use.names=FALSE))
            return(ans)
        }

        ## From here, 'value' is guaranteed to be of length 1.

        ## TODO: Maybe make this the coercion method from NSBS to IntegerRanges.
        if (is(i, "RangesNSBS")) {
            ir <- i@subscript
        } else {
            ir <- as(as.integer(i), "IRanges")
        }
        ir <- IRanges::reduce(ir)
        if (length(ir) == 0L)
            return(x)

        isFactorRle <- is.factor(runValue(x))
        value <- normalizeSingleBracketReplacementValue(value, x)
        value2 <- as.vector(value)
        if (isFactorRle) {
            value2 <- factor(value2, levels=levels(x))
            dummy_value <- factor(levels(x), levels=levels(x))
        }
        if (anyMissingOrOutside(start(ir), 1L, length(x)) ||
            anyMissingOrOutside(end(ir), 1L, length(x)))
            stop("some ranges are out of bounds")

        valueWidths <- width(ir)
        ir <- IRanges::gaps(ir, start=1, end=length(x))
        k <- length(ir)
        start <- start(ir)
        end <- end(ir)

        info <- getStartEndRunAndOffset(x, start, end)
        runStart <- info[["start"]][["run"]]
        offsetStart <- info[["start"]][["offset"]]
        runEnd <- info[["end"]][["run"]]
        offsetEnd <- info[["end"]][["offset"]]

        if ((length(ir) == 0L) || (start(ir)[1L] != 1L)) {
            k <- k + 1L
            runStart <- c(1L, runStart)
            offsetStart <- c(0L, offsetStart)
            runEnd <- c(0L, runEnd)
            offsetEnd <- c(0L, offsetEnd)
        } 
        if ((length(ir) > 0L) && (end(ir[length(ir)]) != length(x))) {
            k <- k + 1L
            runStart <- c(runStart, 1L)
            offsetStart <- c(offsetStart, 0L)
            runEnd <- c(runEnd, 0L)
            offsetEnd <- c(offsetEnd, 0L)
        }

        subseqs <- vector("list", length(valueWidths) + k)
        if (k > 0L) {
            if (isFactorRle) {
                subseqs[seq(1L, length(subseqs), by=2L)] <-
                    lapply(seq_len(k), function(i) {
                           ans <- .Call2("Rle_window_aslist",
                                         x, runStart[i], runEnd[i],
                                         offsetStart[i], offsetEnd[i],
                                         PACKAGE="S4Vectors")
                           ans[["values"]] <- dummy_value[ans[["values"]]]
                           ans})
            } else {
                subseqs[seq(1L, length(subseqs), by=2L)] <-
                    lapply(seq_len(k), function(i)
                           .Call2("Rle_window_aslist",
                                  x, runStart[i], runEnd[i],
                                  offsetStart[i], offsetEnd[i],
                                  PACKAGE="S4Vectors"))
            }
        }
        if (length(valueWidths) > 0L) {
            subseqs[seq(2L, length(subseqs), by=2L)] <-
                lapply(seq_len(length(valueWidths)), function(i)
                       list(values=value2,
                            lengths=valueWidths[i]))
        }
        values <- unlist(lapply(subseqs, "[[", "values"))
        if (isFactorRle)
            values <- dummy_value[values]
        ans <- Rle(values, unlist(lapply(subseqs, "[[", "lengths")))
        mcols(ans) <- replaceROWS(mcols(x, use.names=FALSE), i,
                                  mcols(value, use.names=FALSE))
        ans
    }
)

setReplaceMethod("[", c("Rle", "ANY"),
    function(x, i, j,..., value)
    {
        if (!missing(j) || length(list(...)) > 0L)
            stop("invalid subsetting")
        i <- normalizeSingleBracketSubscript(i, x, as.NSBS=TRUE)
        li <- length(i)
        if (li == 0L) {
            ## Surprisingly, in that case, `[<-` on standard vectors does not
            ## even look at 'value'. So neither do we...
            return(x)
        }
        lv <- length(value)
        if (lv == 0L)
            stop("replacement has length zero")
        replaceROWS(x, i, value)
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting an object by an Rle subscript.
###
### See R/subsetting-utils.R for more information.
###

setClass("RleNSBS",      # not exported
    contains="NSBS",
    representation(
        subscript="Rle"  # integer-Rle
    ),
    prototype(
        ## Calling Rle(integer(0)) below causes the following error at
        ## installation time:
        ##     Error in .Call(.NAME, ..., PACKAGE = PACKAGE) : 
        ##       "Rle_constructor" not available for .Call() for package
        ##       "S4Vectors"
        ##     Error : unable to load R code in package ‘S4Vectors’
        ##     ERROR: lazy loading failed for package ‘S4Vectors’
        #subscript=Rle(integer(0))
        subscript=new2("Rle", values=integer(0),
                              lengths=integer(0),
                              check=FALSE)
    )
)

### Construction methods.
### Supplied arguments are trusted so we don't check them!

setMethod("NSBS", "Rle",
    function(i, x, exact=TRUE, strict.upper.bound=TRUE, allow.NAs=FALSE)
    {
        x_NROW <- NROW(x)
        i_vals <- runValue(i)
        if (is.logical(i_vals) && length(i_vals) != 0L) {
            if (anyNA(i_vals))
                stop("subscript contains NAs")
            if (length(i) < x_NROW)
                i <- rep(i, length.out=x_NROW)
            ## The coercion method from Rle to NormalIRanges is defined in the
            ## IRanges package.
            if (requireNamespace("IRanges", quietly=TRUE)) {
                i <- as(i, "NormalIRanges")
                ## This will call the "NSBS" method for IntegerRanges objects
                ## defined in the IRanges package and return a RangesNSBS, or
                ## RangeNSBS, or NativeNSBS object.
                return(callGeneric())
            }
            warning(wmsg(
                "Couldn't load the IRanges package. Installing this package ",
                "will enable efficient subsetting by a logical-Rle object ",
                "so is higly recommended."
            ))
            i <- which(i)
            return(callGeneric())  # will return a NativeNSBS object
        }
        i_vals <- NSBS(i_vals, x, exact=exact,
                                  strict.upper.bound=strict.upper.bound,
                                  allow.NAs=allow.NAs)
        runValue(i) <- as.integer(i_vals)
        new2("RleNSBS", subscript=i,
                        upper_bound=x_NROW,
                        upper_bound_is_strict=strict.upper.bound,
                        has_NAs=i_vals@has_NAs,
                        check=FALSE)
    }
)

### Other methods.

setMethod("as.integer", "RleNSBS", function(x) decodeRle(x@subscript))

setMethod("length", "RleNSBS", function(x) length(x@subscript))

setMethod("anyDuplicated", "RleNSBS",
    function(x, incomparables=FALSE, ...) anyDuplicated(x@subscript)
)

setMethod("isStrictlySorted", "RleNSBS",
    function(x) isStrictlySorted(x@subscript)
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting an Rle object by an Rle subscript.
###

### Simplified version of rep.int() for Rle objects. Handles only the case
### where 'times' has the length of 'x'.
.rep_times_Rle <- function(x, times)
{
    breakpoints <- end(x)
    if (length(times) != last_or(breakpoints, 0L))
        stop("invalid 'times' argument")
    runLength(x) <- groupsum(times, breakpoints)
    x
}

setMethod("extractROWS", c("Rle", "RleNSBS"),
    function(x, i)
    {
        rle <- i@subscript
        .rep_times_Rle(extractROWS(x, runValue(rle)), runLength(rle))
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Other subsetting-related operations
###

### S3/S4 combo for rev.Rle
rev.Rle <- function(x)
{
    x@values <- rev(runValue(x))
    x@lengths <- rev(runLength(x))
    x
}
setMethod("rev", "Rle", rev.Rle)

setMethod("rep.int", "Rle",
    function(x, times)
    {
        if (!is.numeric(times))
            stop("invalid 'times' argument")
        if (!is.integer(times))
            times <- as.integer(times)
        if (anyMissingOrOutside(times, 0L))
            stop("invalid 'times' argument")

        x_len <- length(x)
        times_len <- length(times)
        if (times_len == x_len)
            return(.rep_times_Rle(x, times))
        if (times_len != 1L)
            stop("invalid 'times' argument")
        ans <- Rle(rep.int(runValue(x), times),
                   rep.int(runLength(x), times))
        as(ans, class(x))  # so the function is an endomorphism
    }
)

setMethod("rep", "Rle",
          function(x, times, length.out, each)
          {
              usedEach <- FALSE
              if (!missing(each) && length(each) > 0) {
                  each <- as.integer(each[1L])
                  if (!is.na(each)) {
                      if (each < 0)
                          stop("invalid 'each' argument")
                      usedEach <- TRUE
                      if (each == 0)
                          x <- new2(class(x), values=runValue(x)[0L],
                                              check=FALSE)
                      else
                          x@lengths <- each[1L] * runLength(x)
                  }
              }
              if (!missing(length.out) && length(length.out) > 0) {
                  n <- length(x)
                  length.out <- as.integer(length.out[1L])
                  if (!is.na(length.out)) {
                      if (length.out == 0) {
                          x <- new2(class(x), values=runValue(x)[0L],
                                              check=FALSE)
                      } else if (length.out < n) {
                          x <- window(x, 1, length.out)
                      } else if (length.out > n) {
                          if (n == 0) {
                              x <- Rle(rep(runValue(x), length.out=1),
                                       length.out)
                          } else {
                              x <-
                                window(rep.int(x, ceiling(length.out / n)),
                                       1, length.out)
                          }
                      }
                  }
              } else if (!missing(times)) {
                  if (usedEach && length(times) != 1)
                      stop("invalid 'times' argument")
                  x <- rep.int(x, times)
              }
              x
          })


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Concatenation
###

.bindROWS_Rle_objects <-
    function(x, objects=list(), use.names=TRUE, ignore.mcols=FALSE, check=TRUE)
{
    objects <- prepare_objects_to_bind(x, objects)
    all_objects <- c(list(x), objects)

    ## 1. Take care of the parallel slots

    ## Call method for Vector objects to concatenate all the parallel
    ## slots (only "elementMetadata" in the case of Rle) and stick them
    ## into 'ans'. Note that the resulting 'ans' can be an invalid object
    ## because its "elementMetadata" slot can be longer (i.e. have more rows)
    ## than 'ans' itself so we use 'check=FALSE' to skip validation.
    ans <- callNextMethod(x, objects, use.names=use.names,
                                      ignore.mcols=ignore.mcols,
                                      check=FALSE)

    ## 2. Take care of the non-parallel slots

    ## Concatenate the "values" slots.
    values_list <- lapply(all_objects, slot, "values")
    tmp_values <- unlist(values_list, recursive=FALSE)

    ## Concatenate the "lengths" slots.
    lengths_list <- lapply(all_objects, slot, "lengths")
    tmp_lengths <- unlist(lengths_list, recursive=FALSE)

    tmp <- Rle(tmp_values, tmp_lengths)
    BiocGenerics:::replaceSlots(ans, values=tmp@values,
                                     lengths=tmp@lengths,
                                     check=check)
}

setMethod("bindROWS", "Rle", .bindROWS_Rle_objects)

setMethod("append", c("Rle", "vector"),
          function (x, values, after = length(x)) {
              append(x, Rle(values), after)
          })

setMethod("append", c("vector", "Rle"),
          function (x, values, after = length(x)) {
              append(Rle(x), values, after)
          })

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Other methods.
###

setMethod("%in%", "Rle",
          function(x, table)
              new_Rle(runValue(x) %in% table, runLength(x)))

setGeneric("findRun", signature = "vec",
           function(x, vec) standardGeneric("findRun"))

setMethod("findRun", signature = c(vec = "Rle"),
          function(x, vec) {
            runs <- findIntervalAndStartFromWidth(as.integer(x),
                                         runLength(vec))[["interval"]]
            runs[is.na(runs) | x == 0 | x > length(vec)] <- NA
            runs
          })

setMethod("is.na", "Rle",
          function(x)
              new_Rle(is.na(runValue(x)), runLength(x)))

setMethod("anyNA", "Rle",
          function(x)
              anyNA(runValue(x)))

setMethod("sameAsPreviousROW", "Rle", function(x) {
    is.same <- !logical(length(x))
    is.same[start(x)] <- sameAsPreviousROW(runValue(x))
    is.same
})

setMethod("is.finite", "Rle",
          function(x)
              new_Rle(is.finite(runValue(x)), runLength(x)))

setMethod("match", c("ANY", "Rle"),
    function(x, table, nomatch=NA_integer_, incomparables=NULL)
    {
        m <- match(x, runValue(table), incomparables=incomparables)
        ans <- start(table)[m]
        ## 'as.integer(nomatch)[1L]' seems to mimic how base::match() treats
        ## the 'nomatch' argument.
        nomatch <- as.integer(nomatch)[1L]
        if (!is.na(nomatch))
            ans[is.na(ans)] <- nomatch
        ans
    }
)

setMethod("match", c("Rle", "ANY"),
    function(x, table, nomatch=NA_integer_, incomparables=NULL)
    {
        x_run_lens <- runLength(x)
        x <- runValue(x)
        m <- callGeneric()
        Rle(m, x_run_lens)
    }
)

setMethod("match", c("Rle", "Rle"),
    function(x, table, nomatch=NA_integer_, incomparables=NULL)
    {
        x_run_lens <- runLength(x)
        x <- runValue(x)
        m <- callGeneric()
        Rle(m, x_run_lens)
    }
)

.duplicated.Rle <- function(x, incomparables=FALSE, fromLast=FALSE)
    stop("no \"duplicated\" method for Rle objects yet, sorry")
setMethod("duplicated", "Rle", .duplicated.Rle)

### S3/S4 combo for anyDuplicated.Rle
anyDuplicated.Rle <- function(x, incomparables=FALSE, ...)
    any(runLength(x) != 1L) || anyDuplicated(runValue(x))
setMethod("anyDuplicated", "Rle", anyDuplicated.Rle)

.unique.Rle <- function(x, incomparables=FALSE, ...)
    unique(runValue(x), incomparables=incomparables, ...)
setMethod("unique", "Rle", .unique.Rle)

setMethod("order", "Rle",
          function(..., na.last=TRUE, decreasing=FALSE,
                   method=c("auto", "shell", "radix"))
{
    args <- list(...)
    if (length(args) == 1L) {
        x <- args[[1L]]
        o <- order(runValue(x), na.last=na.last, decreasing=decreasing,
                   method=method)
        sequence(width(x)[o], from=start(x)[o])
    } else {
        args <- lapply(unname(args), decodeRle)
        do.call(order, c(args, list(na.last=na.last,
                                    decreasing=decreasing,
                                    method=method)))
    }
})

setMethod("is.unsorted", "Rle",
          function(x, na.rm = FALSE, strictly = FALSE)
          {
              ans <- is.unsorted(runValue(x), na.rm = na.rm, strictly = strictly)
              if (strictly && !ans)
                  ans <- any(runLength(x) > 1L)
              ans
          })

setMethod("isStrictlySorted", "Rle",
    function(x) all(runLength(x) == 1L) && isStrictlySorted(runValue(x))
)

### S3/S4 combo for sort.Rle
sort.Rle <- function(x, decreasing=FALSE, na.last=NA, ...)
{
    if (is.na(na.last)) {
        if (anyNA(runValue(x)))
            x <- x[!is.na(x)]
    }
    ord <- base::order(runValue(x), na.last=na.last, decreasing=decreasing)
    new_Rle(runValue(x)[ord], runLength(x)[ord])
}
setMethod("sort", "Rle", sort.Rle)

setMethod("rank", "Rle", function (x, na.last = TRUE,
                                   ties.method = c("average", "first", 
                                     "random", "max", "min"))
          {
              ties.method <- match.arg(ties.method)
              if (ties.method == "min" || ties.method == "first") {
                  callNextMethod()
              } else {
                  x <- as.vector(x)
                  ans <- callGeneric()
                  if (ties.method %in% c("average", "max", "min")) {
                      Rle(ans)
                  } else {
                      ans
                  }
              }
          })

setMethod("xtfrm", "Rle", function(x) {
    initialize(x, values=xtfrm(runValue(x)))
})

setMethod("table", "Rle", 
    function(...)
    {
        ## Currently only 1 Rle is supported. An approach for multiple 
        ## Rle's could be disjoin(), findRun() to find matches, then 
        ## xtabs(length ~ value ...).
        x <- sort(list(...)[[1L]]) 
        if (is.factor(runValue(x))) {
            dn <- levels(x)
            tab <- integer(length(dn))
            tab[dn %in% runValue(x)] <- runLength(x)
            dims <- length(dn)
        } else {
            dn <- as.character(runValue(x)) 
            tab <- runLength(x) 
            dims <- nrun(x)
        }
        ## Adjust 'dn' for consistency with base::table
        if (length(dn) == 0L)
            dn <- NULL
        dn <- list(dn)
        names(dn) <- .list.names(...) 
        y <- array(tab, dims, dimnames=dn)
        class(y) <- "table"
        y 
    }
)

.list.names <- function(...) {
    l <- as.list(substitute(list(...)))[-1L]
    deparse.level <- 1 
    nm <- names(l)
    fixup <- if (is.null(nm))
        seq_along(l)
    else nm == ""
    dep <- vapply(l[fixup], function(x) switch(deparse.level +
        1, "", if (is.symbol(x)) as.character(x) else "",
        deparse(x, nlines = 1)[1L]), "")
    if (is.null(nm))
        dep
    else {
        nm[fixup] <- dep
        nm
    }
}

### Not exported? Broken on numeric-Rle and factor-Rle. H.P. -- Oct 16, 2016
setMethod("tabulate", "Rle",
          function (bin, nbins = max(bin, 1L, na.rm = TRUE)) {
              tabulate2(runValue(bin), nbins, runLength(bin))
          })


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Set methods
###
### The return values of these do not have any duplicated values, so
### it would obviously be more efficient to return plain vectors. That
### might violate user expectations though.
###

setMethod("union", c("Rle", "Rle"), function(x, y) {
  Rle(union(runValue(x), runValue(y)))
})

setMethod("union", c("ANY", "Rle"), function(x, y) {
  Rle(union(as.vector(x), runValue(y)))
})

setMethod("union", c("Rle", "ANY"), function(x, y) {
  Rle(union(runValue(x), as.vector(y)))
})

setMethod("intersect", c("Rle", "Rle"), function(x, y) {
  Rle(intersect(runValue(x), runValue(y)))
})

setMethod("intersect", c("ANY", "Rle"), function(x, y) {
  Rle(intersect(as.vector(x), runValue(y)))
})

setMethod("intersect", c("Rle", "ANY"), function(x, y) {
  Rle(intersect(runValue(x), as.vector(y)))
})

setMethod("setdiff", c("Rle", "Rle"), function(x, y) {
  Rle(setdiff(runValue(x), runValue(y)))
})

setMethod("setdiff", c("ANY", "Rle"), function(x, y) {
  Rle(setdiff(as.vector(x), runValue(y)))
})

setMethod("setdiff", c("Rle", "ANY"), function(x, y) {
  Rle(setdiff(runValue(x), as.vector(y)))
})


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### The "show" method
###

setMethod("show", "Rle",
          function(object)
          {
              lo <- length(object)
              nr <- nrun(object)
              halfWidth <- getOption("width") %/% 2L
              cat(classNameForDisplay(runValue(object)),
                  "-Rle of length ", as.character(as.LLint(lo)),
                  " with ", nr, ifelse(nr == 1, " run\n", " runs\n"), sep = "")
              first <- max(1L, halfWidth)
              showMatrix <-
                rbind(showAsCell(head(runLength(object), first)),
                      showAsCell(head(runValue(object), first)))
              if (nr > first) {
                  last <- min(nr - first, halfWidth)
                  showMatrix <-
                    cbind(showMatrix,
                          rbind(showAsCell(tail(runLength(object), last)),
                                showAsCell(tail(runValue(object), last))))
              }
              if (is.character(runValue(object))) {
                  showMatrix[2L,] <-
                    paste("\"", showMatrix[2L,], "\"", sep = "")
              }
              showMatrix <- format(showMatrix, justify = "right")
              cat(labeledLine("  Lengths", showMatrix[1L,], count = FALSE))
              cat(labeledLine("  Values ", showMatrix[2L,], count = FALSE))
              if (is.factor(runValue(object)))
                  cat(labeledLine("Levels", levels(object)))
          })

