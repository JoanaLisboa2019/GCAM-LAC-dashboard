% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/server-helpers.R
\name{plotMap}
\alias{plotMap}
\title{Plot GCAM data on a global or regional map}
\usage{
plotMap(prjdata, query, scen, diffscen, projselect, subcat, year,
  filters = NULL, map = NULL, zoom = 0)
}
\arguments{
\item{prjdata}{Project data file}

\item{query}{Name of the query to plot}

\item{scen}{Name of the scenario to plot}

\item{diffscen}{Name of the scenario to difference against pltscen, or NULL if none}

\item{projselect}{Projection to use for the map}

\item{subcat}{Name of the subcategory to plot}

\item{year}{Year to plot data for}

\item{filters}{Named list of variables and values to filter to}

\item{map}{Base map to plot on (for gridded data only)}

\item{zoom}{Map zoom level}
}
\description{
Plot GCAM data on a global or regional map
}
