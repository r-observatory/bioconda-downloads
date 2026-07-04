test_that("parse_views_packages extracts Package fields from a VIEWS blob", {
  txt <- paste(c("Package: DESeq2", "Version: 1.44.0", "biocViews: RNASeq", "",
                 "Package: Biobase", "Version: 2.64.0"), collapse = "\n")
  expect_equal(parse_views_packages(txt), c("DESeq2", "Biobase"))
})

test_that("bioc_names fetches canonical Bioconductor names", {
  skip_on_cran(); testthat::skip_if_offline()
  nm <- tryCatch(default_io()$bioc_names(), error = function(e) skip("bioc VIEWS unreachable"))
  if (length(nm) == 0) skip("bioc VIEWS returned nothing")
  expect_true(length(nm) > 1000)
  expect_true("DESeq2" %in% nm)
})
