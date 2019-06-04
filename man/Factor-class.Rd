\name{Factor-class}
\docType{class}

\alias{class:Factor}
\alias{Factor-class}
\alias{Factor}

\alias{parallelSlotNames,Factor-method}

\alias{names,Factor-method}
\alias{names<-,Factor-method}
\alias{levels<-,Factor-method}

\alias{unfactor}
\alias{unfactor,factor-method}
\alias{unfactor,Factor-method}

\alias{coerce,Vector,Factor-method}
\alias{as.integer,Factor-method}
\alias{as.factor,Factor-method}
\alias{as.character,Factor-method}

\alias{show,Factor-method}
\alias{showAsCell,Factor-method}

\alias{bindROWS,Factor-method}

\alias{pcompare,Factor,Factor-method}
%\alias{pcompare,Factor,Vector-method}
%\alias{pcompare,Vector,Factor-method}
\alias{match,Factor,Factor-method}
%\alias{match,Factor,Vector-method}
%\alias{match,Vector,Factor-method}
\alias{selfmatch,Factor-method}
\alias{xtfrm,Factor-method}

\title{Factor objects}

\description{
  The Factor class serves a similar role as \link{factor} in base R (a.k.a.
  ordinary factor) except that the levels of a Factor object can be any
  \link{Vector} derivative.

  A notable difference with ordinary factors is that Factor objects cannot
  contain \code{NA}s, at least for now.
}

\usage{
Factor(x, levels, index=NULL, ...)  # constructor function
}

\arguments{
  \item{x, levels}{
    \link{Vector} derivatives.
    \code{levels} cannot contain duplicates i.e. \code{anyDuplicated(levels)}
    must be 0. When \code{x} and \code{levels} are both specified,
    they should have the same class and all the elements in \code{x}
    must be represented in \code{levels}. See Details section below.
  }
  \item{index}{
    \code{NULL} or an integer (or numeric) vector of valid positive indices
    (no \code{NA}s) into \code{levels}. See Details section below.
  }
  \item{...}{
    Optional metadata columns.
  }
}

\details{
  There are 4 different ways to use the \code{Factor()} constructor function:
  \enumerate{
    \item \code{Factor(x, levels)} (i.e. \code{index} is missing):
          In this case \code{match(x, levels)} is used internally to encode
          \code{x} as a Factor object. An error is returned if some elements
          in \code{x} cannot be matched to \code{levels} so it's important to
          make sure that all the elements in \code{x} are represented in
          \code{levels} when doing \code{Factor(x, levels)}.

    \item \code{Factor(x)} (i.e. \code{levels} and \code{index} are missing):
          This is equivalent to \code{Factor(x, levels=unique(x))}.

    \item \code{Factor(levels=levels, index=index)} (i.e. \code{x} is missing):
          In this case the encoding of the Factor object is supplied via
          \code{index}, that is, \code{index} must be an integer (or numeric)
          vector of valid positive indices (no \code{NA}s) into \code{levels}.
          This is the most efficient way to construct a Factor object.

    \item \code{Factor(levels=levels)} (i.e. \code{x} and \code{index} are
          missing): This is a convenient way to construct a 0-length Factor
          object with the specified levels. In other words it's equivalent to
          \code{Factor(levels=levels, index=integer(0))}.
  }
}

\value{
  A Factor object.
}

\section{Accessors}{
  Factor objects support the same set of accessors as ordinary factors. That
  is:
  \itemize{
    \item \code{length(x)} to get the length of Factor object \code{x}.

    \item \code{names(x)} and \code{names(x) <- value} to get and set the
          names of Factor object \code{x}.

    \item \code{levels(x)} and \code{levels(x) <- value} to get and set the
          levels of Factor object \code{x}.

    \item \code{nlevels(x)} to get the number of levels of Factor
          object \code{x}.

    \item \code{as.integer(x)} to get the encoding of Factor object \code{x}.
          Note that \code{length(as.integer(x))} and
          \code{names(as.integer(x))} are the same as \code{length(x)}
          and \code{names(x)}, respectively.
  }

  In addition, because Factor objects are Vector derivatives, they support
  the \code{mcols()} and \code{metadata()} getters and setters.
}

\section{Decoding a Factor}{
  \code{unfactor(x)} can be used to decode Factor object \code{x}. It returns
  an object of the same class as \code{levels(x)}. Note that it is the
  analog of \code{as.character()} on ordinary factors, with the notable
  difference that \code{unfactor(x)} propagates the names on \code{x}.

  For convenience, \code{unfactor(x)} also works on ordinary factor \code{x}.

  \code{unfactor()} supports extra arguments \code{use.names} and
  \code{ignore.mcols} to control whether the names and metadata columns
  on the Factor object to decode should be propagated or not.
  By default they are propagated, that is, the default values for
  \code{use.names} and \code{ignore.mcols} are \code{TRUE} and \code{FALSE},
  respectively.
}

\section{Coercion}{
  From Vector to Factor: coercion of a Vector derivative \code{x} to
  Factor is supported via \code{as(x, "Factor")} and is equivalent to
  \code{Factor(x)}.

  From Factor to integer: \code{as.integer(x)} is supported on Factor object
  \code{x} and returns its encoding (see Accessors section above).

  From Factor to factor: \code{as.factor(x)} is supported on Factor object
  \code{x} and returns an ordinary factor where the levels are
  \code{as.character(levels(x))}.

  From Factor to character: \code{as.character(x)} is supported on Factor
  object \code{x} and is equivalent to \code{unfactor(as.factor(x))}, which
  is also equivalent to \code{as.character(unfactor(x))}.
}

\section{Subsetting}{
  A Factor object can be subsetted with \code{[}, like an ordinary factor.
}

\section{Concatenation}{
  2 or more Factor objects can be concatenated with \code{c()}.
  Note that, unlike with ordinary factors, \code{c()} on Factor objects
  preserves the class i.e. it returns a Factor object. In other words, 
  \code{c()} acts as an \emph{endomorphism} on Factor objects.

  The levels of \code{c(x, y)} are obtained by appending to \code{levels(x)}
  the levels in \code{levels(y)} that are "new" i.e. that are not already
  in \code{levels(x)}.

  \code{append()}, which is implemented on top of \code{c()}, also works
  on Factor objects.
}

\section{Comparing & ordering}{
  Comparing (with \code{==}, \code{!=}, \code{<=}, \code{>=}, \code{<},
  or \code{>}) or matching (with \code{match()}) 2 Factor objects is only
  supported when the 2 objects have identical levels at the moment.

  Comparison and ordering (e.g. \code{order()}, \code{sort()}, \code{rank()})
  operations on Factor objects are based on the encodings i.e. all these
  operations behave as if the encoding of the Factor objects (obtained with
  \code{as.integer()}) were passed to them.
}

\author{Hervé Pagès}

\seealso{
  \itemize{
    \item \link[base]{factor} in base R.

    \item \link{Vector} objects for the parent class.

    \item \code{\link[BiocGenerics]{anyDuplicated}} in the \pkg{BiocGenerics}
          package.
  }
}

\examples{
showClass("Factor")  # shows the known subclasses

## ---------------------------------------------------------------------
## CONSTRUCTION & ACCESSORS
## ---------------------------------------------------------------------
library(GenomicRanges)
set.seed(123)
ir0 <- IRanges(sample(5, 8, replace=TRUE), width=10, names=letters[1:8])
gr0 <- GRanges("chrA", ir0, ID=paste0("ID", 1:8))

## Use explicit levels:
gr1 <- GRanges("chrA", IRanges(1:6, width=10))
F1 <- Factor(gr0, levels=gr1)
F1
length(F1)
names(F1)
levels(F1)  # gr1
nlevels(F1)
as.integer(F1)  # encoding

## If we don't specify the levels, they'll be set to unique(gr0):
F2 <- Factor(gr0)
F2
length(F2)
names(F2)
levels(F2)  # unique(gr0)
nlevels(F2)
as.integer(F2)

## ---------------------------------------------------------------------
## DECODING
## ---------------------------------------------------------------------
unfactor(F1)

stopifnot(identical(gr0, unfactor(F1)))
stopifnot(identical(gr0, unfactor(F2)))

unfactor(F1, use.names=FALSE)
unfactor(F1, ignore.mcols=TRUE)

## ---------------------------------------------------------------------
## COERCION
## ---------------------------------------------------------------------
F2b <- as(gr0, "Factor")  # same as Factor(gr0)
stopifnot(identical(F2, F2b))

as.factor(F2)
as.factor(F1)

as.character(F1)  # same as unfactor(as.factor(F1)),
                  # and also same as as.character(unfactor(F1))

## ---------------------------------------------------------------------
## CONCATENATION
## ---------------------------------------------------------------------
gr3 <- GRanges("chrA", IRanges(c(5, 2, 8:6), width=10))
F3 <- Factor(levels=gr3, index=2:4)
F13 <- c(F1, F3)
F13
levels(F13)

stopifnot(identical(c(unfactor(F1), unfactor(F3)), unfactor(F13)))

## ---------------------------------------------------------------------
## COMPARING & ORDERING
## ---------------------------------------------------------------------
\dontrun{
  F1 == F2  # Error! (levels(F1) and levels(F2) are not identical)
}

order(F1)  # same as order(as.integer(F1))
order(F2)  # same as order(as.integer(F2))

## The levels of the Factor influence the order of the table:
table(F1)
table(F2)
}
\keyword{methods}
\keyword{classes}