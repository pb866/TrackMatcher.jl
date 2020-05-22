TrackMatcher
============

Overview
--------

`TrackMatcher` is a Julia package to find intersections between airplane and CALIPSO satellite flight tracks and store relevant data in the vicinity of the intersection.


Installation
------------

`TrackMatcher` is an unregistered Julia package, but can be installed by the
package manager with:

```julia
julia> ]
pkg> add https://github.com/pb866/TrackMatcher.jl.git
pkg> instantiate
```


Usage
-----

In essence, 3 `TrackMatcher` structs are needed to load essential flight and satellite data, and find intersection in the stored track data. A full overview is given in the [WIKI](https://github.com/pb866/TrackMatcher.jl/wiki) and this README is only meant as a quick reminder of the most important functions.


Loading flight data
-------------------

`FlightData` of individual flights are loaded into a `FlightDB` with vectors of `FlightData` for different database types, currently holding

1. VOLPE AEDT inventory (`i` or `1`)
2. FlightAware archived data (`a` or `2`)
3. flightaware.com online data (`o` or `3`)

A convenience constructor for `FlightDB` exists needing only the database type listed in a string with the letters or numbers as indicated in the list above and the directories of the main database folders. Those folders are searched recursively for the respective data files. More than one folder path can be listed for all the database types.
The order in the list is free, but the order of folders must correspond to the order
of dataset identifiers in `DBtype`:

```julia
FlightDB(DBtype::String, folder::Union{String, Vector{String}}...; kwargs)
```

### kwargs
- `altmin::Int=15_000`: minimum altitude threshold for which to consider flight data
- `remarks=nothing`: any data or comments that can be attached to the metadata of `FlightDB`
- `odelim::Union{Nothing,Char,String}=nothing`: specify the column delimiter in the text files of the online data


Loading CALIOP data from the CALIPSO satellite
----------------------------------------------

CALIPSO positions and overpass times together with a file index of the corresponding
granule hdf file are stored in the `data` field of `SatData`. Only one of the `type`s
cloud profile (`CPro`) or cloud layer (`CLay`) data can be used to construct `SatData`.
The `metadata` holds a `Dict` with the `fileindex` pointing to a file name (including
the absolute folder path). 
__File names/position must not be changed in order for _TrackMatcher_ to work correctly.__
Further information in the `metadata` include the `type` of the satellite data,
the `date` range of the data, the time the database was `created`, the `loadtime`,
and any `remarks` as additional data or comments.

`SatData` can be instatiated, by giving any number of folder strings and any remarks
using the keyword `remarks`. The `folders` are scanned recursively for any hdf files
and the `type` of the satellite data is determined by keywords `CLay` or `CPro` in
the folder/file names. If both types exist in the `folders`, the data type is determined
by the first 50 file names.

```julia
SatData(folders::String...; remarks=nothing)
```

---
> :information_source: **NOTE**
>
> `SatData` is designed to use CALIPSO data provided by the [AERIS/ICARE Data and Services Centre](http://www.icare.univ-lille1.fr/). 
> For the best performance, you should use the same file/folder format as used by ICARE. 
> In particular, Cloud layer files must include the keyword `CLay` in the file name
> and cloud profile data files the keyword `CPro`.
---


Finding intersections in the trajectories of the flight and satellite data
--------------------------------------------------------------------------

Intersections and corresponding accuracies and flight/satellite data in the vicinity of the intersection are stored in the `Intersection` struct.

A convenience constructor exists for automatic calculation of the intersections 
from the `FlightDB` and `SatData` with parameters controlling these calculations. 
Additionally, it can be specified by the keyword `savesecondsattype` whether the 
corresponding satellite data type of the `CLay` or `CPro` data stored in `SatData`
should be saved as well. 
__For this feature to work, folder and file names of `Clay`/`CPro` data must be identical__
__except for the keywords `CLay`/`CPro` swapped.__

Find intersections by instatiating the `Intersection` struct with:

```julia
Intersection(
  flights::FlightDB, 
  sat::SatData, 
  savesecondsattype::Bool=false;
  maxtimediff::Int=30, 
  flightspan::Int=0, 
  satspan::Int=15, 
  lidarrange::Tuple{Real,Real}=(15,-Inf),
  stepwidth::AbstractFloat=0.01, 
  Xradius::Real=5000, 
  remarks=nothing)
```

### kwargs

- `maxtimediff::Int=30`: maximum delay at intersection between aircraft/satellite overpass
- `flightspan::Int=0`: number of flight data points saved before and after the closest measurement to the intersection
- `satspan::Int=15`: number of satellite data points saved before and after the closest measurement to the intersection
- `lidarrange::Tuple{Real,Real}=(15,-Inf)`: top/bottom bounds of the lidar column data, between which
  data is stored; use `(Inf, -Inf)` to store the whole column
- `stepwidth::Float64=0.01`: stepwidth in degrees (at the equator) used for the 
  interpolation of flight and satellite tracks
- `Xradius::Real=5000`: Radius in meters, in which multiple intersection finds are
  assumed to correspond to the same intersection and only the intersection with the
  minimum delay between flight and sat overpass is saved
- `remarks=nothing`: any data or comments that can be attached to the metadata of `Intersection`
