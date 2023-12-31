### =========================================================================
### Some low-level S4 classes and utilities
### -------------------------------------------------------------------------
###


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Not S4 utilities strictly speaking but I don't have a better place to put
### this at the moment
###

### Override base::I() with a less broken one. This is an ugly hack and
### hopefully it is temporary only!
### See https://stat.ethz.ch/pipermail/r-devel/2020-October/080038.html
### for the full story.
### Must be idempotent i.e. 'I(I(x))' must be identical to 'I(x)' for
### any 'x'.
I <- function(x)
{
    if (isS4(x)) {
        x_class <- class(x)
        new_classes <- unique.default(c("AsIs", x_class))
        attr(new_classes, "package") <- attr(x_class, "package")
        structure(x, class=new_classes)
    } else {
        class(x) <- unique.default(c("AsIs", oldClass(x)))
        x
    }
}

setAs("ANY", "AsIs", function(from) I(from))

### Implement the revert of I() i.e. 'drop_AsIs(I(x))' should be identical
### to 'x' for any 'x'. Must be idempotent i.e. 'drop_AsIs(drop_AsIs(x))'
### must be identical to 'drop_AsIs(x)' for any 'x'.
### NOT exported.
drop_AsIs <- function(x)
{
    x_classes <- class(x)
    new_class <- x_classes[x_classes != "AsIs"]
    attr(new_class, "package") <- attr(x_classes, "package")
    class(x) <- new_class
    x
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Some convenient union classes
###

setClassUnion("character_OR_NULL", c("character", "NULL"))

### WARNING: The behavior of is.vector(), is( , "vector"), is.list(), and
### is( ,"list") makes no sense:
###   1. is.vector(matrix()) is FALSE but is(matrix(), "vector") is TRUE.
###   2. is.list(data.frame()) is TRUE but is(data.frame(), "list") is FALSE.
###   3. is(data.frame(), "list") is FALSE but extends("data.frame", "list")
###      is TRUE.
###   4. is.vector(data.frame()) is FALSE but is.list(data.frame()) and
###      is.vector(list()) are both TRUE. In other words: a data frame is a
###      list and a list is a vector but a data frame is not a vector.
###   5. I'm sure there is more but you get it!
### Building our software on top of such a mess won't give us anything good.
### For example, it's not too surprising that the union class we define below
### is broken:
###   6. is(data.frame(), "vector_OR_factor") is TRUE even though
###      is(data.frame(), "vector") and is(data.frame(), "factor") are both
###      FALSE.
### Results above obtained with R-3.1.2 and R-3.2.0.
### TODO: Be brave and report this craziness to the R bug tracker.
setClassUnion("vector_OR_factor", c("vector", "factor"))

### NOT exported but used in the IRanges package.
ATOMIC_TYPES <- c("logical", "integer", "numeric", "complex",
                  "character", "raw")

setClassUnion("atomic", ATOMIC_TYPES)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion utilities
###

### We define the coercion method below as a workaround to the following
### bug in R:
###
###   setClass("A", representation(stuff="numeric"))
###   setMethod("as.vector", "A", function(x, mode="any") x@stuff)
###
###   a <- new("A", stuff=3:-5)
###   > as.vector(a)
###   [1]  3  2  1  0 -1 -2 -3 -4 -5
###   > as(a, "vector")
###   Error in as.vector(from) : 
###     no method for coercing this S4 class to a vector
###   > selectMethod("coerce", c("A", "vector"))
###   Method Definition:
###
###   function (from, to, strict = TRUE) 
###   {
###       value <- as.vector(from)
###       if (strict) 
###           attributes(value) <- NULL
###       value
###   }
###   <environment: namespace:methods>
###
###   Signatures:
###           from  to      
###   target  "A"   "vector"
###   defined "ANY" "vector"
###   > setAs("ANY", "vector", function(from) as.vector(from))
###   > as(a, "vector")
###   [1]  3  2  1  0 -1 -2 -3 -4 -5
###
###   ML: The problem is that the default coercion method is defined
###   in the methods namespace, which does not see the as.vector()
###   generic we define. Solution in this case would probably be to
###   make as.vector a dispatching primitive like as.character(), but
###   the "mode" argument makes things complicated.
setAs("ANY", "vector", function(from) as.vector(from))

coercerToClass <- function(class) {
  if (extends(class, "vector"))
    .as <- get(paste0("as.", class))
  else .as <- function(from) as(from, class)
  function(from) {
    to <- .as(from)
    if (!is.null(names(from)) && is.null(names(to))) {
      names(to) <- names(from)
    }
    to
  }
}

### A version of coerce() that tries to do a better job at coercing to an
### S3 class. Dispatch on the 2nd argument only!
setGeneric("coerce2", signature="to",
    function(from, to) standardGeneric("coerce2")
)

### TODO: Should probably use coercerToClass() internally (but coercerToClass()
### would first need to be improved).
setMethod("coerce2", "ANY",
    function(from, to)
    {
        to_class <- class(to)
        if (is(from, to_class))
            return(from)
        if (is.data.frame(to)) {
            ans <- as.data.frame(from, check.names=FALSE,
                                       stringsAsFactors=FALSE)
        } else {
            S3coerceFUN <- try(match.fun(paste0("as.", to_class)),
                               silent=TRUE)
            if (!inherits(S3coerceFUN, "try-error")) {
                ans <- S3coerceFUN(from)
            } else {
                ans <- as(from, to_class, strict=FALSE)
            }
        }
        if (length(ans) != length(from))
            stop(wmsg("coercion of ", class(from), " object to ", to_class,
                      " didn't preserve its length"))
        ## Try to restore the names if they were lost (e.g. by as.integer())
        ## or altered (e.g. by as.data.frame(), which will alter names equal
        ## to the empty string even if called with 'check.names=FALSE').
        if (!identical(names(ans), names(from))) {
            tmp <- try(`names<-`(ans, value=names(from)), silent=TRUE)
            if (!inherits(tmp, "try-error"))
                ans <- tmp
        }
        ans
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### setValidity2(), new2()
###
### Give more contol over when object validation should happen.
###

.validity_options <- new.env(hash=TRUE, parent=emptyenv())

assign("debug", FALSE, envir=.validity_options)
assign("disabled", FALSE, envir=.validity_options)

debugValidity <- function(debug)
{
    if (missing(debug))
        return(get("debug", envir=.validity_options))
    debug <- isTRUE(debug)
    assign("debug", debug, envir=.validity_options)
    debug
}

disableValidity <- function(disabled)
{
    if (missing(disabled))
        return(get("disabled", envir=.validity_options))
    disabled <- isTRUE(disabled)
    assign("disabled", disabled, envir=.validity_options)
    disabled
}

### A slightly modified version of wmsg() that is better suited for formatting
### the problem description strings returned by validity methods.
### NOT exported.
wmsg2 <- function(...)
    paste0("\n    ",
           paste0(strwrap(paste0(c(...), collapse="")), collapse="\n    "))

setValidity2 <- function(Class, method, where=topenv(parent.frame()))
{
    setValidity(Class,
        function(object)
        {
            if (disableValidity())
                return(TRUE)
            if (debugValidity()) {
                whoami <- paste("validity method for", Class, "object")
                cat("[debugValidity] Entering ", whoami, "\n", sep="")
                on.exit(cat("[debugValidity] Leaving ", whoami, "\n", sep=""))
            }
            desc_strings <- method(object)
            if (isTRUE(desc_strings) || length(desc_strings) == 0L)
                return(TRUE)
            vapply(desc_strings, wmsg2, character(1), USE.NAMES=FALSE)
        },
        where=where
    )
}

new2 <- function(..., check=TRUE)
{
    if (!isTRUEorFALSE(check))
        stop("'check' must be TRUE or FALSE")
    old_val <- disableValidity()
    on.exit(disableValidity(old_val))
    disableValidity(!check)
    new(...)
}

### 'signatures' must be a list of character vectors. To use when many methods
### share the same implementation.
setMethods <- function(f, signatures=list(), definition,
                       where=topenv(parent.frame()), ...)
{
    for (signature in signatures)
        setMethod(f, signature=signature, definition, where=where, ...)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### setReplaceAs()
###
### Supplying a "coerce<-" method to the 'replace' argument of setAs() is
### optional but supplying a "coerce" method (thru the 'def' argument) is not.
### However there are legitimate situations where we want to define a
### "coerce<-" method only. setReplaceAs() can be used for that.
###

### Same interface as setAs() (but no 'replace' argument).
### NOT exported.
setReplaceAs <- function(from, to, def, where=topenv(parent.frame()))
{
    ## Code below taken from setAs() and slightly adapted.

    args <- formalArgs(def)
    if (identical(args, c("from", "to", "value"))) {
        method <- def
    } else {
        if (length(args) != 2L) 
            stop(gettextf("the method definition must be a function of 2 ",
                          "arguments, got %d", length(args)), domain=NA)
        def <- body(def)
        if (!identical(args, c("from", "value"))) {
            ll <- list(quote(from), quote(value))
            names(ll) <- args
            def <- substituteDirect(def, ll)
            warning(gettextf("argument names in method definition changed ",
                             "to agree with 'coerce<-' generic:\n%s",
                             paste(deparse(def), sep="\n    ")), domain=NA)
        }
        method <- eval(function(from, to, value) NULL)
        functionBody(method, envir=.GlobalEnv) <- def
    }
    setMethod("coerce<-", c(from, to), method, where=where)
}

### We also provide 2 canonical "coerce<-" methods that can be used when the
### "from class" is a subclass of the "to class". They do what the methods
### automatically generated by the methods package are expected to do except
### that the latter are broken. See
###     https://bugs.r-project.org/bugzilla/show_bug.cgi?id=16421
### for the bug report.

### Naive/straight-forward implementation (easy to understand so it explains
### the semantic of canonical "coerce<-").
canonical_replace_as <- function(from, to, value)
{
    for (what in slotNames(to))
        slot(from, what) <- slot(value, what)
    from
}

### Does the same as canonical_replace_as() but tries to generate only one
### copy of 'from' instead of one copy each time one of its slots is modified.
canonical_replace_as_2 <- function(from, to, value)
{
    firstTime <- TRUE
    for (what in slotNames(to)) {
        v <- slot(value, what)
        if (firstTime) {
            slot(from, what, FALSE) <- v
            firstTime <- FALSE
        } else {
            `slot<-`(from, what, FALSE, v)
        }
    }
    from
}

### Usage (assuming B is a subclass of A):
###
###   setReplaceAs("B", "A", canonical_replace_as_2)
###
### Note that this is used in the VariantAnnotation package.


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Manipulating the prototype of an S4 class.
###

### Gets or sets the default value of the given slot of the given class by
### reading or altering the prototype of the class. setDefaultSlotValue() is
### typically used in the .onLoad() hook of a package when the DLL of the
### package needs to be loaded *before* the default value of a slot can be
### computed.
### NOT exported.
getDefaultSlotValue <- function(classname, slotname, where=.GlobalEnv)
{
    classdef <- getClass(classname, where=where)
    if (!(slotname %in% names(attributes(classdef@prototype))))
        stop("prototype for class \"", classname, "\" ",
             "has no \"", slotname, "\" attribute")
    attr(classdef@prototype, slotname, exact=TRUE)
}

### NOT exported.
setDefaultSlotValue <- function(classname, slotname, value, where=.GlobalEnv)
{
    classdef <- getClass(classname, where=where)
    if (!(slotname %in% names(attributes(classdef@prototype))))
        stop("prototype for class \"", classname, "\" ",
             "has no \"", slotname, "\" attribute")
    attr(classdef@prototype, slotname) <- value
    assignClassDef(classname, classdef, where=where)
    ## Re-compute the complete definition of the class. methods::setValidity()
    ## does that after calling assignClassDef() so we do it too.
    resetClass(classname, classdef, where=where)
}

### NOT exported.
setPrototypeFromObject <- function(classname, object, where=.GlobalEnv)
{
    classdef <- getClass(classname, where=where)
    if (class(object) != classname)
        stop("'object' must be a ", classname, " instance")
    object_attribs <- attributes(object)
    object_attribs$class <- NULL
    ## Sanity check.
    stopifnot(identical(names(object_attribs),
                        names(attributes(classdef@prototype))))
    attributes(classdef@prototype) <- object_attribs
    assignClassDef(classname, classdef, where=where)
    ## Re-compute the complete definition of the class. methods::setValidity()
    ## does that after calling assignClassDef() so we do it too.
    resetClass(classname, classdef, where=where)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
### allEqualsS4: just a hack that auomatically digs down
### deeply nested objects to detect differences.
###

.allEqualS4 <- function(x, y) {
  eq <- all.equal(x, y)
  canCompareS4 <- !isTRUE(eq) && isS4(x) && isS4(y) && class(x) == class(y)
  if (canCompareS4) {
    child.diffs <- mapply(.allEqualS4, attributes(x), attributes(y),
                          SIMPLIFY=FALSE)
    child.diffs$class <- NULL
    dfs <- mapply(function(d, nm) {
      if (!is.data.frame(d)) {
        data.frame(comparison = I(list(d)))
      } else d
    }, child.diffs, names(child.diffs), SIMPLIFY=FALSE)
    do.call(rbind, dfs)
  } else {
    eq[1]
  }
}

### NOT exported.
allEqualS4 <- function(x, y) {
  eq <- .allEqualS4(x, y)
  setNames(eq$comparison, rownames(eq))[sapply(eq$comparison, Negate(isTRUE))]
}

