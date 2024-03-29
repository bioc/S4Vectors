\name{DataFrame-class}
\docType{class}

\alias{class:DataFrame}
\alias{DataFrame-class}

\alias{class:DFrame}
\alias{DFrame-class}
\alias{DFrame}

\alias{vertical_slot_names,DFrame-method}
\alias{horizontal_slot_names,DFrame-method}

\alias{updateObject,DataFrame-method}

% accessor
\alias{ncol,DataFrame-method}
\alias{colnames,DataFrame-method}
\alias{length,DataFrame-method}
\alias{names,DataFrame-method}
\alias{nrow,DataFrame-method}
\alias{rownames,DataFrame-method}
\alias{rownames<-,DFrame-method}
\alias{colnames<-,DataFrame-method}
\alias{dimnames<-,DataFrame-method}

% constructors
\alias{DataFrame}
\alias{make_zero_col_DFrame}

% subsetting
\alias{getListElement,DataFrame-method}
\alias{[[,DataFrame-method}
\alias{[[,DFrame-method}
\alias{extractROWS,DataFrame,ANY-method}
\alias{extractCOLS,DataFrame-method}
\alias{[,DataFrame-method}
\alias{replaceROWS,DFrame-method}
\alias{mergeROWS,DFrame-method}
\alias{replaceCOLS,DFrame-method}
\alias{[<-,DataFrame-method}
\alias{[[<-,DFrame-method}
\alias{[[,DataFrame-method}
\alias{droplevels,DFrame-method}
\alias{rep,DataFrame-method}

% coercion
\alias{as.data.frame.DataFrame}
\alias{as.data.frame,DataFrame-method}
\alias{as.matrix,DataFrame-method}
\alias{coerce,data.frame,DFrame-method}
\alias{coerce,data.table,DFrame-method}
\alias{coerce,table,DFrame-method}
\alias{coerce,xtabs,DFrame-method}
\alias{coerce,ANY,DFrame-method}
\alias{coerce,ANY,DataFrame-method}
\alias{coerce,SimpleList,DataFrame-method}
\alias{coerce,SimpleList,DFrame-method}
\alias{coerce,Vector,DFrame-method}
\alias{coerce,list,DFrame-method}
\alias{coerce,NULL,DFrame-method}
\alias{coerce,AsIs,DFrame-method}
\alias{coerce,ANY,DataFrame_OR_NULL-method}

% display
\alias{classNameForDisplay,DFrame-method}
\alias{makeNakedCharacterMatrixForDisplay,DataFrame-method}
\alias{show,DataFrame-method}
\alias{showAsCell,DataFrame-method}

\title{DataFrame objects}

\description{
  The \code{DataFrame} class extends the \link{RectangularData} virtual
  class supports the storage of any type of object (with \code{length}
  and \code{[} methods) as columns.
}

\details{
  On the whole, the \code{DataFrame} behaves very similarly to
  \code{data.frame}, in terms of construction, subsetting, splitting,
  combining, etc. The most notable exceptions have to do with handling
  of the row names:
  \enumerate{
    \item The row names are optional. This means calling \code{rownames(x)}
          will return \code{NULL} if there are no row names. Of course, it
          could return \code{seq_len(nrow(x))}, but returning \code{NULL}
          informs, for example, combination functions that no row names are
          desired (they are often a luxury when dealing with large data).
    \item The row names are not required to be unique.
    \item Subsetting by row names does not use partial matching.
  }

  As \code{DataFrame} derives from \code{\linkS4class{Vector}}, it is
  possible to set an \code{annotation} string. Also, another
  \code{DataFrame} can hold metadata on the columns.

  For a class to be supported as a column, it must have \code{length}
  and \code{[} methods, where \code{[} supports subsetting only by
  \code{i} and respects \code{drop=FALSE}. Optionally, a method may be
  defined for the \code{showAsCell} generic, which should return a
  vector of the same length as the subset of the column passed to
  it. This vector is then placed into a \code{data.frame} and converted
  to text with \code{format}. Thus, each element of the vector should be
  some simple, usually character, representation of the corresponding
  element in the column.
}

\section{Constructor}{
  \describe{
    \item{\code{DataFrame(..., row.names = NULL, check.names = TRUE,
                      stringsAsFactors)}:}{

      Constructs a \code{DataFrame} in similar fashion to
      \code{\link{data.frame}}. Each argument in \code{...} is coerced to
      a \code{DataFrame} and combined column-wise.
      The row names should be given in
      \code{row.names}; otherwise, they are inherited from the
      arguments, as in \code{data.frame}. Explicitly passing
      \code{NULL} to \code{row.names} ensures that there are no rownames.
      If \code{check.names} is \code{TRUE}, the column names will
      be checked for syntactic validity and made unique, if necessary.

      To store an object of a class that does not support coercion to
      \code{DataFrame}, wrap it in \code{I()}. The class must still have
      methods for \code{length} and \code{[}.

      The \code{stringsAsFactors} argument is ignored. The coercion of
      column arguments to DataFrame determines whether strings
      become factors.
    }
    \item{\code{make_zero_col_DFrame(nrow)}:}{

      Constructs a zero-column DFrame object with \code{nrow} rows.
      Intended for developers to use in other packages and typically
      not needed by the end user.
    }
  }
}

\section{Accessors}{
  In the following code snippets, \code{x} is a \code{DataFrame}.
  \describe{
    \item{\code{dim(x)}:}{
      Get the length two integer vector indicating in the first and
      second element the number of rows and columns, respectively.
    }
    \item{\code{dimnames(x)}, \code{dimnames(x) <- value}:}{
      Get and set the two element list containing the row names
      (character vector of length \code{nrow(x)} or \code{NULL})
      and the column names (character vector of length \code{ncol(x)}).
    }
  }
}

\section{Coercion}{
  \describe{
    \item{\code{as(from, "DataFrame")}:}{
      By default, constructs a new \code{DataFrame} with \code{from} as
      its only column. If \code{from} is a \code{matrix} or
      \code{data.frame}, all of its columns become columns in the new
      \code{DataFrame}. If \code{from} is a list, each element becomes a
      column, recycling as necessary. Note that for the \code{DataFrame}
      to behave correctly, each column object must support element-wise
      subsetting via the \code{[} method and return the number of elements with
      \code{length}. It is recommended to use the \code{DataFrame} 
      constructor, rather than this interface.
    }
    \item{\code{as.list(x)}:}{ Coerces \code{x}, a \code{DataFrame},
      to a \code{list}.
    }
    \item{\code{as.data.frame(x, row.names=NULL, optional=FALSE,
                              make.names=TRUE)}:}{
      Coerces \code{x}, a \code{DataFrame}, to a \code{data.frame}.
      Each column is coerced to a \code{data.frame} and then column
      bound together. If \code{row.names} is \code{NULL}, they are
      propagated from \code{x}, if it has any. Otherwise, they are
      inferred by the \code{data.frame} constructor.

      Like the \code{as.data.frame()} method for class \code{matrix},
      the method for class \code{DataFrame} supports the \code{make.names}
      argument. \code{make.names} can be set to \code{TRUE} or \code{FALSE}
      to indicate what should happen if the row names of \code{x} (or the
      row names supplied via the \code{row.names} argument) are invalid
      (e.g. contain duplicates). If they are invalid, and \code{make.names}
      is \code{TRUE} (the default), they get "fixed" by going thru
      \code{make.names(*, unique=TRUE)}. Otherwise (i.e. if \code{make.names}
      is \code{FALSE}), an error is raised. Note that unlike the method
      for class \code{matrix}, \code{make.names=NA} is not supported.

      NOTE: Conversion of \code{x} to a \code{data.frame} is not
      supported if \code{x} contains any \code{list}, \code{SimpleList},
      or \code{CompressedList} columns.
    }
    \item{\code{as(from, "data.frame")}:}{ Coerces a \code{DataFrame}
      to a \code{data.frame} by calling \code{as.data.frame(from)}.
    }
    \item{\code{as.matrix(x)}:}{ Coerces the \code{DataFrame} to a
      \code{matrix}, if possible.
    }
    \item{\code{as.env(x, enclos = parent.frame())}:}{
      Creates an environment from \code{x} with a symbol for each
      \code{colnames(x)}. The values are not actually copied into the
      environment. Rather, they are dynamically bound using
      \code{\link{makeActiveBinding}}. This prevents unnecessary copying
      of the data from the external vectors into R vectors. The values
      are cached, so that the data is not copied every time the symbol
      is accessed.
    }
  }
}

\section{Subsetting}{
  In the following code snippets, \code{x} is a \code{DataFrame}.
  \describe{
    \item{\code{x[i,j,drop]}:}{ Behaves very similarly to the
      \code{\link{[.data.frame}} method, except \code{i} can be a
      logical \code{Rle} object and subsetting by \code{matrix} indices
      is not supported. Indices containing \code{NA}'s are also not
      supported.
    }
    \item{\code{x[i,j] <- value}:}{ Behaves very similarly to the
      \code{\link{[<-.data.frame}} method.
    }
    \item{\code{x[[i]]}:}{ Behaves very similarly to the
      \code{\link{[[.data.frame}} method, except arguments \code{j}
      and \code{exact} are not supported. Column name matching is
      always exact. Subsetting by matrices is not supported.
    }
    \item{\code{x[[i]] <- value}:}{ Behaves very similarly to the
      \code{\link{[[<-.data.frame}} method, except argument \code{j}
      is not supported.
    }
  }
}

\section{Displaying}{
  The \code{show()} method for DataFrame objects obeys global options
  \code{showHeadLines} and \code{showTailLines} for controlling the number
  of head and tail rows to display.
  See \code{?\link{get_showHeadLines}} for more information.
}

\author{Michael Lawrence}

\seealso{
  \itemize{
    \item \link{DataFrame-combine} for combining DataFrame objects.

    \item \link{DataFrame-utils} for other common operations on DataFrame
          objects.

    \item \link{TransposedDataFrame} objects.

    \item \link{RectangularData} and \link{SimpleList} which DataFrame extends
          directly.

    \item \code{\link{get_showHeadLines}} for controlling the number of
          DataFrame rows to display.
  }
}

\examples{
score <- c(1L, 3L, NA)
counts <- c(10L, 2L, NA)
row.names <- c("one", "two", "three")
  
df <- DataFrame(score) # single column
df[["score"]]
df <- DataFrame(score, row.names = row.names) #with row names
rownames(df)
  
df <- DataFrame(vals = score) # explicit naming
df[["vals"]]

# arrays
ary <- array(1:4, c(2,1,2))
sw <- DataFrame(I(ary))  
  
# a data.frame
sw <- DataFrame(swiss)
as.data.frame(sw) # swiss, without row names
# now with row names
sw <- DataFrame(swiss, row.names = rownames(swiss))
as.data.frame(sw) # swiss

# subsetting
    
sw[] # identity subset
sw[,] # same

sw[NULL] # no columns
sw[,NULL] # no columns
sw[NULL,] # no rows

## select columns
sw[1:3]
sw[,1:3] # same as above
sw[,"Fertility"]
sw[,c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)]

## select rows and columns
sw[4:5, 1:3]
  
sw[1] # one-column DataFrame
## the same
sw[, 1, drop = FALSE]
sw[, 1] # a (unnamed) vector
sw[[1]] # the same
sw[["Fertility"]]

sw[["Fert"]] # should return 'NULL'
 
sw[1,] # a one-row DataFrame
sw[1,, drop=TRUE] # a list

## duplicate row, unique row names are created
sw[c(1, 1:2),]

## indexing by row names  
sw["Courtelary",]
subsw <- sw[1:5,1:4]
subsw["C",] # no partial match (unlike with data.frame)

## row and column names
cn <- paste("X", seq_len(ncol(swiss)), sep = ".")
colnames(sw) <- cn
colnames(sw)
rn <- seq(nrow(sw))
rownames(sw) <- rn
rownames(sw)

## column replacement

df[["counts"]] <- counts
df[["counts"]]
df[[3]] <- score
df[["X"]]
df[[3]] <- NULL # deletion
}
\keyword{classes}
\keyword{methods}
