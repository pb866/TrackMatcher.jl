TrackMatcher
============

Overview
--------

`TrackMatcher` is a Julia package to find intersections between two sets of trajectories.
The current version can match aircraft- or cloud-track (primary) data with CALIPSO satellite 
(secondary) ground tracks and store relevant data in the vicinity of the intersection.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.6193048.svg)](https://zenodo.org/records/6193048)


Installation
------------

`TrackMatcher` is an unregistered Julia package, but can be installed with the
package manager. `TrackMatcher` uses the `PCHIP.jl` package developed within the
`TrackMatcher` framework. It is a pure Julia implementation of the Peacewise Cubic
Hermite Interpolating Polynomial. `PCHIP` has to be installed prior to `TrackMatcher`
as Julia currently only acknowledges registered dependencies.

```julia
julia> ]
pkg> add https://github.com/LIM-AeroCloud/PCHIP.jl.git
pkg> add https://github.com/LIM-AeroCloud/TrackMatcher.jl.git
```


Usage
-----

In essence, 3 `TrackMatcher` structs are needed to load essential primary and secondary data, 
and find intersections in the stored track data. A full overview is given in the 
[WIKI](https://github.com/LIM-AeroCloud/TrackMatcher.jl/wiki) and this README is 
only meant as a quick reminder of the most important functions. Additionally, Julia's
help function can be used by pressing `?` and the respective function name or 
type constructor.


Loading primary data
--------------------

`FlightData` or `FlightTrack` of individual flights are loaded into a `FlightSet` 
with vectors of `FlightData` for different database types, currently holding

1. VOLPE AEDT inventory (field/keyword `volpe`)
2. FlightAware archived data (field/keyword  `flightaware`)
3. flightaware.com online data (field/keyword  `webdata`)

A convenience constructor for `FlightSet` exists, where data can be loaded by passing 
a `String` or `Vector{String}` with directories of the input data files for each 
source type to the individual fields of `FlightSet` using the keyword arguments listed
above. Those folders are searched recursively for the respective data files. More than 
one folder path can be listed for all the database types in a `Vector{String}`.

```julia
FlightSet{T}(;
  volpe::Union{String,Vector{String}}=String[],
  flightaware::Union{String,Vector{String}}=String[],
  webdata::Union{String,Vector{String}}=String[],
  altmin::Real=5000,
  odelim::Union{Nothing,Char,String}=nothing,
  savedir::Union{String,Bool}="abs",
  remarks=nothing
) where T
```

A similar convenience constructor exists for `CloudTrack`s. As only one database type
exists, only the directories are needed as `vararg` rather than `kwarg`:

```julia
CloudSet{T}(
  folders::String...;
  savedir::Union{String,Bool}="abs",
  structname::String="cloud",
  remarks=nothing
) where T
```

For details on the kwargs, see the [WIKI](https://github.com/LIM-AeroCloud/TrackMatcher.jl/wiki)
or use the help function for the individual constructors.


Loading CALIOP data from the CALIPSO satellite
----------------------------------------------

Initially, only CALIPSO positions (lat/lon) and overpass times are stored as `SatData`
in a `SatSet` for performance reasons. Each granule is stored as `SatData` or `SatTrack`,
which are combined in the `granules` field of `SatSet`. Only one of the `type`s
cloud profile (`CPro`) or cloud layer (`CLay`) data can be used to construct a `SatSet`.

In the vicinity of intersections, additional observations can be stored as `CPro` or
`CLay` structs.
__This feature is only available, if the file/folder structure does not change between__
__loading the data and calculating intersections.__  It can be controlled with the
`savedir` keyword argument.

The `SatSet` `metadata` includes information about the granules, the `type` of the 
satellite data, the `date` range of the data, the time the database was `created`, 
the `loadtime`, and any `remarks` as additional data or comments.

A `SatSet` can be constructed by giving any number of folder strings and any remarks
using the keyword `remarks`. The `folders` are scanned recursively for any hdf file
and the `type` of the satellite data is determined by keywords `CLay` or `CPro` in
the folder/file names. If both types exist in the `folders`, the data type is determined
by the majority in the first 50 file names. Alternatively, the sat data type can
be forced with the keyword `type` set to a `Symbol` `:CPro` or `:CLay`.

```julia
SatSet{T}(
  folders::String...;
  type::Symbol=:undef,
  savedir::Union{String,Bool}="abs",
  remarks=nothing
) where T
```

---
> :information_source: **NOTE**
>
> `SatSet` is designed to use CALIPSO data provided by the [AERIS/ICARE Data and Services Centre](http://www.icare.univ-lille1.fr/). 
> For the best performance, you should use the same file/folder format as used by ICARE. 
> In particular, Cloud layer files must include the keyword `CLay` in the file name
> and cloud profile data files the keyword `CPro`.
---


Finding intersections in the trajectories of the flight and satellite data
--------------------------------------------------------------------------

Intersections and corresponding accuracies and observation data in the vicinity 
of the intersection are stored in the `XData` struct. Alternatively, an `Intersection`
constructor can be used for the construction of `XData`.

A convenience constructor exists for automatic calculation of the intersections 
from the `FlightSet` and `SatSet` with parameters controlling these calculations. 
Additionally, it can be specified by the optional argument `savesecondsattype` 
whether both satellite data types `CLay` and `CPro` should be stored in `SatSet`
or only the specified main type. 
__For this feature to work, folder and file names of `Clay`/`CPro` data must be identical__
__except for the keywords `CLay`/`CPro` swapped.__

Find intersections by instatiating the `Intersection` struct with:

```julia
Intersection{T}(
  tracks::PrimarySet,
  sat::SatSet,
  savesecondsattype::Bool=false;
  maxtimediff::Int=30,
  primspan::Int=0,
  secspan::Int=15,
  lidarrange::Tuple{Real,Real}=(15_000,-Inf),
  stepwidth::Real=0.01,
  Xradius::Real=20_000,
  expdist::Real=Inf,
  atol::Real=0.1,
  savedir::Union{String,Bool}="abs",
  remarks=nothing
) where T
```

### kwargs

- `maxtimediff::Int=30`: maximum delay at intersection between aircraft/satellite overpass
- `primspan::Int=0`: number of primary (flight or cloud) data points saved before and after the closest measurement to the intersection
- `secspan::Int=15`: number of secondary (satellite) data points saved before and after the closest measurement to the intersection
- `lidarrange::Tuple{Real,Real}=(15_000,-Inf)`: top/bottom bounds of the lidar column data, between which
  data is stored; use `(Inf, -Inf)` to store the whole column
- `stepwidth::Float64=1000`: stepwidth in degrees (at the equator) used for the 
  interpolation of flight and satellite tracks
- `Xradius::Real=20_000`: Radius in meters, in which multiple intersection finds are
  assumed to correspond to the same intersection and only the intersection with the
  minimum delay between flight and sat overpass is saved
- `expdist::Real=Inf`: maximum threshold for the distance of a found intersection to the nearest measured track point
- `atol::Real=0.1`: tolerance to increase the bounding box around primary tracks by `atol` degrees
  increasing the search radius in secondary tracks preventing the omission of intersections due to
  rounding errors
- `savedir::Union{String,Bool}="abs"`: options to save absolute (`"abs"`) or relative
  (`"rel"`) folder paths in the `metadata` of  `FlightData` or `SatSet`. When `savedir`
  is set to an empty string (`""`) or `false`, folder strings are save as given in
  the constructor. When set to an empty string or `false` in the `Intersection` constructor,
  no observations are saved in `Intersection`.
- `remarks=nothing`: any data or comments that can be attached to the metadata of `Intersection`
