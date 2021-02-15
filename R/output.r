##' Xlsx reporting of results
##'
##' Store all the differential gene-lists and supporting materials
##' in a multi-worksheet spreadsheet
##' @title XLSX report of results
##' @param ddsList A list of [DESeq2::DESeqDataSet-class()] objects generated by DESdemonA containing results in the mcols slot
##' @param param The parameter object used to generate the results
##' @param dir Directory to store the results in
##' @return A list of file paths to the excel files
##' @author Gavin Kelly
write_results <- function(ddsList, param, dir=".") {
  si <- session_info()
  crick_colours <-list(
    primary=list(red="#e3001a",yellow="#ffe608",blue="#4066aa",green="#7ab51d",purple="#bb90bd"),
    secondary=list(pink="#fadbd9", yellow="#fff6a7", green="#adcf82", orange="#ffe7ab", blue="#bee2e6"),
    spare=list(blue="#95ceed"))
  hs1 <- createStyle(fgFill = crick_colours$secondary$orange, textDecoration = "italic",
                    border = "Bottom")
  hs2 <- createStyle(fgFill = crick_colours$secondary$blue, textDecoration = "italic",
                    border = "Bottom")
  summaries <- map_depth(ddsList, 3, DESdemonA::summarise_results)
  out <- lapply(ddsList, function(x) "")
  for (dataset in names(ddsList)) {
    wb <- openxlsx::createWorkbook(title=param$get("title"),
                                  creator="Gavin Kelly")
    tmp <- param$describe()
    dframe <- data.frame(id=names(tmp), description=unlist(tmp))
    sn <- "Parameters"
    addWorksheet(wb, sn)
    writeData(wb, sn, dframe,rowNames=FALSE, colNames=TRUE)
    ## Design
    samples_used <- as.data.frame(colData(ddsList[[dataset]][[1]][[1]]))
    sn <- "Design"
    addWorksheet(wb, sn)
    writeData(wb, sn, samples_used, headerStyle=hs2)
    sn <- "Class Sizes"
    addWorksheet(wb, sn)
    dframe <- DESdemonA::rbind_summary(
      summaries[[dataset]],
      levels=c("Design","Comparison")
    )
    writeData(wb, sn, dframe, headerStyle=hs2)
    ## Differential gene-lists
    for (design_ind in 1:length(ddsList[[dataset]])) {
      for (contrast_name in names(ddsList[[dataset]][[design_ind]])) {
        dframe <- as.data.frame(mcols(ddsList[[dataset]][[design_ind]][[contrast_name]])$results) %>%
          tibble::rownames_to_column("id") %>%
          dplyr::filter(padj<param$get("alpha")) %>%
          dplyr::arrange(desc(abs(shrunkLFC))) %>%
          dplyr::select(-pvalue, -padj)
        if (length(ddsList[[dataset]])==1) {
          sn <- contrast_name
        } else {
          sn <- paste0(contrast_name, ", ", names(ddsList[[dataset]])[design_ind])
        }
        addWorksheet(wb, sn, tabColour=crick_colours$secondary[[design_ind]])
        writeData(wb, sn, dframe, headerStyle=hs1)
      }
    }
    ## sn <- "GO terms"
    ## addWorksheet(wb, sn)
    ## writeData(wb, sn, go_df, headerStyle=hs1)
    sn <- "R Packages"
    addWorksheet(wb, sn)
    writeData(wb, sn, as.data.frame(si$packages), headerStyle=hs2)
    sn <- "R Details"
    addWorksheet(wb, sn)
    writeData(wb, sn, data.frame(setting = names(si$platform),
                                 value = unlist(si$platform),
                                 stringsAsFactors = FALSE),
              headerStyle=hs2)
    out[[dataset]] <- file.path(dir, paste0("differential_genelists_", dataset, ".xlsx"))
    saveWorkbook(wb, out[[dataset]], overwrite=TRUE)
  }
  out
}

##' Store results as text files
##'
##' Save unfiltered versions of the results in text files
##' @title Store results as text files
##' @param ddsList A list of [DESeq2::DESeqDataSet-class()] objects generated by DESdemonA containing results in the [S4Vectors::mcols()] slot
##' @param dir Directory to store the results in
##' @return 
##' @author Gavin Kelly
write_all_results <- function(ddsList, dir=".") {
  for (i in names(ddsList)) {
    for (j in names(ddsList[[i]])) { 
      for (k in names(ddsList[[i]][[k]])) { 
        readr::write_excel_csv(
          path=file.path(dir, sprintf("allgenes_%s_%s_%s.csv", i, j, k)),
          x=as.data.frame(mcols(ddsList[[i]][[j]][[k]])$results) %>% dplyr::select(log2FoldChange, stat, symbol, class))
      }
    }
  }
}
