## Define Metadata structs

"""
# struct FlightMetadata{T}

Immutable struct holding metadata for an individual `FlightTrack` of the `FlightSet` with fields

- `dbID::Union{Int,AbstractString}`
- `flightID::Union{Missing,AbstractString}`
- `route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}}`
- `aircraft::Union{Missing,AbstractString}`
- `date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}`
- `area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,AbstractFloat}}`
- `flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,AbstractFloat,AbstractFloat}}}}`
- `useLON::Bool`
- `source::AbstractString`
- `file::AbstractString`

By default, `Float32` is used for `T`.

## dbID
Database ID – integer counter for `volpe`,
String with information about `FlightID`, `route`, and/or scheduled arrival for
FlightAware data.

## FlightID and aircraft
Strings with aircraft identification and type.

## route
`NamedTuple` with fields for `orig`in and `dest`ination holding ICAO airport codes.

## area
`NamedTuple` with fields for latitude and Longitude range. For the longitude range,
it is distinguished between positive and negative ranges to avoid problems with
flights passing the date line.

Fields:
- `latmin`
- `latmax`
- `elonmin`
- `elonmax`
- `wlonmin`
- `wlonmax`

## date
`NamedTuple` with fields `start` and `stop` for start and end time of the current
flight.

## flex
`Tuple` of `NamedTuple`s with entries
- `range` (`UnitRange`): flight segment between inflection points of the current flight track
- `min` (`AbstractFloat`): minimum x value in the flight segment
- `max` (`AbstractFloat`): maximum x value in the flight segment

## useLON
Flag (`Bool`) whether to use longitude as x data for track interpolation.

## source
String describing the database source of the current flight:
- `"VOLPE"`
- `"FlightAware"`
- `"flightaware.com"`

## file
String holding the absolute folder path and file name.


# Instantiation

`FlightMetadata` is constructed automatically, when `FlightTrack` is instantiated using
a modified constructor and `dbID`, `flightID`, `aircraft` type, `route`, `useLON`,
`flex`, `source`, and `file`.
Fields `area` and `date` are calculated from `lat`/`lon`, and `date` vectors.

    function FlightMetadata{T}(
      dbID::Union{Int,AbstractString},
      flightID::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
      aircraft::Union{Missing,AbstractString},
      date::Vector{DateTime},
      lat::Vector{<:Union{Missing,T}},
      lon::Vector{<:Union{Missing,T}},
      useLON::Bool,
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
      source::AbstractString,
      file::AbstractString
    ) where T -> struct FlightMetadata

Or construct `FlightMetadata` by directly handing over every field:

    function FlightMetadata{T}(
      dbID::Union{Int,AbstractString},
      flightID::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
      aircraft::Union{Missing,AbstractString},
      date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}},
      area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}},
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
      useLON::Bool,
      source::AbstractString,
      file::AbstractString
    ) where T -> struct FlightMetadata
"""
struct FlightMetadata{T} <: FlightTrack{T}
  dbID::Union{Int,AbstractString}
  flightID::Union{Missing,AbstractString}
  route::Union{Missing,NamedTuple{(:orig,:dest),Tuple{AbstractString,AbstractString}}}
  aircraft::Union{Missing,AbstractString}
  date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}
  area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}}
  flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}}
  useLON::Bool
  source::AbstractString
  file::AbstractString

  """ Unmodified constructor for `FlightMetadata` """
  function FlightMetadata{T}(
    dbID::Union{Int,AbstractString},
    flightID::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
    aircraft::Union{Missing,AbstractString},
    date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}},
    area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}},
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
    useLON::Bool,
    source::AbstractString,
    file::AbstractString
  ) where T
    # T = typeof(area.latmin)
    new{T}(dbID, flightID, route, aircraft, date, area, flex, useLON, source, file)
  end #constructor 1 FlightMetadata

  """
  Modified constructor for FlightMetadata with some automated construction of fields
  and variable checks.
  """
  function FlightMetadata{T}(
    dbID::Union{Int,AbstractString},
    flightID::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
    aircraft::Union{Missing,AbstractString},
    date::Vector{DateTime},
    lat::Vector{<:Union{Missing,T}},
    lon::Vector{<:Union{Missing,T}},
    useLON::Bool,
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
    source::AbstractString,
    file::AbstractString
  ) where T
    elonmin, elonmax = lonextrema(lon, ≥)
    wlonmin, wlonmax = lonextrema(lon, <)
    area = (latmin=minimum(lat), latmax=maximum(lat), elonmin, elonmax, wlonmin, wlonmax)
    new{T}(dbID, flightID, route, aircraft, (start=date[1], stop=date[end]), area,
      flex, useLON, source, file)
  end #constructor 2 FlightMetadata
end #struct FlightMetadata

"""
    FlightMetadata{T}() where T

External constructor for empty FlightMetadata struct.
"""
FlightMetadata{T}() where T = FlightMetadata{T}(
  "", missing, missing, missing, (start=Dates.now(), stop=Dates.now()),
  (latmin=T(NaN), latmax=T(NaN), elonmin=T(NaN), elonmax=T(NaN), wlonmin=T(NaN), wlonmax=T(NaN)),
  ((range=0:0, min=T(NaN), max=T(NaN)),), false, "", ""
)

"""
    FlightMetadata{T}(meta::FlightMetadata) where T

External FlightMetadata constructor for floating point conversions.
"""
FlightMetadata{T}(meta::FlightMetadata) where T = FlightMetadata{T}(
  meta.dbID, meta.flightID, meta.route, meta.aircraft, meta.date,
  (latmin = T(meta.area.latmin), latmax = T(meta.area.latmax), elonmin = T(meta.area.elonmin),
  elonmax = T(meta.area.elonmax), wlonmin = T(meta.area.wlonmin), wlonmax = T(meta.area.wlonmax)),
  Tuple([(range = m.range, min = T.(m.min), max = T.(m.max)) for m in meta.flex]),
  meta.useLON, meta.source, meta.file
)

"""
    FlightMetadata(args...)

External FlightMetadata constructor for default single floating point precision.
"""
FlightMetadata(args...) = FlightMetadata{Float32}(args...)


"""
# struct CloudMetadata

Metadata struct for cloud track data with fields `ID`, `date` (date range `start` to `stop`),
`area`, `flex`, `useLON`, and `file` similar to `FlightMetadata`.

## Instantiation

Use modified constructor to calculate `area` and `date` range from `time` and
`lat`/`lon` vectors in `data`.

    function CloudMetadata{T}(
      ID::Union{Int,AbstractString},
      data::DataFrame,
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
      useLON::Bool,
      file::AbstractString
    ) where T

Or hand over individual fields to the unmodified constructor.

    function CloudMetadata{T}(
      ID::String,
      date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}},
      area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}},
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
      useLON::Bool,
      file::String
    ) where T
"""
struct CloudMetadata{T} <: CloudTrack{T}
  ID::String
  date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}
  area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}}
  flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}}
  useLON::Bool
  file::String

  """ Unmodified constructor for `CloudMetadata` """
  function CloudMetadata{T}(
    ID::String,
    date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}},
    area::NamedTuple{(:latmin,:latmax,:elonmin,:elonmax,:wlonmin,:wlonmax),NTuple{6,T}},
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
    useLON::Bool,
    file::String
  ) where T
    new{T}(ID, date, area, flex, useLON, file)
  end #constructor 1 CloudMetadata

  """
  Modified constructor for CloudMetadata with some automated construction of fields
  and variable checks.
  """
  function CloudMetadata{T}(
    ID::Union{Int,AbstractString},
    data::DataFrame,
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
    useLON::Bool,
    file::AbstractString
  ) where T
    # T = promote_type(eltype(data.lat), eltype(data.lon))
    elonmax = isempty(data.lon[data.lon.≥0]) ? T(NaN) : maximum(data.lon[data.lon.≥0])
    elonmin = isempty(data.lon[data.lon.≥0]) ? T(NaN) : minimum(data.lon[data.lon.≥0])
    wlonmax = isempty(data.lon[data.lon.<0]) ? T(NaN) : maximum(data.lon[data.lon.<0])
    wlonmin = isempty(data.lon[data.lon.<0]) ? T(NaN) : minimum(data.lon[data.lon.<0])
    area = (latmin=minimum(data.lat), latmax=maximum(data.lat),
      elonmin=elonmin, elonmax=elonmax, wlonmin=wlonmin, wlonmax=wlonmax)
    new{T}(ID, (start=data.time[1], stop=data.time[end]), area, flex, useLON, file)
  end #constructor 2 CloudMetadata
end #struct CloudMetadata

"""
    CloudMetadata(args...)

Default CloudMetadata constructor for single floating point precision.
"""
CloudMetadata(args...) = CloudMetadata{Float32}(args...)

"""
    CloudMetadata{T}() where T

External constructor for empty CloudMetadata struct.
"""
CloudMetadata{T}() where T = CloudMetadata{T}(
  "", (start=Dates.now(), stop=Dates.now()), (latmin=T(NaN), latmax=T(NaN),
  elonmin=T(NaN), elonmax=T(NaN), wlonmin=T(NaN), wlonmax=T(NaN)),
  ((range=0:0, min=T(NaN), max=T(NaN)),), false, ""
)

"""
    CloudMetadata{T}(meta::CloudMetadata) where T

External CloudMetadata constructor for floating point conversions.
"""
CloudMetadata{T}(meta::CloudMetadata) where T = CloudMetadata{T}(
  meta.ID, meta.date, (latmin = T(meta.area.latmin), latmax = T(meta.area.latmax),
  elonmin = T(meta.area.elonmin), elonmax = T(meta.area.elonmax),
  wlonmin = T(meta.area.wlonmin), wlonmax = T(meta.area.wlonmax)),
  Tuple([(range = m.range, min = T.(m.min), max = T.(m.max)) for m in meta.flex]),
  meta.useLON, meta.file
)


"""
# struct PrimaryMetadata

Immutable struct with additional information of databases:

- `altmin::Real`: Minimum altitude threshold for which flight data is considered
- `date`: NamedTuple with entries `start`/`stop` giving the time range of the database
- `created`: time of creation of database
- `loadtime`: time it took to read data files and load it to the struct
- `remarks`: any additional data or comments that can be attached to the database
"""
struct PrimaryMetadata{T} <: PrimarySet{T}
  altmin::T
  date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}
  created::Union{DateTime,ZonedDateTime}
  loadtime::Dates.CompoundPeriod
  remarks
end #struct PrimaryMetadata

"""
    PrimaryMetadata{T}() where T

External constructor for empty PrimaryMetadata.
"""
PrimaryMetadata{T}() where T = PrimaryMetadata{T}(NaN,
  (start=Dates.now(), stop=Dates.now()), Dates.now(), Dates.CompoundPeriod(), nothing)

"""
    PrimaryMetadata(args...)

Default PrimaryMetadata constructor for single floating point precision.
"""
PrimaryMetadata(args...) = PrimaryMetadata{Float32}(args...)

"""
    PrimaryMetadata{T}(meta::PrimaryMetadata) where T

External PrimaryMetadata constructor for floating point conversions.
"""
PrimaryMetadata{T}(meta::PrimaryMetadata) where T = PrimaryMetadata{T}(T(meta.altmin),
  meta.date, meta.created, meta.loadtime, meta.remarks)


## Define structs related to flight data

"""
# struct FlightData{T}

Aircraft data with fields
- `data::DataFrame`
- `metadata::FlightMetadata`

The `DataFrame` of `data` has columns in the following order with the respective types:

- `time::Vector{DateTime}`                (time stamp of measurement)
- `lat::Vector{<:Union{Missing,T}}`       (latitude in deg)
- `lon::Vector{<:Union{Missing,T}}`       (longitude in deg)
- `alt::Vector{<:Union{Missing,T}}`       (altitude in meters)
- `heading::Vector{<:Union{Missing,Int}}` (heading/direction of the aircraft in deg)
- `climb::Vector{<:Union{Missing,Int}}`   (climbing (positive)/sinking (negative values) rate in m/s)
- `speed::Vector{<:Union{Missing,T}}`     (velocity in m/s)

By default, T<:AbstractFloat is set to `Float32`.


# Instantiation

    function FlightData{T}(
      track::DataFrame,
      dbID::Union{Int,AbstractString},
      flightID::Union{Missing,AbstractString},
      aircraft::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{<:AbstractString,<:AbstractString}}},
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
      useLON::Bool,
      source::String,
      file::AbstractString
    ) where T -> struct FlightTrack

Construct `FlightTrack` from the `data` `DataFrame` and additional meta information
`dbID`, `flightID`, `aircraft` type, `route`, `flex` points in the flight trajectory,
a flag whether longitudes are used as x data in the track (`useLON`), the database
`source`, and `file` names.
For `data`, `time` can be passed `ZonedDateTime`, which will be converted to `UTC`
standard time, or as UTC `DateTime`.

Or construct by directly handing over every field:

    FlightTrack(data::DataFrame, metadata::FlightMetadata)

Checks exist that the order, names, and types of the `data` `DataFrame` are correct.
"""
struct FlightData{T} <: FlightTrack{T}
  data::DataFrame
  metadata::FlightMetadata

  """ Unmodified constructor for `FlightData` with basic checks for correct `data`"""
  function FlightData{T}(data::DataFrame, metadata::FlightMetadata{T}) where T
    # Ensure floats of correct precision
    convertFloats!(data, T)
    # Column checks and warnings
    standardnames = ["time", "lat", "lon", "alt", "heading", "climb", "speed"]
    standardtypes = [Union{DateTime,Vector{DateTime}},
      Vector{T}, Vector{T},
      Vector{<:Union{Missing,<:T}},
      Vector{<:Union{Missing,Int}},
      Vector{<:Union{Missing,<:T}},
      Vector{<:Union{Missing,<:T}}]
    bounds = (:lat => (-90, 90), :lon => (-180, 180), :alt => (0,Inf),
      :heading => (0, 360), :speed => (0, Inf))
    checkcols!(data, standardnames, standardtypes, bounds,
      metadata.source, metadata.dbID)
    new{T}(data,metadata)
  end #constructor 1 FlightData

  """ Modified constructor with variable checks and some automated calculation of fields """
  function FlightData{T}(
    track::DataFrame,
    dbID::Union{Int,AbstractString},
    flightID::Union{Missing,AbstractString},
    aircraft::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{<:AbstractString,<:AbstractString}}},
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange{Int},T,T}}}},
    useLON::Bool,
    source::String,
    file::AbstractString
  ) where T
    # Check dataframe columns of flight data; fill missing columns with missing values
    t = getproperty(track, :time)
    t = t isa Vector{ZonedDateTime} ? [zt.utc_datetime for zt in t] : t
    lat = getproperty(track, :lat)
    lon = getproperty(track, :lon)
    alt = getproperty(track, :alt)
    heading = df.hasproperty(track, :heading) ? df.getproperty(track, :heading) :
      [missing for i in t]
    climb = df.hasproperty(track, :climb) ? df.getproperty(track, :climb) :
      [missing for i in t]
    speed = df.hasproperty(track, :speed) ? df.getproperty(track, :speed) :
      [missing for i in t]
    metadata = FlightMetadata{T}(dbID,flightID,route,aircraft,t,lat,lon,useLON,flex,
      source,file)

    # Instatiate new FlightTrack
    new{T}(DataFrame(time=t,lat=lat,lon=lon,alt=alt,heading=heading,climb=climb,speed=speed),metadata)
  end #constructor 2 FlightData
end #struct FlightData


"""
    FlightData{T}() where T

External constructor for emtpy FlightData.
"""
FlightData{T}() where T = FlightData{T}(DataFrame(time = DateTime[],
  lat = T[], lon = T[], alt=T[], heading = Int[], climb = T[],
  speed = T[]), FlightMetadata{T}()
)

"""
    FlightData{T}(flight::FlightData) where T

External FlightData constructor for conversion of floating point precision.
"""
function FlightData{T}(flight::FlightData) where T
  convertFloats!(flight.data, T)
  FlightData{T}(flight.data, FlightMetadata{T}(flight.metadata))
end

"""
    FlightData(args...; kwargs...)

Default `FlightData` constructor for `Float32`.
"""
FlightData(args...; kwargs...) = FlightData{Float32}(args...; kwargs...)

"""
    FlightTrack(args...; kwargs...)

Alias constructor for default `Float32` `FlightData`.
"""
FlightTrack(args...; kwargs...) = FlightData{Float32}(args...; kwargs...)

"""
    FlightTrack{T}(args...; kwargs...) where T

Alias constructor for `FlightData{T}`.
"""
FlightTrack{T}(args...; kwargs...) where T = FlightData{T}(args...; kwargs...)



"""
# struct FlightSet

Database for aircraft data of different database types with fields:
- `volpe::Vector{FlightTrack}`
- `flightaware::Vector{FlightTrack}`
- `webdata::Vector{FlightTrack}`
- `metadata`: `DBMetatadata` with information about
  - `altmin::Real`: Minimum altitude threshold for which flight data is considered
  - `date`: date range of the dataset
  - `created`: time of creation
  - `loadtime`
  - `remarks` (any additional data or comments)

## volpe
Flight data from csv files.

## flightaware
Commercial flight data by FlightAware from a csv file.

## webdata
Online data from the FlightAware website copied to whitespace-separated files.

## metadata
Immutable struct `PrimaryMetadata`.


# Instantiation

Instantiate by passing a `String` or `Vector{String}` with any of the keyword
arguments `volpe`, `flightaware` or `webdata` to the modified constructor of
`FlightSet`. Optionally add a minimum altitude threshold for the flight data
(default = `15000`) and any remarks (comments or additional data). Define the
delimiter in the input files of the online data with the keyword `odelim`.
Use any character or string as delimiter. By default (`odelim=nothing`),
auto-detection is used.

    function FlightSet{T}(;
      volpe::Union{String,Vector{String}}=String[],
      flightaware::Union{String,Vector{String}}=String[],
      webdata::Union{String,Vector{String}}=String[],
      altmin::Real=5000,
      remarks=nothing, odelim::Union{Nothing,Char,String}=nothing) where T

Floating point precision is set by `{T}`. If omitted, `Float32` is used.

Alternatively, instantiate directly with the fields of `FlightSet`, where the correct
database type is checked, and wrong datasets are removed in every field.

    FlightSet{T}(volpe::Vector{FlightData{T}}, flightaware::Vector{FlightData{T}},
        webdata::Vector{FlightData{T}}, metadata::PrimaryMetadata{T}) where T
"""
struct FlightSet{T} <: PrimarySet{T}
  volpe::Vector{FlightData{T}}
  flightaware::Vector{FlightData{T}}
  webdata::Vector{FlightData{T}}
  metadata::PrimaryMetadata{T}

  """
  Unmodified constructor for `FlightSet` with basic checks for correct dataset type
  in each dataset field.
  """
  function FlightSet{T}(volpe::Vector{FlightData{T}}, flightaware::Vector{FlightData{T}},
    webdata::Vector{FlightData{T}}, metadata::PrimaryMetadata{T}) where T

    # Check for correct dataset type in each vector and for correct floating point precision
    volpe = checkDBtype(volpe, "VOLPE")
    flightaware = checkDBtype(flightaware, "FlightAware")
    webdata = checkDBtype(webdata, "flightaware.com")


    # Instantiate new struct
    new{T}(volpe, flightaware, webdata, metadata)
  end #constructor 1 FlightSet

  """
  Modified constructor creating the database from an identifer of the
  database type and the respective folder path for that database.
  """
  function FlightSet{T}(;
    volpe::Union{String,Vector{String}}=String[],
    flightaware::Union{String,Vector{String}}=String[],
    webdata::Union{String,Vector{String}}=String[],
    altmin::Real=5000,
    odelim::Union{Nothing,Char,String}=nothing,
    savedir::Union{String,Bool}="abs",
    remarks=nothing
  ) where T

    # Return empty FlightSet, if no folders are passed to constructor
    all(isempty.([volpe, flightaware, webdata])) &&
      return FlightSet{T}(FlightData{T}[], FlightData{T}[], FlightData{T}[], PrimaryMetadata{T}())
    # Save time of database creation
    tstart = Dates.now()

    ## Load databases for each type
    # VOLPE AEDT dataset
    volpe isa Vector || (volpe = [volpe])
    files = String[]
    for dir in volpe
      findfiles!(files, dir, ".csv")
    end
    files = convertdir.(files, savedir)
    volpe = loadVOLPE(files...; Float=T, altmin)
    # FlightAware commercial dataset
    flightaware isa Vector || (flightaware = [flightaware])
    files = String[]
    for dir in flightaware
      findfiles!(files, dir, ".csv")
    end
    files = convertdir.(files, savedir)
    flightaware = loadFA(files...; Float=T, altmin)
    # FlightAware web content
    webdata isa Vector || (webdata = [webdata])
    files = String[]
    for dir in webdata
      findfiles!(files, dir, ".tsv", ".txt", ".dat")
    end
    files = convertdir.(files, savedir)
    webdata = loadWD(files...; Float=T, altmin, delim=odelim)
    tmin, tmax = if isempty([volpe; flightaware; webdata])
      tstart, tstart
    else
      minimum([[f.metadata.date.start for f in volpe];
        [f.metadata.date.start for f in flightaware];
        [f.metadata.date.start for f in webdata]]),
      maximum([[f.metadata.date.stop for f in volpe];
        [f.metadata.date.stop for f in flightaware];
        [f.metadata.date.stop for f in webdata]])
    end

    # wrap up and calculate load time
    tend = Dates.now()
    tc = tz.ZonedDateTime(tend, tz.localzone())
    loadtime = Dates.canonicalize(Dates.CompoundPeriod(tend - tstart))

    @info string("FlightSet loaded in ",
      "$(join(loadtime.periods[1:min(2,length(loadtime.periods))], ", ")) to",
      "\n▪ volpe ($(length(volpe)) entries)\n▪ flightaware ($(length(flightaware)) entries)\n",
      "▪ webdata ($(length(webdata)) entries)\n▪ metadata")

    # Instantiate
    new{T}(volpe, flightaware, webdata,
      PrimaryMetadata{T}(altmin, (start=tmin, stop=tmax), tc, loadtime, remarks))
  end # constructor 2 FlightSet
end #struct FlightSet

# No External constructor for empty FlightSet needed
# Empty constructor is part of the modified internal constructor


"""
    FlightSet(args...; kwargs...)

Default `FlightSet` constructor for single floating point precision.
"""
FlightSet(args...; kwargs...) = FlightSet{Float32}(args...; kwargs...)

"""
    FlightSet{T}(flights::FlightSet) where T

External `FlightSet` constructor for floating point conversions.
"""
FlightSet{T}(flights::FlightSet) where T = FlightSet{T}(
  FlightData{T}.(flights.volpe),
  FlightData{T}.(flights.flightaware),
  FlightData{T}.(flights.webdata),
  PrimaryMetadata{T}(flights.metadata)
)

"""
    PrimarySet{T}(
      volpe::Vector{FlightData{T}},
      flightaware::Vector{FlightData{T}},
      webdata::Vector{FlightData{T}},
      metadata::PrimaryMetadata{T}
) where T

Alias constructor for `FlightSet{T}` instantiation with unmodified constructor.
"""
PrimarySet{T}(
  volpe::Vector{FlightData{T}},
  flightaware::Vector{FlightData{T}},
  webdata::Vector{FlightData{T}},
  metadata::PrimaryMetadata{T}
) where T = FlightSet{T}(volpe, flightaware, webdata, metadata)

"""
    PrimarySet{T}(; kwargs...) where T

Alias constructor for `FlightSet{T}`.
"""
PrimarySet{T}(; kwargs...) where T =
  FlightSet{T}(; kwargs...)

"""
    PrimarySet{T}(tracks::FlightSet) where T

Alias constructor for `FlightSet` with converted floating point precision.
"""
PrimarySet{T}(tracks::FlightSet) where T = FlightSet{T}(tracks)


## Define structs related to cloud data

"""
# struct CloudTrack{T}

Store Data related to a single cloud track.

## Fields
- `data::DataFrame` with columns:
  - `time::Vector{DateTime}`
  - `lat::Vector{T}`
  - `lon::Vector{T}`
- `metadata::CloudMetadata`

Default floating point precision is `Float32`. There are basic validity checks
during instantiation.
"""
struct CloudData{T} <: PrimaryTrack{T}
  data::DataFrame
  metadata::CloudMetadata

  """ Unmodified constructor for `CloudTrack` with basic checks for correct `data`"""
  function CloudData{T}(data::DataFrame, metadata::CloudMetadata) where T

    # Ensure floats of correct precision
    convertFloats!(data, T)
    # Column checks and warnings
    standardnames = ["time", "lat", "lon"]
    standardtypes = [Union{DateTime,Vector{DateTime}}, Vector{T}, Vector{T}]
    bounds = (:lat => (-90, 90), :lon => (-180, 180))
    checkcols!(data, standardnames, standardtypes, bounds, "CloudTrack", metadata.ID)
    new{T}(data,metadata)
  end #constructor 1 CloudTrack
end #struct CloudTrack

"""
    CloudData(args...)

Default `CloudData` constructor for single floating point precision.
"""
CloudData(args...) = CloudData{Float32}(args...)

"""
    CloudData{T}() where T

External constructor for emtpy `CloudData` struct.
"""
CloudData{T}() where T = CloudData{T}(
  DataFrame(time = DateTime[], lat = T[], lon = T[]), CloudMetadata{T}()
)

"""
    CloudData{T}(cloud::CloudData) where T

External `CloudData` constructor for floating point conversions.
"""
CloudData{T}(cloud::CloudData) where T = CloudData{T}(
  DataFrame(time = cloud.data.time,
    lat = T.(cloud.data.lat),
    lon = T.(cloud.data.lon)
  ),
  cloud.metadata
)

"""
    CloudTrack{T}(args...) where T

Alias constructor for `CloudData{T}`.
"""
CloudTrack{T}(args...) where T = CloudData{T}(args...)

"""
    CloudTrack(args...)

Alias constructor for default Float32 CloudData.
"""
CloudTrack(args...) = CloudData{Float32}(args...)


"""
# struct CloudSet{T} <: PrimarySet{T}

Database for cloud track data with fields:
- `tracks::Vector{CloudTrack}`
- `metadata::PrimaryMetadata`

# Instantiation

Instantiate by giving the folder paths to all `mat` files with cloud track data
and optional remarks.

    CloudSet{T}(folders::String...; remarks=nothing) where T

Or use the unmodified constructor.

    CloudSet{T}(tracks::Vector{CloudData{T}}, metadata::PrimaryMetadata{T}) where T
"""
struct CloudSet{T} <: PrimarySet{T}
  tracks::Vector{CloudData{T}}
  metadata::PrimaryMetadata{T}

  """ unmodified constructor for CloudSet """
  CloudSet{T}(tracks::Vector{CloudData{T}}, metadata::PrimaryMetadata{T}) where T = new{T}(tracks, metadata)

  """
  Modified constructor creating the database from mat files in the given folder
  or any subfolder using the floating point precision given by `Float`.
  """
  function CloudSet{T}(
    folders::String...;
    savedir::Union{String,Bool}="abs",
    structname::String="filtered_trajectories",
    remarks=nothing
  ) where T
    # Return empty CloudSet, if no folders are passed to constructor
    all(isempty.(folders)) && return CloudSet{T}()
    # Track computing time
    tstart = Dates.now()
    # Scan folders for HDF4 files
    files = String[]
    for folder in folders
      try findfiles!(files, folder, ".mat")
      catch
        @warn "read error; data skipped" folder
      end
    end
    files = convertdir.(files, savedir)

    # Load cloud tracks from mat files into TrackMatcher in Julia format
    tracks = loadCloudTracks(files...; structname, Float=T)
    # Calculate load time
    tend = Dates.now()
    tc = tz.ZonedDateTime(tend, tz.localzone())
    loadtime = Dates.canonicalize(Dates.CompoundPeriod(tend - tstart))

    # For now find min/max times in CloudTracks
    tmin = minimum(t.data.time[1] for t in tracks)
    tmax = maximum(t.data.time[end] for t in tracks)

    @info string("CloudSet loaded in ",
      "$(join(loadtime.periods[1:min(2,length(loadtime.periods))], ", ")) to",
      "\n▪ tracks ($(length(tracks)) entries)\n▪ metadata")

    # Instantiate CloudSet
    new{T}(tracks, PrimaryMetadata{T}(NaN, (start=tmin, stop=tmax), tc, loadtime, remarks))
  end #modified constructor 2
end #struct CloudSet

"""
    CloudSet{T}() where T

External constructor for empty `CloudSet{T}`.
"""
CloudSet{T}() where T = CloudSet{T}(CloudData{T}[], PrimaryMetadata{T}())

"""
    CloudSet(args...; kwargs...)

Default `CloudSet` constructor for single floating point precision.
"""
CloudSet(args...; kwargs...) = CloudSet{Float32}(args...; kwargs...)

"""
    CloudSet{T}(cloud::CloudSet) where T

External `CloudSet` constructor for floating point conversions.
"""
CloudSet{T}(cloud::CloudSet) where T = CloudSet{T}(
  CloudData{T}.(cloud.tracks),
  PrimaryMetadata{T}(cloud.metadata)
)

"""
    PrimarySet{T}(tracks::Vector{CloudData{T}}, metadata::PrimaryMetadata{T}) where T

Alias constructor for CloudSet{T} unmodified constructor.
"""
PrimarySet{T}(tracks::Vector{CloudData{T}}, metadata::PrimaryMetadata{T}) where T =
  CloudSet{T}(tracks, metadata)

"""
    PrimarySet{T}(folders::String...; remarks=nothing) where T

Alias constructor for `CloudSet{T}`.
"""
PrimarySet{T}(folders::String...; remarks=nothing) where T =
  CloudSet{T}(folders; remarks)

"""
    PrimarySet{T}(tracks::CloudSet) where T

Alias constructor for `CloudSet` with converted floating point precision.
"""
PrimarySet{T}(tracks::CloudSet) where T = CloudSet{T}(tracks)
