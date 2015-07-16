.test <- function() BiocGenerics:::testPackage("S4Vectors")

.onLoad <- function(libname, pkgname)
    setMethod("nchar", "Rle", .nchar_Rle)
