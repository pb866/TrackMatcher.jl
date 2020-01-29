"""
# Module TrackMatcher

To find intersection between different trajectories. The module is aimed to find
intersections between aircraft and satellite tracks, but can be used for flight
or cloud tracks as well.

## Public structs

- `FlightDB` stores flight track data and other relevant aircraft related data
  from 3 different inventories:
  - `inventory`: VOLPE AEDT inventory
  - `archive`: commercially available database by FlightAware
  - `onlineData`: free online data by FlightAware
- `FlightData` stores `FlightDB` data of a single flight
- `MetaData` holds metadata to every flight
- `SatDB` stores CALIPSO cloud layer and profile data from the CALIOP satellite
- `CLay` CALIPSO cloud layer data
- `CPro` CALIPSO cloud profile data


## Public functions

- `loadFlightData` constructs the `FlightDB` from folder paths and keys signaling
  the database type
- `intersection` finds intersections in the trajectories of aircrafts and satellites
  stored in `FlightDB` and `SatDB`
"""
module TrackMatcher

# Track changes during development
# using Revise

# Import Julia packages
import CSV
import DataFrames; const df = DataFrames
import Dates
import TimeZones; const tz = TimeZones
import Geodesy; const geo = Geodesy
import MATLAB; const mat = MATLAB
import Statistics; const stats = Statistics
import ProgressMeter; const pm = ProgressMeter
import Logging; const logg = Logging
# Import structs from packages
import DataFrames.DataFrame
import Dates.DateTime, Dates.Date, Dates.Time
import TimeZones.ZonedDateTime


# Define Logger with log level
logger = logg.ConsoleLogger(stdout, logg.Debug)
logg.global_logger(logger)


### Define own structs
"""
# struct MetaData

Immutable struct to hold metadata for `FlightData` of the `FlightDB` with fields

- `dbID::Union{Int,AbstractString}`
- `flightID::Union{Missing,AbstractString}`
- `aircraft::Union{Missing,AbstractString}`
- `route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}}`
- `area::NamedTuple{(:latmin,:latmax,:plonmin,:plonmax,:nlonmin,:nlonmax),Tuple{Float64,Float64,Float64,Float64,Float64,Float64}}`
- `date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}`
- `file::AbstractString`

## dbID
Database ID – integer counter for `inventory` and FlightAware `onlineData`,
String with information about `FlightID`, `route`, and scheduled arrival.

## FlightID and aircraft
Strings with aircraft identification and type.

## route
`NamedTuple` with fields for `orig`in and `dest`ination holding the airport codes.

## area
`NamedTuple` with fields for latitude and Longitude range. For the longitude range,
it is distinguished between positive and negative ranges to avoid problems with
flights passing the date line.

Fields:
- `latmin`
- `latmax`
- `plonmin`
- `plonmax`
- `nlonmin`
- `nlonmax`

## date
`NamedTuple` with fields `start` and `stop` for start and end time of the current
flight.

## file
String holding the absolute folder path and file name.


# Instantiation

    MetaData(dbID::Union{Int,AbstractString},
      flightID::Union{Missing,AbstractString}, aircraft::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
      lat::Vector{<:Union{Missing,Float64}}, lon::Vector{<:Union{Missing,Float64}},
      date::Vector{DateTime}, file::AbstractString) -> struct MetaData

Construct `MetaData` from `dbID`, `flightID`, `aircraft` type, `route`, and `file`.
Fields `area` and `date` are calculated from `lat`/`lon`, and `date` vectors.

Or construct `MetaData` by directly handing over every field:

    MetaData(dbID::Union{Int,AbstractString}, flightID::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
      aircraft::Union{Missing,AbstractString}, date::Vector{DateTime},
      lat::Vector{<:Union{Missing,Float64}}, lon::Vector{<:Union{Missing,Float64}},
      useLON::Bool,
      flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,Float64,Float64}}}},
      file::AbstractString)
"""
struct MetaData
  dbID::Union{Int,AbstractString}
  flightID::Union{Missing,AbstractString}
  route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}}
  aircraft::Union{Missing,AbstractString}
  date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}}
  area::NamedTuple{(:latmin,:latmax,:plonmin,:plonmax,:nlonmin,:nlonmax),NTuple{6,Float64}}
  flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,Float64,Float64}}}}
  useLON::Bool
  source::AbstractString
  file::AbstractString

  """ Unmodified constructor for `Metadata` """
  function MetaData(dbID::Union{Int,AbstractString}, flightID::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
    aircraft::Union{Missing,AbstractString}, date::NamedTuple{(:start,:stop),Tuple{DateTime,DateTime}},
    area::NamedTuple{(:latmin,:latmax,:plonmin,:plonmax,:nlonmin,:nlonmax),NTuple{6,Float64}},
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,Float64,Float64}}}},
    useLON::Bool, source::AbstractString, file::AbstractString)

    new(dbID, flightID, route, aircraft, date, area, flex, useLON, source, file)
  end #constructor 1 MetaData


  """
  Modified constructor for MetaData with some automated construction of fields
  and variable checks.
  """
  function MetaData(dbID::Union{Int,AbstractString}, flightID::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
    aircraft::Union{Missing,AbstractString}, date::Vector{DateTime},
    lat::Vector{<:Union{Missing,Float64}}, lon::Vector{<:Union{Missing,Float64}},
    useLON::Bool,
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,Float64,Float64}}}},
    source::AbstractString, file::AbstractString)

    plonmax = isempty(lon[lon.≥0]) ? NaN : maximum(lon[lon.≥0])
    plonmin = isempty(lon[lon.≥0]) ? NaN : minimum(lon[lon.≥0])
    nlonmax = isempty(lon[lon.<0]) ? NaN : maximum(lon[lon.<0])
    nlonmin = isempty(lon[lon.<0]) ? NaN : minimum(lon[lon.<0])
    area = (latmin=minimum(lat), latmax=maximum(lat),
      plonmin=plonmin, plonmax=plonmax, nlonmin=nlonmin, nlonmax=nlonmax)
    new(dbID, flightID, route, aircraft, (start=date[1], stop=date[end]), area,
      flex, useLON, source, file)
  end #constructor 2 MetaData
end #struct MetaData


"""
# struct FlightData

Aircraft data with fields
- `time::Vector{DateTime}`
- `lat::Vector{<:Union{Missing,Float64}}`
- `lon::Vector{<:Union{Missing,Float64}}`
- `alt::Vector{<:Union{Missing,Float64}}`
- `heading::Vector{<:Union{Missing,Int}}`
- `climb::Vector{<:Union{Missing,Int}}`
- `speed::Vector{<:Union{Missing,Float64}}`
- `metadata::MetaData`

## time
Vector of `DateTime`

## lat/lon
Vectors of `Float64` with ranges -90°...90° and -180°...180°.

## alt
Vector of `Float64` with altitude in feet.

## heading
Vector of `Int` with course heading in degrees.

## climb
Vector of `Int` with climbing (positive) / sinking (negative) rate in feet (0 = level).

## speed
Vector of `Float64` in knots.


# Instantiation

    FlightData(time::Vector{ZonedDateTime}, lat::Vector{<:Union{Missing,Float64}},
      lon::Vector{<:Union{Missing,Float64}}, alt::Vector{<:Union{Missing,Float64}},
      heading::Vector{<:Union{Missing,Int}}, climb::Vector{<:Union{Missing,Int}},
      speed::Vector{<:Union{Missing,Float64}}, dbID::Union{Int,AbstractString},
      flightID::Union{Missing,AbstractString}, aircraft::Union{Missing,AbstractString},
      route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
      file::AbstractString) -> struct FlightData

Construct `FlightData` from fields and additonal information `dbID`, `flightID`,
`aircraft` type, `route`, and `file` name for `MetaData`.

Or construct by directly handing over every field:

    FlightData(time::Vector{DateTime}, lat::Vector{<:Union{Missing,Float64}},
      lon::Vector{<:Union{Missing,Float64}}, alt::Vector{<:Union{Missing,Float64}},
      heading::Vector{<:Union{Missing,Int}}, climb::Vector{<:Union{Missing,Int}},
      speed::Vector{<:Union{Missing,Float64}}, metadata::MetaData)
"""
struct FlightData
  data::DataFrame
  metadata::MetaData

  """ Unmodified constructor for `FlightData` """
  function FlightData(data::DataFrame, metadata::MetaData)

    # Column checks and warnings
    standardnames = [:time, :lat, :lon, :alt, :heading, :climb, :speed]
    standardtypes = [Union{DateTime,Vector{DateTime}}, Union{Float64,Vector{Float64}},
      Union{Float64,Vector{Float64}}, Union{Missing,Float64,Vector{<:Union{Missing,Float64}}},
      Union{Missing,Int,Vector{<:Union{Missing,Int}}},
      Union{Missing,Int,Vector{<:Union{Missing,Int}}},
      Union{Missing,Float64,Vector{<:Union{Missing,Float64}}}]
    bounds = [(0,Inf), (0, 360), (-Inf, Inf), (0, Inf)]
    data = checkcols(data, standardnames, standardtypes, bounds,
      metadata.source, metadata.dbID)
    new(data,metadata)
  end #constructor 1 FlightData

  """ Modified constructor with variable checks and some automated calculation of fields """
  function FlightData(time::Vector{ZonedDateTime}, lat::Vector{<:Union{Missing,Float64}},
    lon::Vector{<:Union{Missing,Float64}}, alt::Vector{<:Union{Missing,Float64}},
    heading::Vector{<:Union{Missing,Int}}, climb::Vector{<:Union{Missing,Int}},
    speed::Vector{<:Union{Missing,Float64}}, dbID::Union{Int,AbstractString},
    flightID::Union{Missing,AbstractString}, aircraft::Union{Missing,AbstractString},
    route::Union{Missing,NamedTuple{(:orig,:dest),<:Tuple{AbstractString,AbstractString}}},
    flex::Tuple{Vararg{NamedTuple{(:range, :min, :max),Tuple{UnitRange,Float64,Float64}}}},
    useLON::Bool, source::String, file::AbstractString)

    t = [t.utc_datetime for t in time]
    lat = checklength(lat, t)
    lon = checklength(lon, t)
    alt = checklength(alt, t)
    heading = checklength(heading, t)
    climb = checklength(climb, t)
    speed = checklength(speed, t)
    metadata = MetaData(dbID,flightID,route,aircraft,t,lat,lon,useLON,flex,source,file)

    new(DataFrame(time=t,lat=lat,lon=lon,alt=alt,heading=heading,climb=climb,speed=speed),metadata)
  end #constructor 2 FlightData
end #struct FlightData


"""
# struct FlightDB

Database for aircraft data of different database types with fields:
- `inventory::Vector{FlightData}`
- `archive::Vector{FlightData}`
- `onlineData::Vector{FlightData}`
- `created::Union{DateTime,ZonedDateTime}`
- `remarks`

## inventory
Flight data from csv files.

## archive
Commercial flight data by FlightAware.

## onlineData
Online data from FlightAware website.

## created
Time of creation as `DateTime` (or `ZonedDateTime`).

## remarks
Any data that can be attached to `FlightData` with keyword argument `remarks`.


# Instantiation

Use function `loadFlightDB` for an easy instatiation of `FlightDB`.
"""
struct FlightDB
  inventory::Vector{FlightData}
  archive::Vector{FlightData}
  onlineData::Vector{FlightData}
  created::Union{DateTime,ZonedDateTime}
  remarks

  function FlightDB(inventory::Vector{FlightData},
    archive::Vector{FlightData}, onlineData::Vector{FlightData},
    created::Union{DateTime,ZonedDateTime}=tz.now(tz.localzone()),
    remarks=nothing)

    inventory = checkDBtype(inventory, "VOLPE AEDT")
    archive = checkDBtype(archive, "FlightAware")
    onlineData = checkDBtype(onlineData, "flightaware.com")

    new(inventory, archive, onlineData, tc, remarks)
  end #constructor 1 FlightDB

  function FlightDB(DBtype::String, folder::Union{String, Vector{String}}...;
    altmin::Int=15_000, remarks=nothing)

    # Check DBtype addresses all folder paths
    if length(DBtype) ≠ length(folder)
      throw(ArgumentError("Number of characters in `DBtype` must match length of vararg `folder`"))
    end
    # Save time of database creation
    tc = tz.now(tz.localzone())
    # Find database types
    i1 = [findall(isequal('i'), DBtype); findall(isequal('1'), DBtype)]
    i2 = [findall(isequal('a'), DBtype); findall(isequal('2'), DBtype)]
    i3 = [findall(isequal('o'), DBtype); findall(isequal('3'), DBtype)]

    # Load databases for each type
    # VOLPE AEDT inventory
    ifiles = String[]
    for i in i1
      ifiles = findFiles(ifiles, folder[i], ".csv")
    end
    inventory = loadInventory(ifiles, altmin=altmin)
    # FlightAware commercial archive
    ifiles = String[]
    for i in i2
      ifiles = findFiles(ifiles, folder[i], ".csv")
    end
    archive = loadArchive(ifiles, altmin=altmin)
    ifiles = String[]
    for i in i3
      ifiles = findFiles(ifiles, folder[i], ".txt", ".dat")
    end
    onlineData = loadOnlineData(ifiles, altmin=altmin)

    println("\ndone loading data to properties\n- inventory\n- archive\n- onlineData\n", "")

    new(inventory, archive, onlineData, tc, remarks)
  end # constructor 2 FlightDB
end #struct FlightDB


"""
# struct CLay

CALIOP cloud layer data with fields:
- `time::Vector{DateTime}`
- `lat::Vector{Float64}`
- `lon::Vector{Float64}`

# Instantiation

    CLay(ms::mat.MSession, files::String...) -> struct CLay

Construct `CLay` from a list of file names (including directories) and a running
MATLAB session.

Or construct `CLay` by directly handing over every field:

    CLay(time::Vector{DateTime}, lat::Vector{Float64}, lon::Vector{Float64}) -> struct CLay
"""
struct CLay
  data::DataFrame

  """ Unmodified constructor for `CLay` """
  function CLay(data::DataFrame)
    standardnames = [:time, :lat, :lon]
    standardtypes = [Vector{DateTime}, Vector{Float64}, Vector{Float64}]
    bounds = Tuple{Real,Real}[]
    data = checkbounds(data, standardnames, standardtypes, bounds, "CLay", nothing)
    new(data)
  end #constructor 1 CLay

  """
  Modified constructor of `CLay` reading data from hdf files given in `folders...`
  using MATLAB session `ms`.
  """
  function CLay(ms::mat.MSession, folders::String...)
    # Scan folders for HDF4 files
    files = String[];
    for folder in folders
      files = findFiles(files, folder, ".hdf")
    end
    # Initialise arrays
    utc = DateTime[]; lon = Float64[]; lat = Float64[]
    # Loop over files
    @pm.showprogress 1 "load CLay data..." for file in files
      # Find files with cloud layer data
      if occursin("CLay", basename(file))
        # Extract time and convert to UTC
        t = mat.mxcall(ms, :hdfread,1,file,"Profile_UTC_Time")[:,2]
        utc = [utc; convertUTC.(t)]
        # Extract lat/lon
        lon = [lon; mat.mxcall(ms, :hdfread,1,file, "Longitude")[:,2]]
        lat = [lat; mat.mxcall(ms, :hdfread,1,file, "Latitude")[:,2]]
      end
    end

    # Save time, lat/lon arrays in CLay struct
    new(DataFrame(time=utc, lat=lat, lon=lon))
  end #constructor 2 CLay
end #struct CLay


"""
# struct CPro

CALIOP cloud profile data with fields:
- `time::Vector{DateTime}`
- `lat::Vector{Float64}`
- `lon::Vector{Float64}`

# Instantiation

    CPro(ms::mat.MSession, files::String...) -> struct CPro

Construct `CPro` from a list of file names (including directories) and a running
MATLAB session.

Or construct `CPro` by directly handing over every field:

    CPro(time::Vector{DateTime}, lat::Vector{Float64}, lon::Vector{Float64}) -> struct CPro
"""
struct CPro
  data::DataFrame

  """
      CPro(time::Vector{DateTime}, lat::Vector{Float64}, lon::Vector{Float64}))

  Unmodified constructor for `CPro`.
  """
  function CPro(data::DataFrame)
    standardnames = [:time, :lat, :lon]
    standardtypes = [Vector{DateTime}, Vector{Float64}, Vector{Float64}]
    bounds = Tuple{Real,Real}[]
    data = checkcols(data, standardnames, standardtypes, bounds, "CPro", nothing)
    new(data)
  end #constructor 1 CPro

  """
  Modified constructor of `CPro` reading data from hdf files given in `folders...`
  using MATLAB session `ms`.
  """
  function CPro(ms::mat.MSession, folders::String...)
    # Scan folders for HDF4 files
    files = String[];
    for folder in folders
      files = findFiles(files, folder, ".hdf")
    end
    # Initialise arrays
    utc = DateTime[]; lon = Float64[]; lat = Float64[]
    # Loop over files
    @pm.showprogress 1 "load CPro data..." for file in files
      # Find files with cloud profile data
      if occursin("CPro", basename(file))
        # Extract time and convert to UTC
        t = mat.mxcall(ms, :hdfread,1,file,"Profile_UTC_Time")[:,2]
        utc = [utc; convertUTC.(t)]
        # Extract lat/lon
        lon = [lon; mat.mxcall(ms, :hdfread,1,file, "Longitude")[:,2]]
        lat = [lat; mat.mxcall(ms, :hdfread,1,file, "Latitude")[:,2]]
      end
    end

    # Save time, lat/lon arrays in CLay struct
    new(DataFrame(time=utc, lat=lat, lon=lon))
  end #constructor 2 CPro
end #struct CPro


"""
# struct SatDB

Immutable struct with fields

- `CLay::CLay`
- `CPro::CPro`
- `created::Union{DateTime,ZonedDateTime}`
- `remarks`

## CLay and CPro

CALIOP satellite data currently holding time as `DateTime`
and position (`lat`/`lon`) of cloud layer and profile data.

## created

Time of creation of satellite database as `DateTime` or with timezone information
as `ZonedDateTime` (default).

## remarks
Any data can be attached to the satellite data with the keyword `remarks`.

# Instantiation

    SatDB(folder::String...; remarks=nothing) -> struct SatDB

Construct a CALIOP satellite database from HDF4 files (CALIOP version 4.x)
in `folder` or any subfolder (several folders can be given as vararg).
Attach comments or any data with keyword argument `remarks`.

Or construct by directly handing over struct fields (remarks are an optional
argument defaulting to `nothing`):

    SatDB(CLay::CLay, CPro::CPro, created::Union{DateTime,ZonedDateTime}, remarks=nothing)
"""
struct SatDB
  CLay::CLay
  CPro::CPro
  created::Union{DateTime,ZonedDateTime}
  remarks

  """ Unmodified constructor for `SatDB` """
  function SatDB(CLay::CLay, CPro::CPro,
    created::Union{DateTime,ZonedDateTime}=tz.now(tz.localzone()), remarks=nothing)
    new(CLay, CPro, created, remarks)
  end #constructor 1 SatDb

  """
  Automated constructor scanning for `HDF4` in `folders`; any data or comments
  can be attached in the field remarks.
  """
  function SatDB(folders::String...; remarks=nothing)
    ms = mat.MSession()
    cl = CLay(ms, folders...)
    cp = CPro(ms, folders...)
    mat.close(ms)
    tc = tz.now(tz.localzone())

    new(cl, cp, tc, remarks)
  end #constructor 2 SatDB
end #struct SatDB


"""
# struct Intersection

Immutable struct with fields

- `tflight::DateTime`
- `tsat::DateTime`
- `tdiff::Dates.CompoundPeriod`
- `lat::Float64`
- `lon::Float64`
- `alt::Union{Missing,Float64}`
- `climb::Union{Missing,Int}`
- `speed::Union{Missing,Float64}`
- `cirrus::Bool`
- `flight::MetaData`


## tflight and tsat

Overpass times at intersection of aircraft and satellite in `UTC` as `DateTime`.


## tdiff

Time difference between aircraft and satellite overpass at intersection.
Positive time differences mean satellite overpass before flight overpass,
negative times mean flight reaches intersection before satellite.


## lat/lon

Position of intersection in degrees.


## alt

altitude
"""
struct Intersection
  # tflight::DateTime
  # tsat::DateTime
  lat::Float64
  lon::Float64
  tdiff::Dates.CompoundPeriod
  accuracy::Real
  cirrus::Bool
  sat::SatDB
  flight::FlightData

  function Intersection(flight::FlightData, sat::SatDB, sattype::Symbol,
    tflight::DateTime, tsat::DateTime, lat::Float64, lon::Float64, accuracy::Real)

    tdiff = Dates.canonicalize(Dates.CompoundPeriod(tflight - tsat))
    tf = argmin(abs.(flight.data.time .- tflight))

    flightdata = FlightData(DataFrame(flight.data[tf,:]), flight.metadata)

    ts = argmin(abs.(sat.time .- tsat))
    satdata = sattype == :CLay ? CLay(sat.time[ts-15:ts+15], sat.lat[ts-15:ts+15], sat.lon[ts-15:ts+15]) :
      CPro(sat.time[ts-15:ts+15], sat.lat[ts-15:ts+15], sat.lon[ts-15:ts+15])

    new(lat, lon, tdiff, accuracy, false, satdata, flightdata)
  end
end

# Needed for julia 1.0.x?:
# SatDB(CLay::CLay, CPro::CPro, created::Union{DateTime,ZonedDateTime}) = SatDB(CLay, CPro, created, nothing)
# SatDB(CLay::CLay, CPro::CPro) = SatDB(CLay, CPro, tz.now(tz.localtime()), nothing)


export FlightDB,
       FlightData,
       MetaData,
       CLay,
       CPro,
       SatDB,
       Intersection,
       intersection


include("auxiliary.jl")
include("loadFlightData.jl")
include("match.jl")

end # module TrackMatcher
